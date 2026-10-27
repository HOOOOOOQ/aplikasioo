import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/routing/app_router.dart';
import 'core/services/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_banner.dart';

class EduTaskApp extends ConsumerWidget {
  const EduTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(appPreferencesProvider);

    return MaterialApp.router(
      title: 'EduTask',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Tema gelap belum disiapkan pada seluruh halaman; nilai preferensi
      // tetap disimpan tetapi UI selalu memakai tema terang yang sudah
      // terverifikasi agar tidak ada kontrol yang tampak aktif tetapi palsu.
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();

        final media = MediaQuery.of(context);
        // Skala teks = pengaturan OS (aksesibilitas) x preferensi aplikasi.
        // Preferensi dijepit 0.9–1.4 saat disimpan; hasil gabungan dibatasi
        // 0.8–2.0 agar layout tidak pecah pada skala ekstrem, sementara
        // pengaturan aksesibilitas besar dari OS tetap dihormati.
        final osScale = media.textScaler.scale(100) / 100;
        final combinedScale = (osScale * prefs.textScale).clamp(0.8, 2.0).toDouble();

        final content = MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combinedScale)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              safeChild,
              // Pita informasi di atas layar: konfigurasi server yang belum
              // lengkap dan status koneksi. Ditempatkan dalam satu kolom agar
              // keduanya tidak saling menimpa.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (SupabaseConfig.isNotConfigured)
                        // Banner hanya informasi: tidak boleh menangkap sentuhan
                        // sehingga AppBar tetap bisa dipakai.
                        IgnorePointer(
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              color: AppColors.warningDark,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              child: const Text(
                                'Mode terbatas — server belum dikonfigurasi pada build ini',
                                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      const AppConnectivityBanner(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        // Di layar lebar (Web desktop), konten dipusatkan agar baris teks tidak
        // melebar berlebihan. Aplikasi Android tetap memakai lebar penuh.
        if (media.size.width < 900) return content;
        return ColoredBox(
          color: AppColors.surface,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
