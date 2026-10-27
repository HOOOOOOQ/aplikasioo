/// Pembentuk CSV murni (tanpa I/O) agar dapat diuji di semua target.
///
/// Aturan yang dipakai mengikuti RFC 4180: field yang mengandung koma, tanda
/// kutip, atau baris baru dibungkus tanda kutip ganda dan tanda kutip di
/// dalamnya digandakan. Baris diakhiri CRLF supaya kompatibel dengan Excel.
class CsvBuilder {
  const CsvBuilder._();

  /// Escape satu nilai.
  static String escape(Object? value) {
    final raw = value?.toString() ?? '';
    // Cegah CSV injection: nilai yang diawali karakter formula diberi awalan
    // apostrof agar tidak dieksekusi Excel/Sheets.
    final guarded = raw.isNotEmpty && '=+-@\t\r'.contains(raw[0]) ? "'$raw" : raw;
    final needsQuote = guarded.contains(',') ||
        guarded.contains('"') ||
        guarded.contains('\n') ||
        guarded.contains('\r') ||
        guarded.contains(';');
    if (!needsQuote) return guarded;
    return '"${guarded.replaceAll('"', '""')}"';
  }

  /// Gabungkan baris menjadi teks CSV. Baris kosong diabaikan.
  static String build(List<List<Object?>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      if (row.isEmpty) continue;
      buffer.write(row.map(escape).join(','));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  /// Nama berkas aman: `laporan-tugas-2026-10-27-1030.csv`.
  static String fileName(String prefix, DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final safePrefix = prefix
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    return '${safePrefix.isEmpty ? 'edutask' : safePrefix}-$stamp.csv';
  }
}
