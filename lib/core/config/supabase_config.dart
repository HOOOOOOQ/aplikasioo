import 'package:flutter/foundation.dart';

/// Konfigurasi Supabase untuk EduTask.
/// Gunakan --dart-define untuk menyuntikkan nilai saat build.
///
/// Contoh run:
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isNotConfigured => !isConfigured;

  static void debugPrintConfig() {
    if (kDebugMode) {
      debugPrint('[SupabaseConfig] URL: ${supabaseUrl.isEmpty ? "(kosong)" : supabaseUrl}');
      debugPrint('[SupabaseConfig] AnonKey: ${supabaseAnonKey.isEmpty ? "(kosong)" : "${supabaseAnonKey.substring(0, 10)}..."}');
      debugPrint('[SupabaseConfig] isConfigured: $isConfigured');
    }
  }
}
