import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'pdf_export_result.dart';

/// Web tidak punya dialog cetak PDF bawaan, jadi ekspor memakai unduhan
/// berkas asli (Blob + `<a download>`) tanpa CDN/plugin tambahan.
const bool kSupportsNativePdfDialog = false;

web.Blob _pdfBlob(Uint8List bytes) {
  final parts = <JSAny>[bytes.toJS].toJS;
  return web.Blob(parts, web.BlobPropertyBag(type: 'application/pdf'));
}

/// Unduh PDF langsung ke folder unduhan browser.
Future<PdfExportResult> exportPdfBytes(
  Uint8List bytes, {
  required String fileName,
  required String title,
  bool share = false,
}) async {
  String? objectUrl;
  try {
    final blob = _pdfBlob(bytes);
    objectUrl = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = '$fileName.pdf'
      ..rel = 'noopener';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();

    // Jangan cabut URL terlalu cepat: sebagian browser membatalkan unduhan
    // bila objek URL dihapus pada frame yang sama.
    final url = objectUrl;
    Future<void>.delayed(const Duration(minutes: 1), () {
      try {
        web.URL.revokeObjectURL(url);
      } catch (error) {
        debugPrint('Gagal melepas object URL PDF: $error');
      }
    });
    return const PdfExportResult.downloaded();
  } catch (error) {
    if (objectUrl != null) {
      try {
        web.URL.revokeObjectURL(objectUrl);
      } catch (revokeError) {
        debugPrint('Gagal melepas object URL PDF: $revokeError');
      }
    }
    return PdfExportResult.failed('Browser menolak unduhan PDF: $error');
  }
}

/// Buka PDF di tab baru supaya pengguna bisa mencetak dari penampil browser.
///
/// Popup bisa diblokir browser; dalam hal itu pengguna diarahkan memakai
/// tombol unduh (pesan dikembalikan sebagai kegagalan yang jelas).
Future<PdfExportResult> openPdfForPrint(
  Uint8List bytes, {
  required String fileName,
}) async {
  try {
    final blob = _pdfBlob(bytes);
    final objectUrl = web.URL.createObjectURL(blob);
    final opened = web.window.open(objectUrl, '_blank');
    if (opened == null) {
      web.URL.revokeObjectURL(objectUrl);
      return const PdfExportResult.failed(
        'Tab baru diblokir browser. Gunakan "Unduh PDF" lalu buka berkasnya.',
      );
    }
    return const PdfExportResult.printed();
  } catch (error) {
    return PdfExportResult.failed('Gagal membuka PDF di tab baru: $error');
  }
}
