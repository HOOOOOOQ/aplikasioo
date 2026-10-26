import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edutask/features/auth/presentation/login_page.dart';

/// Regresi keamanan: halaman login tidak boleh membocorkan akun contoh,
/// kata sandi default, atau petunjuk peran administratif.
void main() {
  testWidgets('login memakai label umum dan tanpa petunjuk kredensial',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Email'), findsWidgets);
    expect(find.text('Kata Sandi'), findsWidgets);

    const forbidden = <String>[
      'admin@sekolah.id',
      'admin@edutask',
      'password123',
      'Admin123',
      'admin123',
      'Default password',
      'akun demo',
      'Akun demo',
      'coba:',
    ];
    for (final leak in forbidden) {
      expect(
        find.textContaining(leak),
        findsNothing,
        reason: 'Halaman login tidak boleh menampilkan "$leak".',
      );
    }
  });

  testWidgets('login menyediakan jalur siswa tanpa kredensial',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('siswa'), findsWidgets);
  });
}
