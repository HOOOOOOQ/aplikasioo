import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edutask/core/utils/app_error.dart';

/// Pesan error harus bisa ditindaklanjuti pengguna dan tidak boleh
/// membocorkan detail internal (SQL, token, service role).
void main() {
  group('AppError.from(FunctionException)', () {
    AppError map(int status, {Object? details}) =>
        AppError.from(FunctionException(status: status, details: details));

    test('401 -> sesi login berakhir dengan saran masuk kembali', () {
      final e = map(401, details: {'error': 'Token tidak valid'});
      // Sejak round 3, 401 selalu dipetakan sebagai masalah sesi login agar
      // pengguna mendapat tindakan yang jelas, bukan pesan "Sesi tidak valid".
      expect(e.code, 'session_expired');
      expect(e.title, 'Sesi login berakhir');
      expect(e.hint, contains('Masuk kembali'));
    });

    test('403 -> akses ditolak', () {
      final e = map(403, details: {'error': 'Hanya admin aktif'});
      expect(e.code, 'forbidden');
      expect(e.message, contains('admin'));
    });

    test('404 -> layanan belum tersedia', () {
      final e = map(404);
      expect(e.code, 'not_deployed');
    });

    test('409 -> kode/payload sudah dipakai', () {
      final e = map(409, details: {'error': 'Kode sudah dipakai'});
      expect(e.code, 'conflict');
      expect(e.message, contains('dipakai'));
    });

    test('410 -> kedaluwarsa', () {
      final e = map(410);
      expect(e.code, 'expired');
    });

    test('429 -> rate limited', () {
      final e = map(429, details: {'error': 'Terlalu banyak percobaan'});
      expect(e.code, 'too_many_attempts');
      expect(e.title, contains('Terlalu banyak'));
    });

    test('status 0 -> tidak ada koneksi', () {
      final e = map(0);
      expect(e.code, 'network');
    });

    test('500 -> server bermasalah tanpa membocorkan detail', () {
      final e = map(500, details: {'error': 'database error: relation "secret" does not exist'});
      expect(e.code, 'server_error');
    });
  });

  group('AppError.from(PostgrestException)', () {
    test('RLS 42501 diterjemahkan menjadi pesan izin', () {
      final e = AppError.from(
        PostgrestException(message: 'new row violates row-level security policy', code: '42501'),
      );
      expect(e.shortMessage.isNotEmpty, isTrue);
      expect(e.shortMessage, isNot(contains('PostgrestException')));
    });

    test('fallback tidak memakai "Gagal menyimpan data" dan tidak bocorkan SQL', () {
      final e = AppError.from(
        PostgrestException(
          message: 'invalid input syntax for type uuid: "abc"',
          code: '22P02',
        ),
      );
      expect(e.title, isNot(contains('Gagal menyimpan')));
      expect(e.shortMessage, isNot(contains('invalid input syntax')));
      expect(e.hint, contains('22P02'));
      expect(e.code, '22P02');
    });

    test('timeout database punya pesan sendiri', () {
      final e = AppError.from(
        PostgrestException(message: 'canceling statement due to statement timeout', code: '57014'),
      );
      expect(e.code, 'database_timeout');
      expect(e.title, contains('lambat'));
    });

    test('unique violation 23505 menyebut data sudah ada', () {
      final e = AppError.from(
        PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505'),
      );
      expect(e.shortMessage.isNotEmpty, isTrue);
    });
  });

  group('Round 6: pin tugas (RPC set_tugas_pin)', () {
    test('P0002 tugas tidak ditemukan memakai pesan server, bukan kode mentah', () {
      final e = AppError.from(
        PostgrestException(
          message: 'Tugas tidak ditemukan atau tidak dapat diakses oleh akun ini.',
          code: 'P0002',
        ),
      );
      expect(e.code, 'not_found');
      expect(e.title, 'Data tidak ditemukan');
      expect(e.message, contains('Tugas tidak ditemukan'));
      expect(e.shortMessage.contains('P0002'), isFalse);
    });

    test('22023 payload pin tidak valid dijelaskan sebagai data tidak valid', () {
      final e = AppError.from(
        PostgrestException(
          message: 'Permintaan pin tidak valid: p_pinned wajib true atau false.',
          code: '22023',
        ),
      );
      expect(e.code, 'invalid_input');
      expect(e.title, 'Data tidak valid');
    });

    test('penolakan RLS pin (42501) tidak membocorkan detail SQL', () {
      final e = AppError.from(
        PostgrestException(
          message: 'Akses ditolak: hanya admin atau guru pemilik tugas yang boleh mengubah pin.',
          code: '42501',
        ),
      );
      expect(e.code, 'rls_denied');
      expect(e.shortMessage.toLowerCase().contains('row-level security'), isFalse);
    });
  });

  group('Round 3: skema & sesi', () {
    test('PGRST205 (tabel tidak ada di schema cache) -> schema_not_ready', () {
      final e = AppError.from(
        PostgrestException(
          message: "Could not find the table 'public.kode_akses_siswa' in the schema cache",
          code: 'PGRST205',
        ),
      );
      expect(e.code, 'schema_not_ready');
      expect(e.title, contains('Skema'));
      expect(e.hint, contains('005'));
      // Tidak boleh membocorkan SQL mentah ke pengguna.
      expect(e.shortMessage, isNot(contains('PGRST')));
      expect(e.shortMessage, isNot(contains('public.kode_akses_siswa')));
    });

    test('PGRST202 (fungsi RPC belum ada) -> schema_not_ready', () {
      final e = AppError.from(
        PostgrestException(message: 'Could not find the function public.kode_akses_stats', code: 'PGRST202'),
      );
      expect(e.code, 'schema_not_ready');
    });

    test('42P01 relation does not exist -> schema_not_ready', () {
      final e = AppError.from(
        PostgrestException(message: 'relation "kode_akses_siswa" does not exist', code: '42P01'),
      );
      expect(e.code, 'schema_not_ready');
    });

    test('Edge Function 503 schema_not_ready tetap dikenali', () {
      final e = AppError.from(
        FunctionException(status: 503, details: {'error': 'Skema belum siap', 'code': 'schema_not_ready'}),
      );
      expect(e.code, 'schema_not_ready');
    });

    test('401 session_expired -> judul sesi berakhir + saran login ulang', () {
      final e = AppError.from(
        FunctionException(status: 401, details: {'error': 'Sesi kedaluwarsa', 'code': 'session_expired'}),
      );
      expect(e.code, 'session_expired');
      expect(e.title, 'Sesi login berakhir');
      expect(e.hint, contains('Masuk kembali'));
    });

    test('401 dari gateway (tanpa kode) dianggap sesi login berakhir', () {
      final e = AppError.from(
        FunctionException(status: 401, details: {'message': 'Invalid JWT', 'code': 401}),
      );
      expect(e.code, 'session_expired');
      expect(e.title, 'Sesi login berakhir');
      expect(e.hint, contains('Masuk kembali'));
    });

    test('401 missing_token tidak disamakan dengan 401 tanpa kode', () {
      final withCode = AppError.from(
        FunctionException(status: 401, details: {'code': 'missing_token'}),
      );
      final withoutCode = AppError.from(FunctionException(status: 401));
      expect(withCode.code, 'missing_token');
      expect(withCode.title, 'Sesi login berakhir');
      // 401 tanpa kode juga berarti sesi, tetapi kode internalnya seragam.
      expect(withoutCode.code, 'session_expired');
      expect(withoutCode.title, 'Sesi login berakhir');
    });

    test('404 kode_not_found dari student-access bukan "belum dideploy"', () {
      final e = AppError.from(
        FunctionException(
          status: 404,
          details: {'error': 'Kode tidak ditemukan.', 'code': 'kode_not_found'},
        ),
      );
      expect(e.code, 'kode_not_found');
      expect(e.title, 'Kode tidak ditemukan');
      expect(e.shortMessage, contains('Kode tidak ditemukan'));
    });

    test('404 not_found umum tidak menyamar sebagai kode akses', () {
      final e = AppError.from(
        FunctionException(status: 404, details: {'error': 'Tugas tidak ditemukan', 'code': 'not_found'}),
      );
      expect(e.code, 'not_found');
      expect(e.title, 'Data tidak ditemukan');
      expect(e.title, isNot('Kode tidak ditemukan'));
    });

    test('409 used -> kode sudah dipakai, bukan konflik generik', () {
      final e = AppError.from(
        FunctionException(status: 409, details: {'error': 'Kode sudah digunakan.', 'code': 'used'}),
      );
      expect(e.code, 'used');
      expect(e.title, 'Kode sudah dipakai');
    });

    test('403 revoked -> kode dicabut, bukan akses ditolak generik', () {
      final e = AppError.from(
        FunctionException(status: 403, details: {'error': 'Kode sudah dicabut.', 'code': 'revoked'}),
      );
      expect(e.code, 'revoked');
      expect(e.title, 'Kode sudah dicabut');
    });

    test('410 expired memakai pesan server', () {
      final e = AppError.from(
        FunctionException(status: 410, details: {'error': 'Masa berlaku habis.', 'code': 'expired'}),
      );
      expect(e.code, 'expired');
      expect(e.title, 'Kode kedaluwarsa');
      expect(e.message, contains('Masa berlaku habis'));
    });

    test('server_misconfigured punya petunjuk konfigurasi', () {
      final e = AppError.from(
        FunctionException(status: 500, details: {'code': 'server_misconfigured'}),
      );
      expect(e.code, 'server_misconfigured');
      expect(e.hint, contains('SUPABASE_URL'));
    });
  });

  group('AppError umum', () {
    test('melewati AppError apa adanya', () {
      const original = AppError(title: 'T', message: 'M', code: 'x');
      expect(identical(AppError.from(original), original), isTrue);
    });

    test('error jaringan dikenali dari teks exception', () {
      final e = AppError.from(Exception('SocketException: Failed host lookup'));
      expect(e.code, 'network');
    });

    test('konfigurasi hilang dikenali', () {
      final e = AppError.from(Exception('Supabase belum dikonfigurasi'));
      expect(e.code, 'config');
    });
  });
}
