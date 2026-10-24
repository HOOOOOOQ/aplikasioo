import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/notifications/notification_service.dart';

void main() {
  // Bungkus seluruh startup dalam runZonedGuarded agar async uncaught juga tertangkap
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Tangkap semua error framework
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exception} ${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformDispatcher] $error $stack');
      return true; // jangan crash
    };

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
      } catch (e, s) {
        debugPrint('Supabase init failed: $e $s');
      }
    } else {
      debugPrint('[EduTask] Supabase belum dikonfigurasi. Jalankan dengan --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
    }

    // Notifikasi lokal tetap init walau Supabase demo — biar tidak FC di halaman siswa
    try {
      await NotificationService.init();
    } catch (e, s) {
      debugPrint('NotificationService init gagal: $e $s');
    }

    runApp(const ProviderScope(child: EduTaskApp()));
  }, (error, stack) {
    debugPrint('[Uncaught] $error $stack');
  });
}
