import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../identity/student_identity_provider.dart';

final kelasListProvider = FutureProvider.autoDispose<List<Kelas>>((ref) async {
  if (SupabaseConfig.isNotConfigured) return const [];
  return KelasRepository().fetchAll();
});

final studentScheduleProvider = FutureProvider.autoDispose.family<List<Jadwal>, String>((ref, kelasId) async {
  if (SupabaseConfig.isNotConfigured || kelasId.isEmpty) return const [];
  return JadwalRepository().fetchByKelas(kelasId);
});

final studentTasksProvider = FutureProvider.autoDispose.family<List<Tugas>, String>((ref, kelasId) async {
  if (SupabaseConfig.isNotConfigured || kelasId.isEmpty) return const [];
  final identity = ref.watch(studentIdentityProvider);
  return TugasRepository().fetchAll(kelasId: kelasId, siswaId: identity.siswaId);
});

/// Kelas yang sedang dilihat siswa. Identitas terverifikasi menang; jika belum,
/// siswa boleh memilih kelas secara manual (tanpa login).
String? effectiveKelasId(WidgetRef ref, List<Kelas> kelasList) {
  final identity = ref.watch(studentIdentityProvider);
  final selected = identity.kelasId;
  if (selected != null && kelasList.any((k) => k.id == selected)) return selected;
  if (kelasList.isEmpty) return null;
  return kelasList.first.id;
}

class StudentMainPage extends ConsumerStatefulWidget {
  const StudentMainPage({super.key});

  @override
  ConsumerState<StudentMainPage> createState() => _StudentMainPageState();
}

