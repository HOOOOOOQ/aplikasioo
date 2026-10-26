import 'package:edutask/core/services/session_guard.dart';
import 'package:edutask/core/utils/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesi tidak boleh "dipalsukan" agar lolos: pengujian di sini hanya memeriksa
/// logika klasifikasi (sesi valid / kedaluwarsa / gangguan jaringan) dan
/// pemetaan kode error. Tidak ada token yang dibuat di klien.
void main() {
  group('SessionGuard.isSessionErrorCode', () {
    test('kode yang berarti sesi bermasalah dikenali', () {
      for (final code in [
        'session_expired',
        'invalid_token',
        'missing_token',
        'unauthorized',
        'no_session',
      ]) {
        expect(SessionGuard.isSessionErrorCode(code), isTrue, reason: code);
      }
    });

    test('kode domain kode akses tidak dianggap masalah sesi', () {
      for (final code in ['not_found', 'used', 'expired', 'revoked', 'wrong_student', null]) {
        expect(SessionGuard.isSessionErrorCode(code), isFalse, reason: '$code');
      }
    });
  });

  group('SessionGuard.isNetworkFailure', () {
    test('masalah koneksi dikenali, bukan sesi dicabut', () {
      final failures = [
        Exception('SocketException: Failed host lookup'),
        Exception('ClientException: Connection refused'),
        Exception('TimeoutException after 0:00:10.000000'),
        Exception('XMLHttpRequest error.'),
      ];
      for (final e in failures) {
        expect(SessionGuard.isNetworkFailure(e), isTrue, reason: e.toString());
      }
    });

    test('penolakan kredensial tidak dianggap gangguan jaringan', () {
      final failures = [
        Exception('Invalid Refresh Token: Refresh Token Not Found'),
        Exception('AuthException: User not found'),
        Exception('JWT expired'),
      ];
      for (final e in failures) {
        expect(SessionGuard.isNetworkFailure(e), isFalse, reason: e.toString());
      }
    });
  });

  group('SessionResult', () {
    test('ready membawa access token dan boleh dipakai', () {
      const result = SessionResult.ready('access-token-abc');
      expect(result.isReady, isTrue);
      expect(result.accessToken, 'access-token-abc');
      expect(result.requiresRelogin, isFalse);
      expect(result.degraded, isFalse);
    });

    test('ready degraded (offline) tetap membawa token lama', () {
      const result = SessionResult.ready('old-token', degraded: true);
      expect(result.isReady, isTrue);
      expect(result.degraded, isTrue);
    });

    test('expired meminta login ulang dan tidak membawa token', () {
      const result = SessionResult.failed(
        SessionState.expired,
        AppError(title: 'Sesi login berakhir', message: 'habis', code: 'session_expired'),
      );
      expect(result.isReady, isFalse);
      expect(result.requiresRelogin, isTrue);
      expect(result.accessToken, isNull);
      expect(result.error?.code, 'session_expired');
    });

    test('noSession meminta login ulang', () {
      const result = SessionResult.failed(
        SessionState.noSession,
        AppError(title: 'Belum masuk', message: 'tidak ada sesi', code: 'no_session'),
      );
      expect(result.isReady, isFalse);
      expect(result.requiresRelogin, isTrue);
    });

    test('networkError bukan berarti sesi dicabut', () {
      const result = SessionResult.failed(
        SessionState.networkError,
        AppError(title: 'Tidak ada koneksi', message: 'offline', code: 'network'),
      );
      expect(result.isReady, isFalse);
      expect(result.requiresRelogin, isFalse);
      expect(result.error?.code, 'network');
    });
  });

  group('SessionGuard.ensureValidSession tanpa konfigurasi', () {
    test('tidak melempar dan melaporkan sesi belum tersedia', () async {
      // Dalam unit test Supabase belum diinisialisasi; guard harus berhenti
      // dengan rapi, bukan crash atau menganggap token kedaluwarsa.
      final result = await SessionGuard.ensureValidSession();
      expect(result.isReady, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.code, 'config');
    });
  });
}
