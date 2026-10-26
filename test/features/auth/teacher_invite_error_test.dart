import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/features/auth/data/auth_repository.dart';

/// Unit test untuk pemetaan error Edge Function create-teacher.
/// Fokus: membedakan 401 (kredensial/sesi/project), 403 (bukan admin),
/// 404 (belum dideploy), 409 (duplikat), 500 (secret server), dan network.
void main() {
  group('TeacherInviteException.fromFunctionError', () {
    test('401 dari function (body {error: Unauthorized}) -> unauthorized', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 401,
        details: {'error': 'Unauthorized: token admin tidak valid atau sudah kedaluwarsa.'},
        reasonPhrase: 'Unauthorized',
      );
      expect(e.code, 'unauthorized');
      expect(e.status, 401);
      expect(e.message, contains('HTTP 401'));
      expect(e.message, contains('project'));
    });

    test('401 dari gateway (JWT invalid) tetap unauthorized', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 401,
        details: {'code': 401, 'message': 'Invalid JWT'},
        reasonPhrase: 'Unauthorized',
      );
      expect(e.code, 'unauthorized');
      expect(e.message, contains('HTTP 401'));
    });

    test('403 -> forbidden dan menyebut role admin', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 403,
        details: {'error': 'Forbidden: hanya admin aktif yang boleh membuat akun guru.'},
        reasonPhrase: 'Forbidden',
      );
      expect(e.code, 'forbidden');
      expect(e.message, contains('role = admin'));
    });

    test('404 -> not_deployed (bukan menyalahkan sesi)', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 404,
        details: {'message': 'Requested function was not found'},
        reasonPhrase: 'Not Found',
      );
      expect(e.code, 'not_deployed');
      expect(e.message, contains('supabase functions deploy create-teacher'));
    });

    test('409 email duplikat -> invalid_input tanpa retry', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 409,
        details: {'error': 'Email sudah terdaftar sebagai pengguna.'},
        reasonPhrase: 'Conflict',
      );
      expect(e.code, 'invalid_input');
      expect(e.message, contains('Email sudah terdaftar'));
    });

    test('500 -> server dan menyebut secret', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 500,
        details: {'error': 'Server misconfigured: secret SUPABASE_SERVICE_ROLE_KEY wajib tersedia.'},
        reasonPhrase: 'Internal Server Error',
      );
      expect(e.code, 'server');
      expect(e.message, contains('SUPABASE_SERVICE_ROLE_KEY'));
    });

    test('status 0 (transport) -> network', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 0,
        details: null,
        reasonPhrase: null,
      );
      expect(e.code, 'network');
    });

    test('hanya session_expired yang memaksa login ulang otomatis', () {
      const session = TeacherInviteException('session_expired', 'Sesi berakhir.');
      final unauthorized = TeacherInviteException.fromFunctionError(status: 401, details: null);
      expect(session.requiresRelogin, isTrue);
      expect(unauthorized.requiresRelogin, isFalse);
    });

    test('pesan tidak pernah memuat password atau service_role key', () {
      final e = TeacherInviteException.fromFunctionError(
        status: 500,
        details: {'error': 'boom', 'password': 'rahasia', 'service_role': 'secret-key'},
        reasonPhrase: 'Internal Server Error',
      );
      expect(e.message, isNot(contains('rahasia')));
      expect(e.message, isNot(contains('secret-key')));
    });
  });
}
