import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edutask/core/services/connectivity_service.dart';
import 'package:edutask/core/widgets/connectivity_banner.dart';

/// Widget uji yang mengganti stream status jaringan tanpa menyentuh plugin.
class _BannerHarness extends StatelessWidget {
  const _BannerHarness(this.status);

  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        networkStatusProvider.overrideWith((ref) => Stream.value(status)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AppConnectivityBanner()),
      ),
    );
  }
}

void main() {
  group('NetworkStatus.fromResults', () {
    test('koneksi seluler / wifi / ethernet dianggap online', () {
      expect(NetworkStatus.fromResults([ConnectivityResult.wifi]),
          NetworkStatus.online);
      expect(NetworkStatus.fromResults([ConnectivityResult.mobile]),
          NetworkStatus.online);
      expect(NetworkStatus.fromResults([ConnectivityResult.ethernet]),
          NetworkStatus.online);
    });

    test('hanya none yang berarti offline', () {
      expect(NetworkStatus.fromResults([ConnectivityResult.none]),
          NetworkStatus.offline);
      // Plugin pada sebagian platform mengirim gabungan: none + wifi berarti
      // masih ada jalur aktif → online.
      expect(
        NetworkStatus.fromResults(
            [ConnectivityResult.none, ConnectivityResult.wifi]),
        NetworkStatus.online,
      );
    });

    test('daftar kosong tidak diklaim offline (tidak ada info)', () {
      expect(NetworkStatus.fromResults(const []), NetworkStatus.unknown);
      expect(NetworkStatus.unknown.isOffline, isFalse);
    });

    test('isOffline hanya benar untuk status offline', () {
      expect(NetworkStatus.offline.isOffline, isTrue);
      expect(NetworkStatus.online.isOffline, isFalse);
    });
  });

  group('AppConnectivityBanner', () {
    testWidgets('tidak menampilkan apa pun saat online', (tester) async {
      await tester.pumpWidget(const _BannerHarness(NetworkStatus.online));
      await tester.pump();
      expect(find.textContaining('Tidak ada koneksi'), findsNothing);
    });

    testWidgets('tidak menampilkan apa pun saat status belum diketahui',
        (tester) async {
      await tester.pumpWidget(const _BannerHarness(NetworkStatus.unknown));
      await tester.pump();
      expect(find.textContaining('Tidak ada koneksi'), findsNothing);
    });

    testWidgets('menampilkan pita peringatan saat offline', (tester) async {
      await tester.pumpWidget(const _BannerHarness(NetworkStatus.offline));
      await tester.pump();
      expect(find.textContaining('Tidak ada koneksi'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('pita offline tidak menangkap sentuhan', (tester) async {
      await tester.pumpWidget(const _BannerHarness(NetworkStatus.offline));
      await tester.pump();
      // IgnorePointer membungkus seluruh pita: ketukan diteruskan ke bawah.
      expect(
        find.ancestor(
          of: find.textContaining('Tidak ada koneksi'),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });
  });
}
