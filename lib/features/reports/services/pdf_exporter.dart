import 'dart:typed_data';

import 'pdf_export_result.dart';
import 'pdf_export_stub.dart'
    if (dart.library.io) 'pdf_export_native.dart'
    if (dart.library.js_interop) 'pdf_export_web.dart' as impl;

export 'pdf_export_result.dart';

/// Titik masuk tunggal untuk mengirim PDF ke pengguna.
///
/// Pemilihan implementasi dilakukan saat kompilasi:
/// * Android/iOS (`dart.library.io`) → `Printing` (pratinjau/cetak/bagikan),
/// * Web (`dart.library.js_interop`) → unduhan berkas asli via Blob,
/// * lainnya → kegagalan yang jelas (tidak ada API platform yang dipanggil).
///
/// Dengan cara ini tidak ada API khusus Android yang bocor ke Web dan
/// sebaliknya, tanpa perlu `dart:io` di kode UI.
class PdfExporter {
  PdfExporter._();

  /// `true` bila platform punya dialog cetak/berbagi PDF bawaan.
  static const bool supportsNativePdfDialog = impl.kSupportsNativePdfDialog;

  /// Kirim [bytes] sebagai PDF bernama [fileName] (tanpa ekstensi).
  ///
  /// [share] hanya berpengaruh di platform native (lembar berbagi sistem).
  static Future<PdfExportResult> export(
    Uint8List bytes, {
    required String fileName,
    required String title,
    bool share = false,
  }) {
    return impl.exportPdfBytes(
      bytes,
      fileName: fileName,
      title: title,
      share: share,
    );
  }

  /// Buka PDF untuk dicetak (native: dialog cetak, web: tab baru).
  static Future<PdfExportResult> print(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) {
    return impl.openPdfForPrint(bytes, fileName: fileName);
  }
}
