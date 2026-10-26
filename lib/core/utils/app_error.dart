import 'package:supabase_flutter/supabase_flutter.dart';

/// Kesalahan yang sudah diterjemahkan menjadi pesan yang bisa ditindaklanjuti.
///
/// Tujuan: pengguna tidak pernah melihat pesan mentah seperti
/// "PostgrestException(message: ..., code: 42501)" atau "HTTP 403".
class AppError {
  final String title;
  final String message;
  final String? hint;
  final String? code;

  const AppError({
    required this.title,
    required this.message,
    this.hint,
    this.code,
  });

  /// Pesan singkat untuk SnackBar / baris error.
  String get shortMessage => hint == null ? message : '$message $hint';

  static AppError from(Object error) {
    if (error is AppError) return error;

    if (error is AuthException) {
      return _fromAuth(error);
    }
    if (error is PostgrestException) {
      return _fromPostgrest(error);
    }
    if (error is StorageException) {
      return _fromStorage(error);
    }
    if (error is FunctionException) {
      return _fromFunction(error);
    }

    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return const AppError(
        title: 'Tidak ada koneksi',
        message: 'Perangkat tidak dapat menghubungi server.',
        hint: 'Periksa internet lalu coba lagi.',
        code: 'network',
      );
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return const AppError(
        title: 'Koneksi terlalu lama',
        message: 'Server tidak merespons tepat waktu.',
        hint: 'Coba lagi beberapa saat lagi.',
        code: 'timeout',
      );
    }
    if (lower.contains('belum dikonfigurasi')) {
      return const AppError(
        title: 'Konfigurasi belum lengkap',
        message: 'Aplikasi belum terhubung ke server Supabase pada build ini.',
        hint: 'Hubungi pengelola untuk build dengan SUPABASE_URL dan SUPABASE_ANON_KEY.',
        code: 'config',
      );
    }

