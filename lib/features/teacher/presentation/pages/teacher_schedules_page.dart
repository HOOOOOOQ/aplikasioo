import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/services/supabase_service.dart';

final teacherSchedulesProvider = FutureProvider.autoDispose<List<Jadwal>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const [];
  return JadwalRepository().fetchByGuru(uid);
});

class TeacherSchedulesPage extends ConsumerStatefulWidget {
  const TeacherSchedulesPage({super.key});

  @override
  ConsumerState<TeacherSchedulesPage> createState() => _TeacherSchedulesPageState();
}

class _TeacherSchedulesPageState extends ConsumerState<TeacherSchedulesPage> {
  String? _hari;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teacherSchedulesProvider);
    final today = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teacherSchedulesProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        children: [
          AppHeroHeader(
            compact: true,
            eyebrow: 'Jadwal mengajar',
            title: 'Jadwal Saya',
            subtitle: 'Jadwal yang tercatat untuk akun guru Anda.',
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
          async.when(
            loading: () => const AppSkeletonList(count: 4),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(teacherSchedulesProvider),
            ),
            data: (all) {
              final list = _hari == null ? all : all.where((j) => j.hari == _hari).toList();
              if (list.isEmpty) {
                return AppCard(
                  child: AppEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Belum ada jadwal',
                    subtitle: _hari == null
                        ? 'Admin belum menambahkan jadwal untuk akun Anda.'
                        : 'Tidak ada jadwal pada hari $_hari.',
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
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'HARI INI',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
                                          '${jadwal.kelasNama ?? '-'}'
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
      ),
    );
  }
}
