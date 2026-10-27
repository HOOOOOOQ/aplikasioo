import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/url_strategy.dart';
import 'core/services/platform_capabilities.dart';
import 'features/notifications/notification_service.dart';

/// Titik masuk aplikasi (Android & Web).
///
/// Semua langkah startup bersifat "gagal-aman": kesalahan konfigurasi atau
/// plugin tidak boleh membuat aplikasi berhenti sebelum UI tampil. Bila
/// Supabase tidak dapat diinisialisasi, aplikasi tetap berjalan dan menampilkan
/// penjelasan di splash/login (bukan layar putih).
Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exception}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformDispatcher] $error');
      return true;
    };

    // URL Web: default hash strategy (aman di semua host). Path strategy hanya
    // bila diminta eksplisit lewat --dart-define=USE_PATH_URL_STRATEGY=true.
    configureUrlStrategy(
      usePathStrategy: const bool.fromEnvironment('USE_PATH_URL_STRATEGY'),
    );

    try {
      await initializeDateFormatting('id_ID', null);
    } catch (e) {
      debugPrint('initializeDateFormatting gagal: $e');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
          // Sesi dipulihkan otomatis dari penyimpanan platform yang didukung
          // (SharedPreferences di Android, localStorage di Web).
          debug: false,
        );
      } catch (e) {
        debugPrint('Supabase init gagal: $e');
      }
    } else {
      debugPrint(
        '[EduTask] Supabase belum dikonfigurasi. Jalankan dengan '
        '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    // Notifikasi lokal hanya pada Android/iOS (Web: no-op, lihat NotificationService).
    if (PlatformCapabilities.supportsLocalNotifications) {
      try {
        await NotificationService.init();
      } catch (e) {
        debugPrint('NotificationService init gagal: $e');
      }
    }

    runApp(const ProviderScope(child: EduTaskApp()));
  }, (error, stack) {
    debugPrint('[Uncaught] $error');
  });
}
