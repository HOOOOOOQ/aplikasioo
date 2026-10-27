import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutask/core/services/onboarding_service.dart';
import 'package:edutask/features/onboarding/presentation/onboarding_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('belum selesai pada instalasi baru', () async {
      expect(await OnboardingService.isCompleted(), isFalse);
    });

    test('tersimpan setelah diselesaikan', () async {
      await OnboardingService.markCompleted();
      expect(await OnboardingService.isCompleted(), isTrue);
    });

    test('reset mengembalikan status belum selesai', () async {
      await OnboardingService.markCompleted();
      await OnboardingService.reset();
      expect(await OnboardingService.isCompleted(), isFalse);
    });
  });

  group('Halaman onboarding', () {
    testWidgets('menampilkan langkah pertama, indikator, dan tombol Lewati',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kenali EduTask'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
      // Langkah pertama belum punya tombol kembali.
      expect(find.text('Kembali'), findsNothing);
      // Tidak boleh meminta kredensial apa pun.
      expect(find.textContaining('Kata Sandi'), findsNothing);
      expect(find.textContaining('kode akses'), findsNothing);
    });

    testWidgets('Lanjut berpindah langkah dan Kembali tersedia',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Masuk sebagai Guru atau Admin'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Kenali EduTask'), findsOneWidget);
    });

    testWidgets('tutorial memiliki 8 langkah sesuai alur', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingPage()),
      );
      await tester.pumpAndSettle();

      const titles = [
        'Kenali EduTask',
        'Masuk sebagai Guru atau Admin',
        'Siswa: Hubungkan Kode Akses',
        'Jadwal & Tugas',
        'Kerjakan & Kumpulkan Tugas',
        'Chat dengan Guru',
        'Pengumuman & Notifikasi',
        'Cari Bantuan',
      ];

      expect(find.text(titles.first), findsOneWidget);
      expect(find.text('Langkah 1 dari ${titles.length}'), findsOneWidget);

      for (var i = 1; i < titles.length; i++) {
        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text(titles[i]), findsOneWidget);
      }

      expect(find.text('Langkah ${titles.length} dari ${titles.length}'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Lanjut'), findsNothing);
    });

    testWidgets('langkah terakhir memakai tombol Mulai Sekarang',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingPage()),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Cari Bantuan'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Lanjut'), findsNothing);
    });

    testWidgets('showSkip=false menyembunyikan tombol Lewati', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingPage(showSkip: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lewati'), findsNothing);
    });
  });
}
