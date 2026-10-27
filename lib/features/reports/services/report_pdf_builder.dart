import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/config/app_info.dart';
import '../domain/report_document.dart';

/// Pembuat dokumen PDF laporan penyelesaian tugas.
///
/// Murni Dart (paket `pdf`) sehingga:
/// * bisa diuji tanpa perangkat/plugin (`flutter test`),
/// * dipakai sama persis di Android dan Web,
/// * tidak memanggil API khusus platform.
///
/// Isi tabel diambil dari [ReportDocument.toTableRows] — sumber yang sama
/// dengan ekspor CSV — sehingga kedua format tidak bisa berbeda data.
class ReportPdfBuilder {
  ReportPdfBuilder._();

  static final PdfColor _brand = PdfColor.fromInt(0xFF1A56DB);
  static final PdfColor _brandDark = PdfColor.fromInt(0xFF123C9B);
  static final PdfColor _surface = PdfColor.fromInt(0xFFF5F7FB);
  static final PdfColor _border = PdfColor.fromInt(0xFFE2E8F0);
  static final PdfColor _textPrimary = PdfColor.fromInt(0xFF0F172A);
  static final PdfColor _textSecondary = PdfColor.fromInt(0xFF5B6B85);
  static final PdfColor _success = PdfColor.fromInt(0xFF15803D);
  static final PdfColor _warning = PdfColor.fromInt(0xFFB45309);

  /// Batas halaman; [ReportDocument.maxRows] menjaga agar tidak terlampaui.
  static const int maxPages = 120;

  /// Bangun dokumen PDF (belum di-save) dari [doc].
  ///
  /// Dipisah dari [build] agar pengujian bisa memeriksa jumlah halaman tanpa
  /// bergantung pada isi biner berkas.
  static pw.Document createDocument(ReportDocument doc) {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    final pdf = pw.Document(
      theme: theme,
      title: doc.title,
      author: AppInfo.appName,
      creator: AppInfo.appName,
      subject: 'Laporan penyelesaian tugas ${doc.filter.scopeLabel}',
      producer: AppInfo.appName,
    );

    // A4 landscape: laporan punya 10 kolom; header tabel diulang otomatis di
    // setiap halaman (`headerCount: 1`).
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.fromLTRB(26, 22, 26, 24),
        theme: theme,
        maxPages: maxPages,
        header: (context) => _header(doc),
        footer: (context) => _footer(doc, context),
        build: (context) => [
          _summary(doc),
          pw.SizedBox(height: 12),
          if (doc.rows.isEmpty) _emptyState() else _table(doc),
          if (doc.truncated) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Catatan: laporan dibatasi ${ReportDocument.maxRows} tugas pertama. '
              'Persempit periode atau filter untuk melihat sisanya.',
              style: pw.TextStyle(fontSize: 8, color: _warning),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  /// Bangun berkas PDF final dari [doc].
  static Future<Uint8List> build(ReportDocument doc) {
    return createDocument(doc).save();
  }

  // ---------------------------------------------------------------------
  // Bagian-bagian dokumen
  // ---------------------------------------------------------------------

  static pw.Widget _header(ReportDocument doc) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 34,
            height: 34,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _brand,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(9)),
            ),
            child: pw.Text(
              'E',
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppInfo.appName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandDark,
                  ),
                ),
                pw.Text(
                  AppInfo.tagline,
                  style: pw.TextStyle(fontSize: 8, color: _textSecondary),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                doc.title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              pw.Text(
                'Dibuat: ${doc.generatedAtLabel}',
                style: pw.TextStyle(fontSize: 7.5, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(ReportDocument doc, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${AppInfo.appName} • ${doc.filter.scopeLabel} • ${doc.filter.periodLabel}',
            style: pw.TextStyle(fontSize: 7, color: _textSecondary),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summary(ReportDocument doc) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          doc.filter.scopeLabel,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Periode: ${doc.filter.periodLabel} • ${doc.totalTugas} tugas',
          style: pw.TextStyle(fontSize: 8, color: _textSecondary),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _metric('Total tugas', '${doc.totalTugas}'),
            pw.SizedBox(width: 8),
            _metric('Total siswa', '${doc.totalSiswa}'),
            pw.SizedBox(width: 8),
            _metric('Selesai', '${doc.totalSelesai}', color: _success),
            pw.SizedBox(width: 8),
            _metric('Terlambat', '${doc.totalTerlambat}', color: _warning),
            pw.SizedBox(width: 8),
            _metric('Penyelesaian', '${doc.overallPercent.toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _metric(String label, String value, {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: _border, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7, color: _textSecondary),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color ?? _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _emptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Tidak ada data pada filter ini',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Ubah kelas, guru, mata pelajaran, atau periode lalu ekspor ulang. '
            'Laporan hanya memuat tugas yang sudah diterbitkan (bukan draft).',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  static pw.Widget _table(ReportDocument doc) {
    final rows = doc.toTableRows();
    final headers = rows.first;
    final data = rows.skip(1).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerCount: 1,
      border: pw.TableBorder.all(color: _border, width: 0.6),
      headerDecoration: pw.BoxDecoration(color: _brand),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: pw.TextStyle(fontSize: 7.5, color: _textPrimary),
      oddRowDecoration: pw.BoxDecoration(color: _surface),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      // Kolom angka dibuat sempit & rata kanan, kolom teks dapat sisa lebar.
      columnWidths: const {
        0: pw.FlexColumnWidth(3.2), // Judul
        1: pw.FlexColumnWidth(1.2), // Kelas
        2: pw.FlexColumnWidth(1.6), // Mapel
        3: pw.FlexColumnWidth(1.6), // Guru
        4: pw.FlexColumnWidth(1.6), // Tenggat
        5: pw.FlexColumnWidth(0.9), // Total
        6: pw.FlexColumnWidth(0.9), // Selesai
        7: pw.FlexColumnWidth(0.9), // Belum
        8: pw.FlexColumnWidth(1.0), // Terlambat
        9: pw.FlexColumnWidth(1.1), // Persentase
      },
      cellAlignments: const {
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
      },
      headerAlignments: const {
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
      },
    );
  }
}
