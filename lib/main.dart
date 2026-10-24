import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Jangan biarkan error formatter / timezone bikin FC
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('initializeDateFormatting gagal: $e');
  }
  try {
    tz.initializeTimeZones();
  } catch (e) {
    debugPrint('tz init gagal: $e');
  }

  // Init Supabase jika configured — jangan crash jika gagal
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  } else {
    debugPrint('[EduTask] Supabase belum dikonfigurasi. Jalankan dengan --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
  }

  // Notifikasi lokal tetap init walau Supabase demo — biar tidak FC di halaman siswa
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init gagal: $e');
  }

  // Global error handler biar tidak FC diam-diam
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
  };

  runApp(const ProviderScope(child: EduTaskApp()));
}
