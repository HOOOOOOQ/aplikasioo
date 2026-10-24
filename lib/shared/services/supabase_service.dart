import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService {
  /// Cek apakah Supabase SDK sudah di-initialize (Supabase.initialize pernah dipanggil)
  static bool get _isInitialized {
    try {
      // ignore: unnecessary_statements
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Apakah siap dipakai (configured + initialized)
  static bool get isReady => SupabaseConfig.isConfigured && _isInitialized;

  /// Client aman — throw dengan pesan jelas jika belum siap.
  /// Untuk kode yang sudah guard isConfigured/isReady, ini tidak akan throw.
  static SupabaseClient get client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase belum dikonfigurasi (SUPABASE_URL/ANON_KEY kosong). Build dengan --dart-define.');
    }
    if (!_isInitialized) {
      throw StateError('Supabase belum di-initialize. Panggil Supabase.initialize dulu.');
    }
    return Supabase.instance.client;
  }

  /// Versi nullable — tidak throw, return null jika belum siap. Cocok untuk guard.
  static SupabaseClient? get tryClient {
    if (!isReady) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static GoTrueClient? get tryAuth => tryClient?.auth;

  static User? get currentUser => tryAuth?.currentUser;
  static Session? get currentSession => tryAuth?.currentSession;
  static bool get isLoggedIn => currentUser != null;

  static Future<void> signOut() async {
    await tryAuth?.signOut();
  }

  static bool get isConfigured => SupabaseConfig.isConfigured;
}
