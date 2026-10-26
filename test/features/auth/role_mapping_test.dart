import 'package:flutter_test/flutter_test.dart';

import 'package:edutask/features/auth/domain/app_user.dart';

/// Peran (role) hanya boleh berasal dari database. Nilai tak dikenal tidak
/// boleh "naik" menjadi admin di sisi klien.
void main() {
  group('UserRoleX.fromString', () {
    test('memetakan peran yang sah', () {
      expect(UserRoleX.fromString('admin'), UserRole.admin);
      expect(UserRoleX.fromString('ADMIN'), UserRole.admin);
      expect(UserRoleX.fromString('guru'), UserRole.guru);
      expect(UserRoleX.fromString('Guru'), UserRole.guru);
    });

    test('peran siswa/tak dikenal tidak pernah menjadi admin', () {
      for (final value in ['siswa', 'student', 'user', '', null, 'admin ', 'administrator']) {
        expect(
          UserRoleX.fromString(value),
          UserRole.unknown,
          reason: 'nilai "$value" tidak boleh dipetakan ke peran istimewa',
        );
      }
    });

    test('label peran berbahasa Indonesia', () {
      expect(UserRole.admin.label, 'Admin');
      expect(UserRole.guru.label, 'Guru');
      expect(UserRole.unknown.label, 'Tidak dikenal');
    });
  });

  group('AppUser', () {
    test('membaca profil dari database dan menandai akun nonaktif', () {
      final user = AppUser.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'email': 'guru@example.test',
        'full_name': 'Guru Contoh',
        'role': 'guru',
        'is_active': false,
      });

      expect(user.id, '11111111-1111-1111-1111-111111111111');
      expect(user.fullName, 'Guru Contoh');
      expect(user.role, UserRole.guru);
      expect(user.isActive, isFalse);
    });

    test('profil tanpa peran tidak dianggap admin', () {
      final user = AppUser.fromJson({
        'id': '22222222-2222-2222-2222-222222222222',
        'email': 'x@example.test',
        'full_name': '',
        'role': null,
        'is_active': true,
      });

      expect(user.role, UserRole.unknown);
      expect(user.isAdmin, isFalse);
    });
  });
}
