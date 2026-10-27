import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/csv_builder.dart';
import '../../../../core/widgets/csv_export_sheet.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';

final reportProvider = FutureProvider.autoDispose.family<List<TugasReportRow>, String?>((ref, kelasId) {
  return TugasRepository().fetchReport(kelasId: kelasId);
});

final reportKelasProvider = FutureProvider.autoDispose<List<Kelas>>((ref) {
  return KelasRepository().fetchAll();
});

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  String? _kelasFilter;

  /// Nama kelas terpilih untuk judul berkas & ringkasan ekspor.
  String _kelasLabel(List<Kelas> kelasList) {
    final id = _kelasFilter;
    if (id == null) return 'Semua kelas';
    for (final kelas in kelasList) {
      if (kelas.id == id) return kelas.namaKelas;
    }
    return 'Kelas terpilih';
  }

  void _exportCsv(BuildContext context, List<TugasReportRow> rows, List<Kelas> kelasList) {
    final header = <Object?>[
      'Judul Tugas',
      'Kelas',
      'Mata Pelajaran',
      'Tenggat',
      'Total Siswa',
      'Selesai',
      'Belum',
      'Terlambat',
      'Persentase Selesai',
    ];
    final body = rows
        .map((row) => <Object?>[
              row.tugas.judul,
              row.tugas.kelasNama ?? '-',
              row.tugas.mataPelajaranNama ?? '-',
              AppDateUtils.formatTanggal(row.tugas.tenggatWaktu),
              row.totalSiswa,
              row.selesai,
              row.belum,
              row.terlambat,
              '${row.persen.toStringAsFixed(1)}%',
            ])
        .toList();
    final csv = CsvBuilder.build([header, ...body]);

    showCsvExportSheet(
      context,
      fileName: CsvBuilder.fileName('laporan-tugas-${_kelasLabel(kelasList)}', DateTime.now()),
      csv: csv,
      summary: '${rows.length} tugas • ${_kelasLabel(kelasList)} • '
          'data dari server (status resmi siswa dengan kode akses).',
    );
  }

  @override
  Widget build(BuildContext context) {
    final kelasAsync = ref.watch(reportKelasProvider);
    final reportAsync = ref.watch(reportProvider(_kelasFilter));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportProvider);
        ref.invalidate(reportKelasProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        children: [
          const AppHeroHeader(
            compact: true,
            eyebrow: 'Laporan',
            title: 'Penyelesaian Tugas',
            subtitle: 'Persentase dihitung dari status tugas siswa di server.',
          ),
          const SizedBox(height: AppSpacing.lg),
          kelasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (kelasList) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua kelas'),
                    selected: _kelasFilter == null,
                    onSelected: (_) => setState(() => _kelasFilter = null),
                  ),
                  for (final kelas in kelasList) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: Text(kelas.namaKelas),
                      selected: _kelasFilter == kelas.id,
                      onSelected: (selected) => setState(() => _kelasFilter = selected ? kelas.id : null),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          reportAsync.when(
            loading: () => const AppSkeletonList(count: 4),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(reportProvider(_kelasFilter)),
            ),
            data: (rows) {
              final kelasList = kelasAsync.valueOrNull ?? const <Kelas>[];
              if (rows.isEmpty) {
                return const AppCard(
                  child: AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Belum ada data laporan',
                    subtitle: 'Laporan muncul setelah guru menerbitkan tugas.',
                  ),
                );
              }

              final totalSiswa = rows.fold<int>(0, (sum, row) => sum + row.totalSiswa);
              final totalSelesai = rows.fold<int>(0, (sum, row) => sum + row.selesai);
              final totalTerlambat = rows.fold<int>(0, (sum, row) => sum + row.terlambat);
              final overall = totalSiswa == 0 ? 0.0 : (totalSelesai / totalSiswa) * 100;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _kelasLabel(kelasList),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportCsv(context, rows, kelasList),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('Ekspor CSV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.7,
                    children: [
                      MetricTile(
                        label: 'Penyelesaian agregat',
                        value: '${overall.toStringAsFixed(1)}%',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                        background: AppColors.successContainer,
                      ),
                      MetricTile(
                        label: 'Tugas terlapor',
                        value: '${rows.length}',
                        icon: Icons.assignment_rounded,
                      ),
                      MetricTile(
                        label: 'Sudah selesai',
                        value: '$totalSelesai',
                        icon: Icons.task_alt_rounded,
                        color: AppColors.success,
                        background: AppColors.successContainer,
                      ),
                      MetricTile(
                        label: 'Terlambat dikumpulkan',
                        value: '$totalTerlambat',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        background: AppColors.warningContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Rincian per tugas',
                    subtitle: 'Termasuk jumlah siswa yang belum menyelesaikan',
                    icon: Icons.list_alt_rounded,
                  ),
                  ...rows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: () => context.push('/admin/tugas/${row.tugas.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.tugas.judul,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    '${row.persen.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: row.persen >= 75
                                          ? AppColors.success
                                          : row.persen >= 40
                                              ? AppColors.warning
                                              : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${row.tugas.kelasNama ?? '-'} • ${row.tugas.mataPelajaranNama ?? '-'} • '
                                'Tenggat ${AppDateUtils.formatTanggal(row.tugas.tenggatWaktu)}',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (row.persen / 100).clamp(0, 1),
                                  minHeight: 7,
                                  backgroundColor: AppColors.surfaceMuted,
                                  valueColor: AlwaysStoppedAnimation(
                                    row.persen >= 75
                                        ? AppColors.success
                                        : row.persen >= 40
                                            ? AppColors.warning
                                            : AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${row.selesai}/${row.totalSiswa} selesai • ${row.belum} belum • ${row.terlambat} terlambat',
                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: AppSpacing.sm),
                  const AppNotice.info(
                    text: 'Status "selesai" hanya berasal dari laporan resmi siswa dengan kode akses. '
                        'Status yang disimpan di perangkat siswa tidak dihitung di laporan ini.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
