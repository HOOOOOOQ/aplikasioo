import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'pdf_export_result.dart';

/// Android/iOS punya dialog cetak & lembar berbagi bawaan sistem, jadi PDF
/// ditampilkan lewat `Printing` (pratinjau, simpan sebagai PDF, atau bagikan).
const bool kSupportsNativePdfDialog = true;

/// Ekspor PDF di platform native.
///
/// * `share == false` → dialog cetak sistem (`Printing.layoutPdf`). Di Android
///   pengguna bisa memilih "Simpan sebagai PDF" atau printer.
/// * `share == true` → lembar berbagi sistem (`Printing.sharePdf`).
///
/// Semua kegagalan plugin ditangkap dan dikembalikan sebagai
/// [PdfExportStatus.failed] agar UI menampilkan pesan, bukan crash.
Future<PdfExportResult> exportPdfBytes(
  Uint8List bytes, {
  required String fileName,
  required String title,
  bool share = false,
}) async {
  try {
    if (share) {
      final shared = await Printing.sharePdf(
        bytes: bytes,
        filename: '$fileName.pdf',
        subject: title,
      );
      return shared
          ? const PdfExportResult.shared()
          : const PdfExportResult.cancelled();
    }

    final done = await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: title,
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
    );
    return done ? const PdfExportResult.printed() : const PdfExportResult.cancelled();
  } catch (error) {
    return PdfExportResult.failed('Gagal membuka pratinjau PDF: $error');
  }
}

/// Cetak langsung tanpa lembar berbagi.
Future<PdfExportResult> openPdfForPrint(
  Uint8List bytes, {
  required String fileName,
}) async {
  try {
    final done = await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileName,
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
    );
    return done ? const PdfExportResult.printed() : const PdfExportResult.cancelled();
  } catch (error) {
    return PdfExportResult.failed('Gagal mencetak PDF: $error');
  }
}