    return AppError(
      title: 'Terjadi kesalahan',
      message: _clean(text),
      code: 'unknown',
    );
  }

  static AppError _fromAuth(AuthException e) {
    final text = '${e.message} ${e.code ?? ''}'.toLowerCase();
    if (text.contains('invalid login') || text.contains('invalid credentials')) {
      return const AppError(
        title: 'Gagal masuk',
        message: 'Email atau kata sandi tidak sesuai.',
        hint: 'Periksa kembali penulisan keduanya.',
        code: 'auth_invalid_credentials',
      );
    }
    if (text.contains('email not confirmed')) {
      return const AppError(
        title: 'Email belum dikonfirmasi',
        message: 'Akun sudah terdaftar tetapi email belum diverifikasi.',
        hint: 'Buka tautan verifikasi di email, atau hubungi admin.',
        code: 'auth_email_unconfirmed',
      );
    }
    if (text.contains('too many requests') || text.contains('rate limit')) {
      return const AppError(
        title: 'Terlalu banyak percobaan',
        message: 'Demi keamanan, percobaan masuk dibatasi sementara.',
        hint: 'Tunggu beberapa menit lalu coba lagi.',
        code: 'auth_rate_limited',
      );
    }
    if (text.contains('user not found')) {
      return const AppError(
        title: 'Akun tidak ditemukan',
        message: 'Tidak ada akun dengan email tersebut.',
        hint: 'Pastikan email benar atau hubungi admin sekolah.',
        code: 'auth_user_not_found',
      );
    }
    return AppError(
      title: 'Autentikasi gagal',
      message: _clean(e.message),
      code: e.code ?? 'auth_error',
    );
  }

  static AppError _fromPostgrest(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return const AppError(
          title: 'Akses ditolak',
          message: 'Akun ini tidak memiliki izin untuk operasi tersebut.',
          hint: 'Hubungi admin jika menurut Anda ini keliru.',
          code: 'rls_denied',
        );
      case '23505':
        return const AppError(
          title: 'Data sudah ada',
          message: 'Nilai yang Anda masukkan sudah dipakai data lain.',
          hint: 'Gunakan nama atau nomor induk yang berbeda.',
          code: 'unique_violation',
        );
      case '23503':
        return const AppError(
          title: 'Data masih terhubung',
          message: 'Data ini dipakai oleh data lain sehingga tidak bisa diproses.',
          hint: 'Hapus atau ubah data terkait terlebih dahulu.',
          code: 'foreign_key',
        );
      case '23514':
        return const AppError(
          title: 'Data tidak valid',
          message: 'Data yang dikirim tidak memenuhi aturan penyimpanan.',
          hint: 'Periksa kembali isian tanggal, jam, dan kolom wajib.',
          code: 'check_violation',
        );
      case 'PGRST116':
        return const AppError(
          title: 'Data tidak ditemukan',
          message: 'Data yang diminta sudah tidak ada atau belum tersedia.',
          code: 'not_found',
        );
      case 'P0001':
        return AppError(
          title: 'Operasi ditolak server',
          message: _clean(e.message),
          code: 'server_rule',
        );
    }

    final lower = e.message.toLowerCase();
    if (lower.contains('jadwal bentrok')) {
      return const AppError(
        title: 'Jadwal bentrok',
        message: 'Sudah ada jadwal lain pada hari dan jam yang sama.',
        hint: 'Pilih jam atau kelas lain.',
        code: 'jadwal_bentrok',
      );
    }
    if (lower.contains('row-level security')) {
      return const AppError(
        title: 'Akses ditolak',
        message: 'Server menolak operasi ini karena aturan keamanan data.',
        hint: 'Pastikan Anda login dengan akun yang berwenang.',
        code: 'rls_denied',
      );
    }
    return AppError(
      title: 'Gagal menyimpan data',
      message: _clean(e.message),
      code: e.code,
    );
  }

  static AppError _fromStorage(StorageException e) {
    final raw = '${e.message} ${e.error ?? ''}'.toLowerCase();
    if (e.statusCode == '403' || raw.contains('row-level security') || raw.contains('unauthorized')) {
      return const AppError(
        title: 'Lampiran ditolak server',
        message: 'File tidak dapat diunggah karena aturan keamanan penyimpanan.',
        hint: 'Pastikan Anda guru pemilik tugas ini dan policy Storage sudah diperbarui '
            '(jalankan supabase/migrations/003_storage_attachments.sql).',
        code: 'storage_forbidden',
      );
    }
    if (e.statusCode == '413' || raw.contains('too large') || raw.contains('exceeded')) {
      return const AppError(
        title: 'File terlalu besar',
        message: 'Ukuran file melebihi batas yang diizinkan server (10 MB).',
        code: 'storage_too_large',
      );
    }
    if (e.statusCode == '404' || raw.contains('bucket not found')) {
      return const AppError(
        title: 'Bucket lampiran tidak ditemukan',
        message: 'Penyimpanan lampiran belum disiapkan di server.',
        hint: 'Jalankan migration 003_storage_attachments.sql.',
        code: 'storage_bucket_missing',
      );
    }
    if (raw.contains('mime') || raw.contains('content type')) {
      return const AppError(
        title: 'Tipe file tidak didukung',
        message: 'Server menolak tipe file ini.',
        hint: 'Gunakan PDF, DOC/DOCX, PPT/PPTX, XLS/XLSX, JPG, PNG, atau ZIP.',
        code: 'storage_mime',
      );
    }
    return AppError(
      title: 'Gagal mengunggah file',
      message: _clean(e.message),
      code: e.statusCode ?? 'storage_error',
    );
  }

  static AppError _fromFunction(FunctionException e) {
    dynamic detail = e.details;
    String message = '';
    String code = '';
    if (detail is Map) {
      message = (detail['error'] ?? detail['message'] ?? '').toString();
      code = (detail['code'] ?? '').toString();
    } else if (detail != null) {
      message = detail.toString();
    }

    switch (e.status) {
      case 401:
        return AppError(
          title: 'Sesi tidak valid',
          message: message.isEmpty ? 'Server menolak kredensial Anda.' : message,
          hint: 'Keluar lalu masuk kembali.',
          code: code.isEmpty ? 'unauthorized' : code,
        );
      case 403:
        return AppError(
          title: 'Akses ditolak',
          message: message.isEmpty ? 'Akun ini tidak berwenang untuk operasi tersebut.' : message,
          code: code.isEmpty ? 'forbidden' : code,
        );
      case 404:
        return const AppError(
          title: 'Layanan belum tersedia',
          message: 'Edge Function yang dibutuhkan belum dideploy di server.',
          hint: 'Deploy melalui Actions → Deploy Supabase Edge Functions.',
          code: 'not_deployed',
        );
      case 409:
        return AppError(
          title: 'Sudah digunakan',
          message: message.isEmpty ? 'Data ini sudah dipakai.' : message,
          code: code.isEmpty ? 'conflict' : code,
        );
      case 410:
        return AppError(
          title: 'Kode kedaluwarsa',
          message: message.isEmpty ? 'Kode ini sudah tidak berlaku.' : message,
          code: code.isEmpty ? 'expired' : code,
        );
      case 429:
        return AppError(
          title: 'Terlalu banyak percobaan',
          message: message.isEmpty ? 'Demi keamanan, coba lagi beberapa menit lagi.' : message,
          code: code.isEmpty ? 'too_many_attempts' : code,
        );
      case 0:
        return const AppError(
          title: 'Tidak ada koneksi',
          message: 'Permintaan tidak sampai ke server.',
          hint: 'Periksa internet lalu coba lagi.',
          code: 'network',
        );
    }

    if (e.status >= 500) {
      return AppError(
        title: 'Server bermasalah',
        message: message.isEmpty ? 'Terjadi kesalahan di server.' : message,
        hint: 'Coba lagi beberapa saat lagi.',
        code: code.isEmpty ? 'server_error' : code,
      );
    }

    return AppError(
      title: 'Permintaan gagal',
      message: message.isEmpty ? 'Server menolak permintaan (HTTP ${e.status}).' : message,
      code: code.isEmpty ? 'function_error' : code,
    );
  }

  static String _clean(String raw) {
    var text = raw
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('PostgrestException(message: ', '')
        .replaceAll(RegExp(r', code: [^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > 220) text = '${text.substring(0, 220)}…';
    return text.isEmpty ? 'Terjadi kesalahan yang tidak diketahui.' : text;
  }
}

/// Bungkus operasi async agar pemanggil cukup menangani AppError.
Future<T> guardAsync<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw AppError.from(e);
  }
}