class _StudentMainPageState extends ConsumerState<StudentMainPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(kelasListProvider);
    ref.invalidate(studentScheduleProvider);
    ref.invalidate(studentTasksProvider);
    await ref.read(kelasListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final kelasAsync = ref.watch(kelasListProvider);
    final now = AppDateUtils.nowJakarta();
    final hariIni = AppDateUtils.hariIndonesia(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            EduTaskLogo(size: 30, withShadow: false),
            SizedBox(width: AppSpacing.sm),
            Text('EduTask'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Identitas siswa',
            onPressed: () => context.push('/siswa/identitas'),
            icon: Badge(
              isLabelVisible: identity.isIdentified,
              backgroundColor: AppColors.success,
              smallSize: 8,
              child: const Icon(Icons.badge_outlined),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') context.push('/siswa/tentang');
              if (value == 'login') context.push('/login');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('Tentang EduTask')),
              PopupMenuItem(value: 'login', child: Text('Masuk sebagai guru/admin')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              context.go('/siswa/jadwal');
              break;
            case 2:
              context.go('/siswa/tugas');
              break;
            case 3:
              context.push('/siswa/identitas');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Identitas'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: kelasAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 3)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(error: e, onRetry: _refresh),
            ],
          ),
          data: (kelasList) {
            if (kelasList.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  AppHeroHeader(
                    eyebrow: '${hariIni}, ${AppDateUtils.formatTanggal(now)}',
                    title: 'Selamat datang',
                    subtitle: 'Belum ada data kelas dari sekolah.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.class_outlined,
                      title: 'Belum ada kelas',
                      subtitle: SupabaseConfig.isNotConfigured
                          ? 'Build ini belum terhubung ke Supabase. Hubungi pengelola aplikasi.'
                          : 'Admin sekolah belum menambahkan kelas. Coba muat ulang sebentar lagi.',
                      actionLabel: 'Muat ulang',
                      onAction: _refresh,
                    ),
                  ),
                ],
              );
            }

            final kelasId = effectiveKelasId(ref, kelasList);
            final kelasAktif = kelasList.firstWhere((k) => k.id == kelasId, orElse: () => kelasList.first);
            final jadwalAsync = ref.watch(studentScheduleProvider(kelasId ?? ''));
            final tugasAsync = ref.watch(studentTasksProvider(kelasId ?? ''));

            return ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  eyebrow: '${hariIni}, ${AppDateUtils.formatTanggal(now)}',
                  title: identity.isIdentified
                      ? 'Halo, ${identity.siswaNama ?? 'Siswa'}'
                      : 'Halo, Sobat EduTask',
                  subtitle: identity.isIdentified
                      ? '${identity.kelasNama ?? kelasAktif.namaKelas} • Identitas terverifikasi'
                      : 'Pilih kelas untuk melihat jadwal dan tugas tanpa login.',
                  trailing: identity.isIdentified
                      ? const Icon(Icons.verified_rounded, color: Colors.white)
                      : null,
                  footer: _IdentityStrip(identity: identity),
                ),
                const SizedBox(height: AppSpacing.lg),
                _KelasSelector(
                  kelasList: kelasList,
                  selectedId: kelasAktif.id,
                  onSelected: (kelas) async {
                    await ref.read(studentIdentityProvider.notifier).setKelas(
                          kelas.id,
                          kelasNama: kelas.namaKelas,
                        );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: jadwalAsync.when(
                        loading: () => const MetricTile(
                          label: 'Jadwal hari ini',
                          value: '…',
                          icon: Icons.schedule_rounded,
                        ),
                        error: (_, __) => MetricTile(
                          label: 'Jadwal hari ini',
                          value: '-',
                          icon: Icons.schedule_rounded,
                          caption: 'Gagal dimuat',
                          onTap: () => context.go('/siswa/jadwal'),
                        ),
                        data: (list) {
                          final today = list.where((j) => j.hari == hariIni).length;
                          return MetricTile(
                            label: 'Jadwal hari ini',
                            value: '$today',
                            icon: Icons.schedule_rounded,
                            caption: today == 0 ? 'Tidak ada pelajaran' : 'Pelajaran',
                            onTap: () => context.go('/siswa/jadwal'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: tugasAsync.when(
                        loading: () => const MetricTile(
                          label: 'Tugas aktif',
                          value: '…',
                          icon: Icons.assignment_rounded,
                          color: AppColors.warning,
                          background: AppColors.warningContainer,
                        ),
                        error: (_, __) => const MetricTile(
                          label: 'Tugas aktif',
                          value: '-',
                          icon: Icons.assignment_rounded,
                          color: AppColors.warning,
                          background: AppColors.warningContainer,
                          caption: 'Gagal dimuat',
                        ),
                        data: (list) {
                          final localStatus = ref.watch(localTaskStatusProvider);
                          final aktif = list.where((t) {
                            final done = t.statusSiswa == 'selesai' || localStatus[t.id] == 'selesai';
                            return !done;
                          }).length;
                          return MetricTile(
                            label: 'Tugas belum selesai',
                            value: '$aktif',
                            icon: Icons.assignment_late_rounded,
                            color: AppColors.warning,
                            background: AppColors.warningContainer,
                            caption: 'Dari ${list.length} tugas',
                            onTap: () => context.go('/siswa/tugas'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Jadwal hari ini',
                  subtitle: hariIni,
                  actionLabel: 'Semua',
                  onAction: () => context.go('/siswa/jadwal'),
                ),
                jadwalAsync.when(
                  loading: () => const AppSkeletonList(count: 2),
                  error: (e, _) => AppCard(
                    child: AppEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Jadwal gagal dimuat',
                      subtitle: 'Periksa koneksi lalu coba lagi.',
                      actionLabel: 'Coba lagi',
                      onAction: () => ref.invalidate(studentScheduleProvider(kelasAktif.id)),
                    ),
                  ),
                  data: (list) {
                    final today = list.where((j) => j.hari == hariIni).toList();
                    if (today.isEmpty) {
                      return const AppCard(
                        child: AppEmptyState(
                          icon: Icons.free_breakfast_rounded,
                          title: 'Tidak ada jadwal hari ini',
                          subtitle: 'Gunakan waktu untuk mengerjakan tugas yang belum selesai.',
                        ),
                      );
                    }
                    return Column(
                      children: today
                          .take(3)
                          .map((jadwal) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _JadwalTile(jadwal: jadwal),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Tugas terdekat',
                  subtitle: 'Diurutkan dari tenggat paling awal',
                  actionLabel: 'Semua',
                  onAction: () => context.go('/siswa/tugas'),
                ),
                tugasAsync.when(
                  loading: () => const AppSkeletonList(count: 2),
                  error: (e, _) => AppCard(
                    child: AppEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Tugas gagal dimuat',
                      subtitle: 'Periksa koneksi lalu coba lagi.',
                      actionLabel: 'Coba lagi',
                      onAction: () => ref.invalidate(studentTasksProvider(kelasAktif.id)),
                    ),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const AppCard(
                        child: AppEmptyState(
                          icon: Icons.task_alt_rounded,
                          title: 'Belum ada tugas',
                          subtitle: 'Guru belum menerbitkan tugas untuk kelas ini.',
                        ),
                      );
                    }
                    final localStatus = ref.watch(localTaskStatusProvider);
                    return Column(
                      children: list
                          .take(3)
                          .map((tugas) {
                            final official = tugas.statusSiswa == 'selesai';
                            final local = localStatus[tugas.id] == 'selesai';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                onTap: () => context.push('/siswa/tugas/${tugas.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tugas.judul,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        StatusChip(
                                          status: DeadlineHelper.getStatus(
                                            deadline: tugas.tenggatWaktu,
                                            isCompleted: official || local,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tugas.mataPelajaranNama ?? '-'} • '
                                      '${AppDateUtils.formatTanggal(tugas.tenggatWaktu)}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Pintasan', icon: Icons.bolt_rounded),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/siswa/identitas'),
                      icon: const Icon(Icons.badge_outlined, size: 18),
                      label: Text(identity.isIdentified ? 'Identitas saya' : 'Verifikasi kode akses'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/siswa/tentang'),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('Tentang EduTask'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IdentityStrip extends StatelessWidget {
  final StudentIdentity identity;
  const _IdentityStrip({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            identity.isIdentified ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              identity.isIdentified
                  ? 'Status tugas yang Anda laporkan tercatat resmi di server.'
                  : 'Belum terverifikasi — perubahan status tugas hanya tersimpan di perangkat ini.',
              style: TextStyle(fontSize: 10.5, height: 1.35, color: Colors.white.withValues(alpha: 0.92)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KelasSelector extends StatelessWidget {
  final List<Kelas> kelasList;
  final String selectedId;
  final ValueChanged<Kelas> onSelected;
  const _KelasSelector({required this.kelasList, required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kelasList
            .map((kelas) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(kelas.namaKelas),
                    selected: kelas.id == selectedId,
                    onSelected: (_) => onSelected(kelas),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _JadwalTile extends StatelessWidget {
  final Jadwal jadwal;
  const _JadwalTile({required this.jadwal});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              children: [
                Text(
                  AppDateUtils.formatJamFromString(jadwal.jamMulai),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
                Text(
                  AppDateUtils.formatJamFromString(jadwal.jamSelesai),
                  style: const TextStyle(fontSize: 9.5, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jadwal.mataPelajaranNama ?? '-',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(
                  '${jadwal.guruNama ?? '-'}${jadwal.ruang != null && jadwal.ruang!.isNotEmpty ? ' • ${jadwal.ruang}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
