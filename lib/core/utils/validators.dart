class Validators {
  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email wajib diisi';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? nomorInduk(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nomor induk wajib diisi';
    if (value.trim().length < 3) return 'Nomor induk minimal 3 karakter';
    return null;
  }

  static String? nama(String? value, {String field = 'Nama'}) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    if (value.trim().length < 2) return '$field minimal 2 karakter';
    if (value.trim().length > 100) return '$field maksimal 100 karakter';
    return null;
  }

  static String? title(String? value) {
    if (value == null || value.trim().isEmpty) return 'Judul wajib diisi';
    if (value.trim().length < 3) return 'Judul minimal 3 karakter';
    if (value.trim().length > 200) return 'Judul maksimal 200 karakter';
    return null;
  }

  static String? description(String? value) {
    if (value == null || value.trim().isEmpty) return 'Deskripsi wajib diisi';
    if (value.trim().length < 10) return 'Deskripsi minimal 10 karakter';
    return null;
  }

  static String? timeRange(String? start, String? end) {
    if (start == null || end == null) return null;
    if (start.compareTo(end) >= 0) return 'Jam selesai harus setelah jam mulai';
    return null;
  }

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    if (end.isBefore(start)) return 'Tenggat tidak boleh sebelum tanggal mulai';
    return null;
  }
}
