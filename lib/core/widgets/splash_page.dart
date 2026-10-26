import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_info.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';
import '../services/onboarding_service.dart';
import '../utils/app_error.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_provider.dart';

/// Splash dengan progres yang benar-benar mengikuti pekerjaan nyata:
/// 1. membaca status onboarding,
/// 2. memulihkan sesi Supabase (maks. 10 detik),
/// 3. menentukan tujuan berdasarkan peran yang sudah diverifikasi.
///
/// Tidak ada jeda palsu dan dashboard tidak pernah dibuka sebelum sesi selesai
/// diverifikasi.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  bool _failed = false;
  AppError? _error;
  int _step = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_running || !mounted) return;
    _running = true;

    setState(() {
      _failed = false;
      _error = null;
      _step = 1;
    });

    try {
      final watch = Stopwatch()..start();

      final onboardingDone = await OnboardingService.isCompleted();

      if (!mounted) return;
      setState(() => _step = 2);

      AppUser? user;
      if (!SupabaseConfig.isNotConfigured && onboardingDone) {
        user = await ref
            .read(currentUserProvider.future)
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      setState(() => _step = 3);

      // Jeda minimum hanya agar animasi tidak berkedip; tidak menahan pengguna
      // bila proses sudah selesai lebih cepat dari 700 ms.
      final remaining = const Duration(milliseconds: 700) - watch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (!mounted) return;

      if (!onboardingDone) {
        context.go('/onboarding');
        return;
      }

      if (user != null && user.isActive && user.role != UserRole.unknown) {
        context.go(user.role == UserRole.admin ? '/admin' : '/guru');
        return;
      }

      context.go('/siswa');
    } on TimeoutException {
      _fail(const AppError(
        title: 'Server terlalu lama merespons',
        message: 'Pemulihan sesi melebihi 10 detik. Periksa koneksi internet Anda.',
        hint: 'Anda tetap bisa memakai mode siswa tanpa login.',
        code: 'timeout',
      ));
    } catch (e) {
      _fail(AppError.from(e));
    } finally {
      _running = false;
    }
  }

  void _fail(AppError error) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = switch (_step) {
      0 => 0.06,
      1 => 0.28,
      2 => 0.62,
      3 => 0.9,
      _ => 1.0,
    };

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          const _SplashBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.86, end: 1).animate(
                        CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
                      ),
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    AppInfo.appName,
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppInfo.tagline,
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0.3,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                  const Spacer(flex: 2),
                  if (_failed)
                    _SplashError(
                      error: _error,
                      onRetry: _bootstrap,
                      onSkip: () => context.go('/siswa'),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: 190,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: Colors.white.withValues(alpha: 0.22),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            switch (_step) {
                              0 => 'Menyiapkan aplikasi…',
                              1 => 'Memeriksa tutorial…',
                              2 => 'Memulihkan sesi…',
                              _ => 'Menyiapkan halaman…',
                            },
                            key: ValueKey(_step),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const Spacer(flex: 2),
                  Text(
                    'v${AppInfo.version} • ${AppInfo.copyright}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF0B2A6B)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _Orb(size: 220, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: _Orb(size: 260, color: Colors.white.withValues(alpha: 0.06)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SplashError extends StatelessWidget {
  final AppError? error;
  final VoidCallback onRetry;
  final VoidCallback onSkip;
  const _SplashError({
    required this.error,
    required this.onRetry,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error?.title ?? 'Gagal menyiapkan aplikasi',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error?.message ?? 'Terjadi kesalahan yang tidak diketahui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (error?.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              error!.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba lagi'),
              ),
              FilledButton.icon(
                onPressed: onSkip,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                ),
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Mode siswa'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
