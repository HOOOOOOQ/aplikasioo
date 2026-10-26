import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edutask/core/utils/app_error.dart';

/// Pesan error harus bisa ditindaklanjuti pengguna dan tidak boleh
/// membocorkan detail internal (SQL, token, service role).
void main() {
  group('AppError.from(FunctionException)', () {
    AppError map(int status, {Object? details}) =>
        AppError.from(FunctionException(status: status, details: details));

    test('401 -> sesi tidak valid', () {
      final e = map(401, details: {'error': 'Token tidak valid'});
      expect(e.code, 'unauthorized');
      expect(e.title, 'Sesi tidak valid');
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

    test('unique violation 23505 menyebut data sudah ada', () {
      final e = AppError.from(
        PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505'),
      );
      expect(e.shortMessage.isNotEmpty, isTrue);
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
