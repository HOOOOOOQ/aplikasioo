import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static bool get isConfigured => SupabaseConfig.isConfigured;

  /// Pastikan supabase terinisialisasi. Jika belum, tampilkan error config.
  static Future<void> ensureInitialized() async {
    if (!isConfigured) return;
    // Supabase.initialize dipanggil di main.dart
  }

  static User? get currentUser => auth.currentUser;
  static Session? get currentSession => auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  static Future<void> signOut() async {
    await auth.signOut();
  }
}
