import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';

/// Halaman galat navigasi: tetap menjelaskan apa yang salah, memberi jalan
/// keluar, dan tidak pernah menampilkan stack trace mentah ke pengguna.
class AppRouteErrorPage extends StatelessWidget {
  final String title;
  final String message;
  final String fallbackRoute;
  final String? location;

  const AppRouteErrorPage({
    super.key,
    required this.title,
    required this.message,
    required this.fallbackRoute,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terjadi kesalahan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => context.go(fallbackRoute),
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Kembali ke beranda'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(fallbackRoute);
                    }
                  },
                  child: const Text('Kembali'),
                ),
                if (location != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    location!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
