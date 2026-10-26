import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'auth_provider.dart';
import '../../auth/domain/app_user.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (SupabaseConfig.isNotConfigured) {
      showAppSnackBar(context, 'Supabase belum dikonfigurasi. Hubungi admin.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(email: _emailC.text.trim(), password: _passC.text);
      final user = await ref.read(authRepositoryProvider).getCurrentProfile();
      if (!mounted) return;
      if (user == null) {
        showAppSnackBar(context, 'Login berhasil tetapi profil tidak ditemukan. Hubungi admin.', isError: true);
        return;
      }
      if (!user.isActive) {
        showAppSnackBar(context, 'Akun Anda nonaktif. Hubungi admin.', isError: true);
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }
      if (user.role == UserRole.admin) {
        context.go('/admin');
      } else if (user.role == UserRole.guru) {
        context.go('/guru');
      } else {
        showAppSnackBar(context, 'Role tidak dikenal: ${user.role.label}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
      String display = 'Login gagal. Periksa email dan password.';
      if (msg.toLowerCase().contains('invalid login')) display = 'Email atau password salah.';
      if (msg.toLowerCase().contains('email not confirmed')) display = 'Email belum dikonfirmasi. Cek inbox Anda.';
      if (msg.toLowerCase().contains('network') || msg.toLowerCase().contains('socket')) display = 'Tidak ada koneksi internet.';
      showAppSnackBar(context, display, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Banner Logo EduTask — utama biar tidak FC, pakai errorBuilder
              Center(child: EduTaskLogo(size: 88)),
              const SizedBox(height: 14),
              const Center(child: Text('EduTask', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary))),
              const Center(child: Text('Aplikasi Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
              const SizedBox(height: 6),
              const Center(
                child: EduTaskBanner(height: 42),
              ),
              const SizedBox(height: 20),
              if (SupabaseConfig.isNotConfigured)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Supabase belum dikonfigurasi. Aplikasi berjalan dalam mode demo terbatas.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              if (SupabaseConfig.isNotConfigured) const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Masuk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Masuk sebagai Admin atau Guru', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailC,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), hintText: 'admin@sekolah.id'),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passC,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: Validators.password,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Masuk'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/siswa'),
                          child: const Text('Masuk sebagai Siswa (Tanpa Login)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Siswa tidak perlu login. Pilih kelas untuk melihat jadwal dan tugas.\nAdmin & Guru harus login dengan akun yang dibuat admin.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
