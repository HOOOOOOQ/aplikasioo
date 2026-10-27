import 'package:edutask/core/services/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformCapabilities', () {
    test('konsisten dengan kIsWeb dan target platform aktif', () {
      expect(PlatformCapabilities.isWeb, kIsWeb);
      expect(PlatformCapabilities.isAndroid, defaultTargetPlatform == TargetPlatform.android && !kIsWeb);
      expect(PlatformCapabilities.isIOS, defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb);
    });

    test('isMobile adalah gabungan Android dan iOS', () {
      expect(
        PlatformCapabilities.isMobile,
        PlatformCapabilities.isAndroid || PlatformCapabilities.isIOS,
      );
    });

    test('notifikasi lokal hanya diklaim pada platform seluler', () {
      expect(
        PlatformCapabilities.supportsLocalNotifications,
        PlatformCapabilities.isMobile,
      );
    });

    test('label tidak pernah kosong dan mengikuti platform aktif', () {
      final label = PlatformCapabilities.label;
      expect(label.trim(), isNotEmpty);
      if (PlatformCapabilities.isWeb) {
        expect(label, 'Web');
      } else {
        // Label memakai kapitalisasi merek ('Android'/'iOS'); nama platform
        // dari Flutter memakai huruf kecil, jadi perbandingan tanpa beda huruf.
        expect(label.toLowerCase(), defaultTargetPlatform.name.toLowerCase());
      }
    });
  });
}
