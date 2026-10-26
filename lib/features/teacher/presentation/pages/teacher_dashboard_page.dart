import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../auth/presentation/auth_provider.dart';

class _TeacherHomeData {
  final List<Jadwal> hariIni;
  final List<Tugas> tugas;
  const _TeacherHomeData({required this.hariIni, required this.tugas});
}

final teacherHomeProvider = FutureProvider.autoDispose<_TeacherHomeData>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const _TeacherHomeData(hariIni: [], tugas: []);
  final hari = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
  final results = await Future.wait([
    JadwalRepository().fetchAll(guruId: uid, hari: hari),
    TugasRepository().fetchAll(guruId: uid, statusPublikasi: ''),
  ]);
  final tugas = (results[1] as List<Tugas>)
      .where((t) => t.statusPublikasi != 'archived')
      .toList();
  return _TeacherHomeData(
    hariIni: results[0] as List<Jadwal>,
    tugas: tugas,
  );
});

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherHomeProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final now = AppDateUtils.nowJakarta();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teacherHomeProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        children: [
          AppHeroHeader(
            eyebrow: '${AppDateUtils.hariIndonesia(now)}, ${AppDateUtils.formatTanggal(now)}',
            title: 'Halo, ${user?.fullName ?? 'Guru'}',
            subtitle: 'Kelola jadwal dan tugas kelas yang Anda ampu.',
            trailing: IconButton(
              tooltip: 'Tentang',
              onPressed: () => context.push('/tentang?from=guru'),
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            loading: () => const AppSkeletonList(count: 3),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(teacherHomeProvider),
            ),
            data: (data) {
              final aktif = data.tugas.where((t) => t.isPublished).length;
              final draft = data.tugas.where((t) => t.statusPublikasi == 'draft').length;
              final berlampiran = data.tugas.where((t) => t.hasLampiran).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Jadwal hari ini',
                          value: '${data.hariIni.length}',
                          icon: Icons.today_rounded,
                          onTap: () => context.go('/guru/jadwal'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricTile(
                          label: 'Tugas terbit',
                          value: '$aktif',
                          icon: Icons.assignment_rounded,
                          color: AppColors.success,
                          background: AppColors.successContainer,
                          onTap: () => context.go('/guru/tugas'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Draft',
                          value: '$draft',
                          icon: Icons.edit_note_rounded,
                          color: AppColors.warning,
                          background: AppColors.warningContainer,
                          onTap: () => context.go('/guru/tugas'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricTile(
                          label: 'Berlampiran',
                          value: '$berlampiran',
                          icon: Icons.attach_file_rounded,
                          color: AppColors.info,
                          background: AppColors.infoContainer,
                          onTap: () => context.go('/guru/tugas'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Jadwal hari ini',
                    subtitle: AppDateUtils.hariIndonesia(now),
                    actionLabel: 'Semua jadwal',
                    onAction: () => context.go('/guru/jadwal'),
                  ),
                  if (data.hariIni.isEmpty)
                    const AppCard(
                      child: AppEmptyState(
                        icon: Icons.free_breakfast_rounded,
                        title: 'Tidak ada jadwal hari ini',
                        subtitle: 'Nikmati waktu luang, atau tambahkan tugas untuk kelas Anda.',
                      ),
                    )
                  else
                    ...data.hariIni.map((jadwal) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        AppDateUtils.formatJamFromString(jadwal.jamMulai),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
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
                                        '${jadwal.kelasNama ?? '-'}${jadwal.ruang != null ? ' • ${jadwal.ruang}' : ''}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Aksi cepat', icon: Icons.bolt_rounded),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/guru/tugas/tambah'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Buat tugas'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/guru/kode-akses'),
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('Kode akses'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/guru/tugas'),
                        icon: const Icon(Icons.insights_rounded, size: 18),
                        label: const Text('Laporan tugas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Tugas terbaru',
                    actionLabel: 'Lihat semua',
                    onAction: () => context.go('/guru/tugas'),
                  ),
                  if (data.tugas.isEmpty)
                    const AppCard(
                      child: AppEmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'Belum ada tugas',
                        subtitle: 'Buat tugas pertama untuk kelas Anda.',
                      ),
                    )
                  else
                    ...data.tugas.take(4).map((tugas) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            onTap: () => context.push('/guru/tugas/${tugas.id}'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tugas.judul,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tugas.kelasNama ?? '-'} • ${AppDateUtils.formatTanggal(tugas.tenggatWaktu)}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(
                                  status: DeadlineHelper.getStatus(
                                    deadline: tugas.tenggatWaktu,
                                    isCompleted: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
