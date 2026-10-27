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
import '../../../reports/domain/report_document.dart';
import '../../../reports/services/pdf_exporter.dart';
import '../../../reports/services/report_pdf_builder.dart';

final reportProvider = FutureProvider.autoDispose.family<List<TugasReportRow>, ReportFilter>((ref, filter) {
  return TugasRepository().fetchReport(
    kelasId: filter.kelasId,
    guruId: filter.guruId,
    mapelId: filter.mapelId,
    from: filter.from,
    to: filter.to,
    // Satu baris lebih dari batas dokumen supaya UI/PDF tahu laporan terpotong.
    limit: ReportDocument.maxRows + 1,
  );
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
  /// Filter tunggal untuk CSV **dan** PDF (sumber data tidak boleh berbeda).
  ReportFilter _filter = ReportFilter.empty;

  bool _exportingPdf = false;

  void _selectKelas(Kelas? kelas) {
    setState(() {
      _filter = kelas == null
          ? _filter.copyWith(clearKelas: true)
          : _filter.copyWith(kelasId: kelas.id, kelasNama: kelas.namaKelas);
    });
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDateRange: _filter.from != null && _filter.to != null
          ? DateTimeRange(start: _filter.from!, end: _filter.to!)
          : null,
      helpText: 'Pilih periode tenggat tugas',
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = _filter.copyWith(from: picked.start, to: picked.end));
  }

  void _clearPeriod() {
    setState(() => _filter = _filter.copyWith(clearPeriod: true));
  }

  /// Satu dokumen laporan dipakai untuk CSV dan PDF.
  ReportDocument _buildDocument(List<TugasReportRow> rows) {
    return ReportDocument.from(
      source: rows,
      filter: _filter,
      generatedAt: DateTime.now(),
    );
  }

  void _exportCsv(List<TugasReportRow> rows) {
    final doc = _buildDocument(rows);
    final csv = CsvBuilder.build(doc.toTableRows());
    showCsvExportSheet(
      context,
      fileName: '${doc.fileNameStem}.csv',
      csv: csv,
      summary: '${doc.totalTugas} tugas • ${doc.filter.scopeLabel} • '
          'periode ${doc.filter.periodLabel} • data dari server '
          '(status resmi siswa dengan kode akses).',
    );
  }

  Future<void> _exportPdf(List<TugasReportRow> rows) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final doc = _buildDocument(rows);
      final bytes = await ReportPdfBuilder.build(doc);
      if (!mounted) return;

      const native = PdfExporter.supportsNativePdfDialog;
      final action = await showModalBottomSheet<_PdfAction>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ekspor PDF • ${doc.totalTugas} tugas',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(native ? 'Pratinjau & cetak' : 'Unduh PDF'),
                subtitle: Text(
                  native
                      ? 'Buka dialog cetak Android; pilih "Simpan sebagai PDF" untuk menyimpan.'
                      : 'Berkas PDF asli diunduh ke folder unduhan browser.',
                ),
                onTap: () => Navigator.of(sheetContext).pop(_PdfAction.preview),
              ),
              ListTile(
                leading: Icon(native ? Icons.ios_share_rounded : Icons.open_in_new_rounded),
                title: Text(native ? 'Bagikan' : 'Buka untuk dicetak'),
                subtitle: Text(
                  native
                      ? 'Kirim PDF lewat aplikasi lain di perangkat.'
                      : 'Buka PDF di tab baru, lalu cetak dari penampil browser.',
                ),
                onTap: () => Navigator.of(sheetContext).pop(_PdfAction.secondary),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      );
      if (action == null || !mounted) return;

      final PdfExportResult result;
      if (PdfExporter.supportsNativePdfDialog) {
        // Native: aksi kedua memakai lembar berbagi sistem.
        result = await PdfExporter.export(
          bytes,
          fileName: doc.fileNameStem,
          title: doc.title,
          share: action == _PdfAction.secondary,
        );
      } else {
        // Web: aksi kedua membuka PDF di tab baru untuk dicetak.
        result = action == _PdfAction.secondary
            ? await PdfExporter.print(bytes, fileName: doc.fileNameStem, title: doc.title)
            : await PdfExporter.export(
                bytes,
                fileName: doc.fileNameStem,
                title: doc.title,
              );
      }
      if (!mounted) return;
      if (result.isCancelled) return;
      _showSnack(result.successMessage, isError: result.isFailure);
    } catch (error) {
      if (!mounted) return;
      _showSnack('Gagal membuat PDF: $error', isError: true);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kelasAsync = ref.watch(reportKelasProvider);
    final reportAsync = ref.watch(reportProvider(_filter));
    final rows = reportAsync.valueOrNull ?? const <TugasReportRow>[];
    final canExport = reportAsync.hasValue && !_exportingPdf;

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
                    selected: _filter.kelasId == null,
                    onSelected: (_) => _selectKelas(null),
                  ),
                  for (final kelas in kelasList) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: Text(kelas.namaKelas),
                      selected: _filter.kelasId == kelas.id,
                      onSelected: (selected) => _selectKelas(selected ? kelas : null),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event_rounded, size: 16),
                  label: Text('Periode: ${_filter.periodLabel}'),
                  onPressed: _pickPeriod,
                ),
                if (_filter.hasPeriod) ... [
                  const SizedBox(width: AppSpacing.sm),
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Hapus periode'),
                    onPressed: _clearPeriod,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_filter.scopeLabel} • '
                '${rows.length > ReportDocument.maxRows ? '${ReportDocument.maxRows}+' : rows.length} tugas',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canExport ? () => _exportCsv(rows) : null,
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Ekspor CSV'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canExport ? () => _exportPdf(rows) : null,
                      icon: _exportingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: Text(_exportingPdf ? 'Menyiapkan…' : 'Ekspor PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          reportAsync.when(
            loading: () => const AppSkeletonList(count: 4),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(reportProvider(_filter)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppCard(
                  child: AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Belum ada data laporan',
                    subtitle: 'Laporan muncul setelah guru menerbitkan tugas. '
                        'Anda tetap bisa mengekspor PDF kosong sebagai bukti periode tanpa data.',
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

/// Aksi yang dipilih dari lembar ekspor PDF.
enum _PdfAction { preview, secondary }
