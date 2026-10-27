import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Implementasi penyimpanan CSV di Android/iOS/desktop.
///
/// Berkas ditulis ke direktori sementara aplikasi (bukan storage eksternal),
/// sehingga tidak memerlukan izin tambahan dan tidak bocor ke aplikasi lain.
class CsvSaver {
  static const bool supportsFileSave = true;

  /// Mengembalikan path berkas yang berhasil ditulis, atau `null` bila gagal.
  static Future<String?> save({required String fileName, required String content}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    // BOM UTF-8 agar Excel mengenali aksara non-ASCII dengan benar.
    await file.writeAsBytes(utf8.encode('\uFEFF$content'), flush: true);
    return file.path;
  }
}
