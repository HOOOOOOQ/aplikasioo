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
    // Skema belum diterapkan / schema cache PostgREST basi.
    // PGRST205 = tabel tidak ada di schema cache, PGRST202 = fungsi tidak ada,
    // 42P01 = undefined_table, 42883 = undefined_function,
    // PGRST204 = kolom tidak dikenal (schema cache).
    final rawMessage = e.message.toLowerCase();
    final schemaMissing = const {'PGRST205', 'PGRST202', 'PGRST204', '42P01', '42883'}
            .contains(e.code) ||
        rawMessage.contains('could not find the table') ||
        rawMessage.contains('could not find the function') ||
        rawMessage.contains('schema cache') ||
        (rawMessage.contains('relation') && rawMessage.contains('does not exist'));
    if (schemaMissing) {
      return const AppError(
        title: 'Skema database belum siap',
        message: 'Objek database yang dibutuhkan aplikasi belum tersedia di project Supabase.',
        hint: 'Admin: jalankan supabase/migrations/005_access_codes_schema_repair.sql, '
            'lalu tekan "Periksa skema" di Pengaturan.',
        code: 'schema_not_ready',
      );
    }

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
    // Fallback: penyebab spesifik tidak dikenali, tetapi tetap jangan
    // menampilkan teks SQL mentah ke pengguna dan jangan memakai judul
    // "Gagal menyimpan data" untuk operasi baca.
    final sqlState = (e.code ?? '').trim();
    if (lower.contains('timeout') || lower.contains('canceling statement')) {
      return const AppError(
        title: 'Database lambat merespons',
        message: 'Permintaan melebihi batas waktu server database.',
        hint: 'Coba lagi beberapa saat lagi.',
        code: 'database_timeout',
      );
    }
    return AppError(
      title: 'Permintaan database gagal',
      message: 'Server database menolak permintaan ini.',
      hint: sqlState.isEmpty
          ? 'Coba lagi. Bila berulang, hubungi admin dan periksa log Supabase.'
          : 'Kode kesalahan: $sqlState. Coba lagi; bila berulang, laporkan kode ini ke admin.',
      code: sqlState.isEmpty ? 'database_error' : sqlState,
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

    // Kode domain dari Edge Function lebih spesifik daripada status HTTP.
    // Contoh: `student-access` mengembalikan 404 `kode_not_found` untuk kode
    // yang salah ketik — bukan berarti Edge Function belum dideploy.
    final domain = _domainFunctionError(code, message);
    if (domain != null) return domain;

    switch (e.status) {
      case 401:
        // Bedakan sesi benar-benar berakhir dari sekadar token tidak dikirim.
        //
        // Gateway Supabase (verify_jwt) menolak token kedaluwarsa dengan body
        // generik sebelum Edge Function berjalan; kode numerik/ kosong seperti
        // itu tetap berarti sesi login, bukan kesalahan input.
        final numericOrEmpty = code.isEmpty || int.tryParse(code) != null;
        final sessionIssue = numericOrEmpty ||
            const {'session_expired', 'invalid_token', 'missing_token', 'unauthorized'}
                .contains(code);
        return AppError(
          title: sessionIssue ? 'Sesi login berakhir' : 'Sesi tidak valid',
          message: message.isEmpty
              ? 'Server tidak menerima kredensial sesi Anda.'
              : message,
          hint: sessionIssue
              ? 'Masuk kembali sebagai admin atau guru. Data yang sudah tersimpan tidak hilang.'
              : null,
          code: numericOrEmpty ? 'session_expired' : code,
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

    if (e.status == 503 || code == 'schema_not_ready') {
      return AppError(
        title: 'Skema database belum siap',
        message: message.isEmpty
            ? 'Database belum memiliki tabel yang dibutuhkan aplikasi.'
            : message,
        hint: 'Admin: jalankan supabase/migrations/005_access_codes_schema_repair.sql, '
            'lalu ulangi. Periksa juga di Pengaturan → Kesehatan server.',
        code: 'schema_not_ready',
      );
    }
    if (code == 'server_misconfigured') {
      return AppError(
        title: 'Konfigurasi server salah',
        message: message.isEmpty
            ? 'Edge Function tidak dapat menghubungi project Supabase yang benar.'
            : message,
        hint: 'Periksa secret SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY di Edge Functions.',
        code: 'server_misconfigured',
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

  /// Pesan spesifik untuk kode error yang memang dibuat oleh Edge Function
  /// aplikasi ini (`student-access`, `student-codes`, `create-teacher`, ...).
  ///
  /// Mengembalikan `null` bila kode tidak dikenali, sehingga pemetaan berbasis
  /// status HTTP di [_fromFunction] tetap dipakai.
  static AppError? _domainFunctionError(String code, String message) {
    String msg(String fallback) => message.isEmpty ? fallback : message;

    switch (code) {
      case 'kode_not_found':
        return AppError(
          title: 'Kode tidak ditemukan',
          message: msg('Kode akses tidak dikenali server.'),
          hint: 'Periksa kembali penulisan kode (huruf/angka), lalu minta kode baru bila tetap gagal.',
          code: code,
        );
      case 'not_found':
        return AppError(
          title: 'Data tidak ditemukan',
          message: msg('Data yang diminta tidak ada di server.'),
          hint: 'Muat ulang halaman lalu coba lagi.',
          code: code,
        );
      case 'student_not_found':
      case 'siswa_not_found':
        return AppError(
          title: 'Siswa tidak ditemukan',
          message: msg('Data siswa tidak ditemukan atau tidak aktif.'),
          hint: 'Pastikan siswa terdaftar dan berstatus aktif di kelas tersebut.',
          code: code,
        );
      case 'siswa_inactive':
        return AppError(
          title: 'Siswa tidak aktif',
          message: msg('Siswa ini berstatus tidak aktif.'),
          hint: 'Aktifkan kembali data siswa sebelum menerbitkan kode.',
          code: code,
        );
      case 'invalid_code':
        return AppError(
          title: 'Format kode tidak valid',
          message: msg('Kode akses tidak sesuai format.'),
          hint: 'Salin kode persis seperti yang diberikan admin atau guru.',
          code: code,
        );
      case 'missing_code':
      case 'missing_fields':
        return AppError(
          title: 'Data belum lengkap',
          message: msg('Ada kolom wajib yang kosong.'),
          code: code,
        );
      case 'invalid_claim_token':
        return AppError(
          title: 'Sesi kode berakhir',
          message: msg('Sesi pemilihan nama sudah kedaluwarsa.'),
          hint: 'Masukkan kembali kode akses lalu pilih nama Anda.',
          code: code,
        );
      case 'revoked':
        return AppError(
          title: 'Kode sudah dicabut',
          message: msg('Kode ini telah dicabut oleh admin atau guru.'),
          hint: 'Minta kode baru kepada admin atau guru.',
          code: code,
        );
      case 'used':
        return AppError(
          title: 'Kode sudah dipakai',
          message: msg('Kode sekali pakai ini sudah digunakan.'),
          hint: 'Minta kode baru kepada admin atau guru.',
          code: code,
        );
      case 'expired':
        return AppError(
          title: 'Kode kedaluwarsa',
          message: msg('Masa berlaku kode ini sudah habis.'),
          hint: 'Minta kode baru kepada admin atau guru.',
          code: code,
        );
      case 'wrong_student':
      case 'class_mismatch':
        return AppError(
          title: 'Kode tidak cocok',
          message: msg('Kode ini bukan untuk siswa/kelas tersebut.'),
          hint: 'Pastikan Anda memilih nama dan kelas yang benar.',
          code: code,
        );
      case 'invalid_kelas':
        return AppError(
          title: 'Kelas tidak valid',
          message: msg('Kelas yang dipilih tidak dikenali server.'),
          hint: 'Muat ulang daftar kelas lalu pilih kembali.',
          code: code,
        );
      case 'invalid_siswa':
        return AppError(
          title: 'Siswa tidak valid',
          message: msg('Siswa yang dipilih tidak dikenali server.'),
          hint: 'Muat ulang daftar siswa lalu pilih kembali.',
          code: code,
        );
      case 'invalid_expiry':
        return AppError(
          title: 'Masa berlaku tidak valid',
          message: msg('Masa berlaku harus antara 1 dan 365 hari.'),
          code: code,
        );
      case 'invalid_id':
        return AppError(
          title: 'Kode tidak valid',
          message: msg('ID kode tidak valid.'),
          hint: 'Muat ulang daftar kode lalu coba lagi.',
          code: code,
        );
      case 'student_token_missing':
      case 'student_token_invalid':
      case 'student_token_expired':
      // Kode lama dari versi Edge Function yang belum diperbarui.
      case 'token_expired':
        return AppError(
          title: 'Sesi identitas berakhir',
          message: msg('Identitas siswa di perangkat ini sudah tidak berlaku.'),
          hint: 'Verifikasi ulang kode akses di halaman Identitas agar status tugas dapat '
              'dikirim resmi ke guru.',
          code: code,
        );
      case 'token_mismatch':
        return AppError(
          title: 'Identitas tidak cocok',
          message: msg('Token identitas tidak sesuai dengan data siswa.'),
          hint: 'Verifikasi ulang kode akses di halaman Identitas.',
          code: code,
        );
      case 'too_many_attempts':
        return AppError(
          title: 'Terlalu banyak percobaan',
          message: msg('Demi keamanan, percobaan dibatasi sementara.'),
          hint: 'Tunggu beberapa menit lalu coba lagi.',
          code: code,
        );
      case 'forbidden':
        return AppError(
          title: 'Akses ditolak',
          message: msg('Akun ini tidak berwenang untuk operasi tersebut.'),
          hint: 'Operasi kode akses hanya untuk admin/guru yang berwenang.',
          code: code,
        );
      case 'insert_failed':
      case 'update_failed':
      case 'claim_failed':
      case 'lookup_failed':
      case 'bad_response':
        return AppError(
          title: 'Operasi gagal di server',
          message: msg('Server gagal memproses permintaan.'),
          hint: 'Coba lagi. Bila berulang, periksa log Edge Function di Supabase.',
          code: code,
        );
    }
    return null;
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
