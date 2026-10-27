import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edutask/core/routing/app_router.dart';
import 'package:edutask/features/auth/domain/app_user.dart';

AppUser user({
  UserRole role = UserRole.admin,
  bool isActive = true,
  String id = 'u1',
}) {
  return AppUser(
    id: id,
    email: 'orang@sekolah.sch.id',
    fullName: 'Orang',
    role: role,
    isActive: isActive,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('resolveRedirect — rute publik', () {
    test('splash, onboarding, login, dan tentang selalu boleh', () {
      for (final path in ['/splash', '/onboarding', '/login', '/tentang']) {
        expect(
          resolveRedirect(path: path, auth: const AsyncValue.data(null)),
          isNull,
          reason: '$path harus tetap dapat dibuka tanpa sesi',
        );
      }
    });

    test('semua rute siswa boleh tanpa login (memakai kode akses)', () {
      for (final path in [
        '/siswa',
        '/siswa/tugas',
        '/siswa/tugas/abc',
        '/siswa/chat/xyz',
        '/siswa/kalender',
      ]) {
        expect(
          resolveRedirect(path: path, auth: const AsyncValue.data(null)),
          isNull,
          reason: '$path adalah area siswa',
        );
      }
    });

    test('halaman non-dashboard lain (bantuan) tidak dijaga', () {
      expect(
        resolveRedirect(path: '/bantuan', auth: const AsyncValue.data(null)),
        isNull,
      );
    });
  });

  group('resolveRedirect — area admin/guru', () {
    test('refresh URL tanpa sesi diarahkan ke login, bukan halaman kosong', () {
      expect(
        resolveRedirect(path: '/admin/tugas', auth: const AsyncValue.data(null)),
        '/login',
      );
      expect(
        resolveRedirect(path: '/guru/laporan', auth: const AsyncValue.data(null)),
        '/login',
      );
    });

    test('selama profil dimuat diarahkan ke splash (bukan login)', () {
      expect(
        resolveRedirect(
          path: '/admin',
          auth: const AsyncValue<AppUser?>.loading(),
        ),
        '/splash',
      );
    });

    test('akun nonaktif selalu ke login walau peran cocok', () {
      expect(
        resolveRedirect(
          path: '/admin',
          auth: AsyncValue.data(user(role: UserRole.admin, isActive: false)),
        ),
        '/login',
      );
      expect(
        resolveRedirect(
          path: '/guru/tugas',
          auth: AsyncValue.data(user(role: UserRole.guru, isActive: false)),
        ),
        '/login',
      );
    });

    test('admin boleh membuka area admin', () {
      expect(
        resolveRedirect(
          path: '/admin',
          auth: AsyncValue.data(user(role: UserRole.admin)),
        ),
        isNull,
      );
    });

    test('guru yang membuka /admin dipindah ke dashboard guru', () {
      expect(
        resolveRedirect(
          path: '/admin/laporan',
          auth: AsyncValue.data(user(role: UserRole.guru)),
        ),
        '/guru',
      );
    });

    test('guru boleh membuka area guru', () {
      expect(
        resolveRedirect(
          path: '/guru/tugas',
          auth: AsyncValue.data(user(role: UserRole.guru)),
        ),
        isNull,
      );
    });

    test('admin boleh membuka area guru (pendampingan)', () {
      expect(
        resolveRedirect(
          path: '/guru',
          auth: AsyncValue.data(user(role: UserRole.admin)),
        ),
        isNull,
      );
    });

    test('peran tidak dikenal tidak boleh masuk area mana pun', () {
      expect(
        resolveRedirect(
          path: '/admin',
          auth: AsyncValue.data(user(role: UserRole.unknown)),
        ),
        '/login',
      );
      expect(
        resolveRedirect(
          path: '/guru',
          auth: AsyncValue.data(user(role: UserRole.unknown)),
        ),
        '/login',
      );
    });

    test('error memuat profil diperlakukan sebagai belum login', () {
      expect(
        resolveRedirect(
          path: '/admin',
          auth: AsyncValue.error(Exception('jaringan'), StackTrace.empty),
        ),
        '/login',
      );
    });
  });

  group('Tab guard', () {
    test('parentTabFor memilih tab paling spesifik', () {
      expect(
        parentTabFor('/admin/tugas/123/status', adminTabRoutes),
        '/admin/tugas',
      );
    });

    test('rute tanpa tab induk kembali ke beranda', () {
      expect(parentTabFor('/admin/guru', adminTabRoutes), isNull);
    });
  });
}
