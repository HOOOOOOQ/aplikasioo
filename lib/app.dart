import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class EduTaskApp extends ConsumerWidget {
  const EduTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'EduTask',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();

        // MediaQuery dibatasi agar layout tetap rapi pada pengaturan ukuran
        // teks ekstrem, sambil tetap menghormati aksesibilitas.
        final media = MediaQuery.of(context);
        final textScaler = media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);

        return MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          child: Stack(
            children: [
              safeChild,
              if (SupabaseConfig.isNotConfigured)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
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
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    // Hindari glow berlebihan di Android; tetap mendukung tarik-untuk-refresh.
    return child;
  }
}
