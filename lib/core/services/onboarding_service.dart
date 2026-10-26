import 'package:shared_preferences/shared_preferences.dart';

/// Status penyelesaian tutorial pertama kali.
///
/// Disimpan terpisah dari sesi autentikasi: membuka tutorial TIDAK pernah
/// menghapus atau mengganti sesi pengguna.
class OnboardingService {
  OnboardingService._();

  static const String _completedKey = 'onboarding_completed_v1';

  static Future<bool> isCompleted() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(_completedKey) ?? false;
    } catch (_) {
      // Jika penyimpanan tidak tersedia, jangan menahan pengguna di tutorial.
      return true;
    }
  }

  static Future<void> markCompleted() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_completedKey, true);
    } catch (_) {
      // abaikan: tutorial tetap bisa dilewati
    }
  }

  /// Dipakai tombol "Putar ulang tutorial" di Pengaturan.
  static Future<void> reset() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_completedKey);
    } catch (_) {}
  }
}
