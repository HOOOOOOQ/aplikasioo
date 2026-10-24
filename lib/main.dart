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
  await initializeDateFormatting('id_ID', null);
  tz.initializeTimeZones();

  // Init Supabase if configured
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // publishableKey = nama baru untuk anonKey di supabase_flutter >=2.8
        publishableKey: SupabaseConfig.supabaseAnonKey,
      );
      // Notification permission
      await NotificationService.init();
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  } else {
    debugPrint('[EduTask] Supabase belum dikonfigurasi. Jalankan dengan --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
  }

  runApp(const ProviderScope(child: EduTaskApp()));
}
