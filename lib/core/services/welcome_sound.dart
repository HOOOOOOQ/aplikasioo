import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Suara pembuka singkat ("welcome chime") yang diputar sekali per peluncuran.
///
/// Aturan:
/// * hanya sekali per proses aplikasi — kembali dari halaman lain atau
///   rebuild tidak memutar ulang;
/// * menghormati preferensi "Suara pembuka" di Pengaturan;
/// * memakai audio context `notificationEvent`/`sonification` sehingga tidak
///   memaksa output saat perangkat dalam mode senyap atau sedang memutar
///   musik lain (Android), dan `ambient` + `mixWithOthers` di iOS;
/// * kegagalan apa pun (aset hilang, codec tidak didukung) hanya dicatat di
///   debug dan tidak pernah menggagalkan startup.
///
/// Berkas aset: `assets/audio/welcome.wav` (lihat `assets/audio/README.md`).
class WelcomeSoundService {
  WelcomeSoundService._();

  static const String assetPath = 'audio/welcome.wav';

  /// Penjaga agar suara tidak diputar dua kali dalam satu peluncuran, bahkan
  /// bila splash dibangun ulang.
  static bool _playedThisLaunch = false;

  /// Untuk pengujian/preview ulang saat pengembang ingin mendengar aset.
  static void resetLaunchGuard() => _playedThisLaunch = false;

  static bool get playedThisLaunch => _playedThisLaunch;

  /// Putar suara pembuka bila [enabled] dan belum diputar pada peluncuran ini.
  static Future<void> playOnce({required bool enabled}) async {
    if (!enabled || _playedThisLaunch) return;
    _playedThisLaunch = true;

    AudioPlayer? player;
    try {
      player = AudioPlayer();
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(assetPath), volume: 0.65);
    } catch (e) {
      // Aset atau codec tidak tersedia: aplikasi tetap berjalan tanpa suara.
      debugPrint('WelcomeSound: tidak dapat memutar suara pembuka (${e.runtimeType}).');
    } finally {
      // Beri waktu playback selesai sebelum player dilepas.
      Future<void>.delayed(const Duration(seconds: 3), () async {
        try {
          await player?.dispose();
        } catch (_) {
          // abaikan kegagalan dispose
        }
      });
    }
  }
}
