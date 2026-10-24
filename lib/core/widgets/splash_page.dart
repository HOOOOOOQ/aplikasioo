import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.school_rounded, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text('EduTask', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 40),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
