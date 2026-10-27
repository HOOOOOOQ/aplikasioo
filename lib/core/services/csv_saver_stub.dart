/// Implementasi tanpa sistem berkas (dipakai pada target Web).
///
/// Browser tidak mengizinkan penulisan berkas langsung dari sandbox, sehingga
/// alur ekspor di Web memakai papan klip. Fungsi di bawah tidak pernah dipanggil
/// selama [CsvSaver.supportsFileSave] bernilai `false`.
class CsvSaver {
  static const bool supportsFileSave = false;

  static Future<String?> save({required String fileName, required String content}) async => null;
}
