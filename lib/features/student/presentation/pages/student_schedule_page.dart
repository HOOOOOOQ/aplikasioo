import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../shared/models/jadwal.dart';
import '../../identity/student_identity_provider.dart';
import 'student_main_page.dart';

class StudentSchedulePage extends ConsumerStatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  ConsumerState<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends ConsumerState<StudentSchedulePage> {
  String? _hari;

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final kelasAsync = ref.watch(kelasListProvider);
    final today = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Jadwal Pelajaran')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/siswa');
          if (index == 2) context.go('/siswa/tugas');
          if (index == 3) context.push('/siswa/identitas');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Identitas'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kelasListProvider);
          ref.invalidate(studentScheduleProvider);
          await ref.read(kelasListProvider.future);
        },
        child: kelasAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 4)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(error: e, onRetry: () => ref.invalidate(kelasListProvider)),
            ],
          ),
          data: (kelasList) {
            if (kelasList.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SizedBox(height: AppSpacing.xxl),
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.class_outlined,
                      title: 'Belum ada kelas',
                      subtitle: 'Jadwal akan muncul setelah admin menambahkan kelas.',
                    ),
                  ),
                ],
              );
            }

            final kelasId = effectiveKelasId(ref, kelasList);
            final kelasAktif = kelasList.firstWhere((k) => k.id == kelasId, orElse: () => kelasList.first);
            final jadwalAsync = ref.watch(studentScheduleProvider(kelasId ?? ''));

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Jadwal pelajaran',
                  title: identity.isIdentified ? identity.siswaNama ?? 'Jadwal saya' : 'Jadwal kelas',
                  subtitle: '${kelasAktif.namaKelas} • hari ini $today',
                ),
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _hari == null,
                        onSelected: (_) => setState(() => _hari = null),
                      ),
                      for (final hari in AppDateUtils.daftarHari) ...[
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(hari),
                          selected: _hari == hari,
                          onSelected: (selected) => setState(() => _hari = selected ? hari : null),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                jadwalAsync.when(
                  loading: () => const AppSkeletonList(count: 4),
                  error: (e, _) => AppErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(studentScheduleProvider(kelasAktif.id)),
                  ),
                  data: (all) {
                    final list = _hari == null ? all : all.where((j) => j.hari == _hari).toList();
                    if (list.isEmpty) {
                      return AppCard(
                        child: AppEmptyState(
                          icon: Icons.event_busy_rounded,
                          title: 'Belum ada jadwal',
                          subtitle: _hari == null
                              ? 'Admin belum menyusun jadwal untuk kelas ${kelasAktif.namaKelas}.'
                              : 'Tidak ada pelajaran pada hari $_hari.',
                          actionLabel: _hari == null ? null : 'Lihat semua hari',
                          onAction: _hari == null ? null : () => setState(() => _hari = null),
                        ),
                      );
                    }

                    final grouped = <String, List<Jadwal>>{};
                    for (final item in list) {
                      grouped.putIfAbsent(item.hari, () => []).add(item);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        final isToday = entry.key == today;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: entry.key,
                              subtitle: isToday ? 'Hari ini • ${entry.value.length} pelajaran' : '${entry.value.length} pelajaran',
                              icon: isToday ? Icons.today_rounded : Icons.calendar_today_outlined,
                            ),
                            ...entry.value.map((jadwal) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: AppCard(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: Row(
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              AppDateUtils.formatJamFromString(jadwal.jamMulai),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                            ),
                                            Text(
                                              AppDateUtils.formatJamFromString(jadwal.jamSelesai),
                                              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 3,
                                          height: 40,
                                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                jadwal.mataPelajaranNama ?? '-',
                                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                              ),
                                              Text(
                                                '${jadwal.guruNama ?? '-'}'
                                                '${jadwal.ruang != null && jadwal.ruang!.isNotEmpty ? ' • ${jadwal.ruang}' : ''}',
                                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
