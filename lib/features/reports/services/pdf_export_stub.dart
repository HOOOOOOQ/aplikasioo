import 'dart:typed_data';

import 'pdf_export_result.dart';

/// Implementasi fallback ketika platform tidak dikenali (mis. lingkungan uji
/// tanpa dart:io maupun JS). Tidak pernah dipakai di Android/Web.
const bool kSupportsNativePdfDialog = false;

Future<PdfExportResult> exportPdfBytes(
  Uint8List bytes, {
  required String fileName,
  required String title,
  bool share = false,
}) async {
  return const PdfExportResult.failed('Ekspor PDF tidak didukung di perangkat ini.');
}

Future<PdfExportResult> openPdfForPrint(
  Uint8List bytes, {
  required String fileName,
}) async {
  return const PdfExportResult.failed('Cetak PDF tidak didukung di perangkat ini.');
}
