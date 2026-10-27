import 'package:flutter/foundation.dart';

/// Kemampuan platform yang memengaruhi fitur mana yang boleh diaktifkan.
///
/// Dipakai agar Flutter Web tidak memanggil plugin khusus Android (notifikasi
/// lokal, penjadwalan alarm) dan agar UI bisa menampilkan penjelasan yang jujur
/// ketika sebuah fitur memang hanya tersedia di aplikasi Android.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMobile => isAndroid || isIOS;

  /// Notifikasi lokal + penjadwalan pengingat hanya didukung di Android/iOS.
  static bool get supportsLocalNotifications => isMobile;

  /// Pemilihan file dari penyimpanan perangkat: didukung Web (input file) dan
  /// Android/iOS (file picker native).
  static bool get supportsFilePicker => true;

  /// Membuka aplikasi eksternal (Instagram, tautan lampiran).
  static bool get supportsExternalLinks => true;

  /// Nama platform untuk pesan ke pengguna.
  static String get label {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    return defaultTargetPlatform.name;
  }
}
