import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../shared/models/status_tugas.dart';
import '../../../../shared/repositories/tugas_repository.dart';

final taskStatusProvider = FutureProvider.autoDispose.family<({List<StatusTugasSiswa> rows, Map<String, int> summary}), String>((ref, tugasId) async {
  final repo = TugasRepository();
  final results = await Future.wait([
    repo.fetchStatusForTugas(tugasId),
    repo.fetchSummary(tugasId),
  ]);
  return (
    rows: results[0] as List<StatusTugasSiswa>,
    summary: results[1] as Map<String, int>,
  );
});

class TeacherTaskStatusPage extends ConsumerStatefulWidget {
  final String taskId;
  const TeacherTaskStatusPage({super.key, required this.taskId});

  @override
  ConsumerState<TeacherTaskStatusPage> createState() => _TeacherTaskStatusPageState();
}

class _TeacherTaskStatusPageState extends ConsumerState<TeacherTaskStatusPage> {
  String _filter = 'semua';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskStatusProvider(widget.taskId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Status Penyelesaian')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(taskStatusProvider(widget.taskId)),
        child: async.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 4)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(taskStatusProvider(widget.taskId)),
              ),
            ],
          ),
          data: (data) {
            final list = data.rows;
            final filtered = switch (_filter) {
              'selesai' => list.where((e) => e.status == 'selesai').toList(),
              'belum' => list.where((e) => e.status != 'selesai').toList(),
              _ => list,
            };

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Laporan resmi',
                  title: 'Status Siswa',
                  subtitle: 'Hanya status yang dilaporkan dengan kode akses terverifikasi yang dihitung.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: MetricTile(label: 'Total siswa', value: '${data.summary['total'] ?? 0}', icon: Icons.groups_rounded)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Selesai',
                        value: '${data.summary['selesai'] ?? 0}',
                        icon: Icons.task_alt_rounded,
                        color: AppColors.success,
                        background: AppColors.successContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Belum',
                        value: '${data.summary['belum'] ?? 0}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.error,
                        background: AppColors.errorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'semua', label: Text('Semua')),
                    ButtonSegment(value: 'selesai', label: Text('Selesai')),
                    ButtonSegment(value: 'belum', label: Text('Belum')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.isEmpty ? _filter : selection.first),
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Belum ada laporan',
                      subtitle: list.isEmpty
                          ? 'Siswa perlu memverifikasi kode akses dan menandai tugas selesai untuk muncul di sini.'
                          : 'Tidak ada siswa pada filter ini.',
                      actionLabel: list.isEmpty ? null : 'Lihat semua',
                      onAction: list.isEmpty ? null : () => setState(() => _filter = 'semua'),
                    ),
                  )
                else
                  ...filtered.map((row) {
                    final done = row.status == 'selesai';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            InitialsAvatar(name: row.siswaNama ?? 'Siswa', size: 38),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.siswaNama ?? 'Siswa',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    done
                                        ? 'Selesai ${row.selesaiPada == null ? '' : '• ${AppDateUtils.formatTanggalJam(row.selesaiPada)}'}'
                                        : 'Belum selesai',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: done ? AppColors.successContainer : AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                done ? 'Selesai' : 'Belum',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: done ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
