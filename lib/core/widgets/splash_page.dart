import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../config/app_info.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';
import '../services/onboarding_service.dart';
import '../utils/app_error.dart';
import 'app_banner.dart';

/// Splash screen EduTask.
///
/// Prinsip:
///  * Tidak ada delay hiasan yang panjang — animasi berjalan sambil benar-benar
///    memeriksa onboarding + memulihkan sesi.
///  * Selalu ada batas waktu (<= 10 detik) dan jalur keluar bila gagal.
///  * Dashboard tidak pernah ditampilkan sebelum profil & role terverifikasi.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  static const Duration _minimumDisplay = Duration(milliseconds: 650);
  static const Duration _sessionTimeout = Duration(seconds: 10);

  late final AnimationController _animation;
  late final Animation<double> _logoScale;
  late final Animation<double> _fade;

  bool _navigated = false;
  bool _failed = false;
  String _status = 'Menyiapkan aplikasi…';
  double _progress = 0.08;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _logoScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _animation, curve: const Interval(0, 0.7, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _setStatus(String text, double progress) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _progress = progress;
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _failed = false;
      _error = null;
      _navigated = false;
    });

    final startedAt = DateTime.now();

    try {
      _setStatus('Memeriksa status tutorial…', 0.25);
      final onboardingDone = await OnboardingService.isCompleted();

      if (!onboardingDone) {
        await _waitMinimum(startedAt);
        _go('/onboarding');
        return;
      }

      if (SupabaseConfig.isNotConfigured) {
        _setStatus('Menjalankan mode demo…', 0.65);
        await _waitMinimum(startedAt);
        _go('/siswa');
        return;
      }

      _setStatus('Memulihkan sesi…', 0.55);
      AppUser? user;
      try {
        user = await ref.read(currentUserProvider.future).timeout(_sessionTimeout);
      } on TimeoutException {
        await _waitMinimum(startedAt);
        _fail(const AppError(
          title: 'Koneksi lambat',
          message: 'Server tidak merespons saat memulihkan sesi.',
          hint: 'Periksa internet, lalu coba lagi atau lanjut tanpa login.',
          code: 'timeout',
        ));
        return;
      } catch (e) {
        await _waitMinimum(startedAt);
        _fail(AppError.from(e));
        return;
      }

      _setStatus('Menyiapkan halaman…', 0.9);
      await _waitMinimum(startedAt);
      if (!mounted) return;

      if (user == null) {
        _go('/siswa');
        return;
      }
      if (!user.isActive) {
        _fail(const AppError(
          title: 'Akun nonaktif',
          message: 'Akun ini dinonaktifkan oleh admin.',
          hint: 'Hubungi admin sekolah untuk mengaktifkan kembali.',
          code: 'inactive',
        ));
        return;
      }

      switch (user.role) {
        case UserRole.admin:
          _go('/admin');
          break;
        case UserRole.guru:
          _go('/guru');
          break;
        case UserRole.unknown:
          _fail(const AppError(
            title: 'Peran akun tidak dikenali',
            message: 'Akun ini tidak memiliki peran admin atau guru.',
            hint: 'Hubungi admin untuk melengkapi data akun.',
            code: 'unknown_role',
          ));
          break;
      }
    } catch (e) {
      await _waitMinimum(startedAt);
      _fail(AppError.from(e));
    }
  }

  Future<void> _waitMinimum(DateTime startedAt) async {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minimumDisplay) {
      await Future.delayed(_minimumDisplay - elapsed);
    }
  }

  void _fail(AppError error) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _error = error;
    });
  }

  void _go(String location) {
    if (!mounted || _navigated) return;
    _navigated = true;
    setState(() => _progress = 1);
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Ornamen lembut (tidak mengganggu performa).
              Positioned(
                top: -size.width * 0.25,
                right: -size.width * 0.2,
                child: _orb(size.width * 0.65, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                bottom: -size.width * 0.35,
                left: -size.width * 0.25,
                child: _orb(size.width * 0.8, Colors.white.withValues(alpha: 0.05)),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: FadeTransition(
                    opacity: _fade,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const EduTaskLogo(size: 84, withShadow: false),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          AppInfo.appName,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppInfo.tagline,
                          style: TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        if (!_failed) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              width: 168,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: _progress),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOut,
                                builder: (context, value, _) => LinearProgressIndicator(
                                  value: value,
                                  minHeight: 4,
                                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              _status,
                              key: ValueKey(_status),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ] else
                          _buildError(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.lg,
                child: Column(
                  children: [
                    Text(
                      AppInfo.teamMotto,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${AppInfo.version}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    final error = _error;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: [
              Text(
                error?.title ?? 'Gagal memuat',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                error?.message ?? 'Terjadi kesalahan saat menyiapkan aplikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _bootstrap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
              ),
              child: const Text('Coba lagi'),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton(
              onPressed: () => _go('/siswa'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Lanjut tanpa login'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
