import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../services/csv_saver.dart';
import 'app_card.dart';
import 'app_states.dart';

/// Menampilkan opsi ekspor CSV: pratinjau, salin ke papan klip, dan (bila
/// platform mendukung) tulis berkas ke direktori sementara aplikasi.
///
/// Web tidak memiliki akses sistem berkas, jadi opsi simpan disembunyikan dan
/// pengguna diarahkan menyalin lalu menempel ke Excel/Google Sheets. Ini
/// perilaku yang jujur — bukan tombol unduh palsu.
Future<void> showCsvExportSheet(
  BuildContext context, {
  required String fileName,
  required String csv,
  String? summary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => _CsvExportSheet(fileName: fileName, csv: csv, summary: summary),
  );
}

class _CsvExportSheet extends StatefulWidget {
  final String fileName;
  final String csv;
  final String? summary;

  const _CsvExportSheet({required this.fileName, required this.csv, this.summary});

  @override
  State<_CsvExportSheet> createState() => _CsvExportSheetState();
}

class _CsvExportSheetState extends State<_CsvExportSheet> {
  bool _saving = false;
  String? _savedPath;

  int get _lineCount {
    final trimmed = widget.csv.trimRight();
    if (trimmed.isEmpty) return 0;
    return '\n'.allMatches(trimmed).length + 1;
  }

  String get _preview {
    final lines = widget.csv.split('\r\n').where((l) => l.trim().isNotEmpty).take(6);
    return lines.join('\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV disalin ke papan klip.')),
    );
  }

  Future<void> _save() async {
    if (!CsvSaver.supportsFileSave || _saving) return;
    setState(() => _saving = true);
    try {
      final path = await CsvSaver.save(fileName: widget.fileName, content: widget.csv);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedPath = path;
      });
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan berkas CSV.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan berkas: ${e.runtimeType == Exception ? 'kesalahan penyimpanan' : 'tidak diketahui'}.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ekspor CSV',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${widget.fileName} • $_lineCount baris',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.summary != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.summary!,
                  style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.surfaceMuted,
                child: Text(
                  _preview.isEmpty ? '(tidak ada data)' : _preview,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Salin CSV'),
                ),
              ),
              if (CsvSaver.supportsFileSave) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 18),
                    label: Text(_saving ? 'Menyimpan…' : 'Simpan berkas CSV'),
                  ),
                ),
                if (_savedPath != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    'Tersimpan di: $_savedPath',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                const AppNotice.info(
                  title: 'Ekspor di browser',
                  text: 'Browser tidak mengizinkan aplikasi menulis langsung ke folder perangkat. '
                      'Gunakan "Salin CSV" lalu tempel (Ctrl+V) ke Excel atau Google Sheets, '
                      'atau unduh dari menu berbagi browser.',
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Nilai diawali apostrof bila berpotensi dibaca sebagai formula, agar aman '
                'saat dibuka di spreadsheet.',
                style: TextStyle(fontSize: 10.5, height: 1.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
