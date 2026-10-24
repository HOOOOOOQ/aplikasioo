import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';
import 'app_banner.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/domain/app_user.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Jika supabase belum konfigurasi, langsung ke siswa
    if (SupabaseConfig.isNotConfigured) {
      context.go('/siswa');
      return;
    }

    try {
      final user = await ref.read(currentUserProvider.future);
      if (!mounted) return;
      if (user == null) {
        context.go('/siswa');
        return;
      }
      if (user.role == UserRole.admin) {
        context.go('/admin');
      } else if (user.role == UserRole.guru) {
        context.go('/guru');
      } else {
        context.go('/siswa');
      }
    } catch (_) {
      if (mounted) context.go('/siswa');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Banner logo utama — anti FC dengan errorBuilder
              const EduTaskLogo(size: 110),
              const SizedBox(height: 20),
              const Text('EduTask', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                child: const Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('com.edutask.sekolah • v1.0.0', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              const Text('Memuat...', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
