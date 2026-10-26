import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_colors.dart';

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
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();
        if (SupabaseConfig.isNotConfigured) {
          return Stack(
            children: [
              safeChild,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: AppColors.warning,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: const Text('Mode Demo: Supabase belum dikonfigurasi. Beberapa fitur terbatas.', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          );
        }
        return safeChild;
      },
    );
  }
}
