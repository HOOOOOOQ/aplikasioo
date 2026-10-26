import 'package:edutask/core/navigation/back_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Mengirim event Back sistem (sama seperti tombol Back Android).
Future<void> pressSystemBack(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  group('resolveBackAction', () {
    test('halaman yang ditumpuk selalu pop satu kali', () {
      expect(
        resolveBackAction(path: '/admin/tugas/1', homeRoute: '/admin', canPop: true),
        BackAction.popRoute,
      );
      expect(
        resolveBackAction(path: '/admin', homeRoute: '/admin', canPop: true, confirmAtRoot: true),
        BackAction.popRoute,
      );
    });

    test('sub-halaman kembali ke tab induk (prefix terpanjang)', () {
      final action = resolveBackAction(
        path: '/admin/tugas/123/status',
        homeRoute: '/admin',
        canPop: false,
        tabRoutes: const ['/admin', '/admin/tugas'],
      );
      expect(action, BackAction.goTo('/admin/tugas'));
    });

    test('tab selain beranda kembali ke beranda, bukan keluar', () {
      expect(
        resolveBackAction(
          path: '/admin/laporan',
          homeRoute: '/admin',
          canPop: false,
          tabRoutes: const ['/admin/siswa', '/admin/tugas', '/admin/laporan'],
          confirmAtRoot: true,
        ),
        BackAction.goTo('/admin'),
      );
    });

    test('di akar: konfirmasi bila diminta, keluar biasa bila tidak', () {
      expect(
        resolveBackAction(path: '/admin', homeRoute: '/admin', canPop: false, confirmAtRoot: true),
        BackAction.confirmExit,
      );
      expect(
        resolveBackAction(path: '/admin', homeRoute: '/admin', canPop: false),
        BackAction.exitApp,
      );
    });

    test('parentTabFor mengabaikan tab itu sendiri dan memilih yang paling spesifik', () {
      expect(parentTabFor('/siswa/tugas', const ['/siswa/tugas']), isNull);
      expect(
        parentTabFor('/siswa/tugas/9/diskusi', const ['/siswa', '/siswa/tugas', '/siswa/tugas/9']),
        '/siswa/tugas/9',
      );
      expect(parentTabFor('/guru/profil', const ['/guru/tugas']), isNull);
      expect(parentTabFor('/guru/profil', const ['/guru', '/guru/tugas']), '/guru');
    });
  });

  group('AppBackGuard', () {
    testWidgets('akar aplikasi: Back menampilkan konfirmasi, bukan keluar langsung', (tester) async {
      var exited = false;
      var confirmations = 0;

      final router = GoRouter(
        initialLocation: '/root',
        routes: [
          GoRoute(
            path: '/root',
            builder: (context, state) => AppBackGuard(
              homeRoute: '/root',
              confirmAtRoot: true,
              exitTitle: 'Keluar dari aplikasi?',
              confirmExit: (context) async {
                confirmations++;
                return false; // pengguna memilih "tetap di aplikasi"
              },
              onExit: () => exited = true,
              child: const Scaffold(body: Text('root')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await pressSystemBack(tester);

      expect(confirmations, 1);
      expect(exited, isFalse);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('konfirmasi diterima menjalankan onExit satu kali', (tester) async {
      var exited = 0;

      final router = GoRouter(
        initialLocation: '/root',
        routes: [
          GoRoute(
            path: '/root',
            builder: (context, state) => AppBackGuard(
              homeRoute: '/root',
              confirmAtRoot: true,
              confirmExit: (context) async => true,
              onExit: () => exited++,
              child: const Scaffold(body: Text('root')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await pressSystemBack(tester);
      expect(exited, 1);
    });

    testWidgets('dua event Back beruntun hanya memicu satu aksi', (tester) async {
      var exited = 0;

      final router = GoRouter(
        initialLocation: '/root',
        routes: [
          GoRoute(
            path: '/root',
            builder: (context, state) => AppBackGuard(
              homeRoute: '/root',
              confirmAtRoot: true,
              confirmExit: (context) async => true,
              onExit: () => exited++,
              child: const Scaffold(body: Text('root')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Dua event Back dikirim tanpa jeda: latch 250 ms harus menahan yang kedua.
      final message = const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/navigation', message, (_) {});
      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/navigation', message, (_) {});
      await tester.pumpAndSettle();

      expect(exited, 1);
    });

    testWidgets('sub-halaman tanpa stack kembali ke beranda, bukan keluar', (tester) async {
      var exited = 0;

      final router = GoRouter(
        initialLocation: '/root/detail',
        routes: [
          GoRoute(
            path: '/root',
            builder: (context, state) => AppBackGuard(
              homeRoute: '/root',
              confirmAtRoot: true,
              onExit: () => exited++,
              child: const Scaffold(body: Text('beranda')),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (context, state) => AppBackGuard(
                  homeRoute: '/root',
                  confirmAtRoot: true,
                  onExit: () => exited++,
                  child: const Scaffold(body: Text('detail')),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      await pressSystemBack(tester);

      expect(find.text('beranda'), findsOneWidget);
      expect(exited, 0);
    });

    testWidgets('halaman hasil push kembali ke halaman sebelumnya', (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            builder: (context, state) => AppBackGuard(
              homeRoute: '/a',
              confirmAtRoot: true,
              child: Scaffold(
                body: Builder(
                  builder: (inner) => Center(
                    child: TextButton(
                      onPressed: () => inner.push('/b'),
                      child: const Text('ke b'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const Scaffold(body: Text('halaman b')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ke b'));
      await tester.pumpAndSettle();
      expect(find.text('halaman b'), findsOneWidget);

      await pressSystemBack(tester);
      expect(find.text('ke b'), findsOneWidget);
    });
  });
}
