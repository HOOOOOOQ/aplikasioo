import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/services/app_version.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/domain/app_user.dart';
import 'auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  AppError? _error;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (SupabaseConfig.isNotConfigured) {
      showAppSnackBar(context, 'Aplikasi belum terhubung ke server.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _emailC.text.trim(),
            password: _passC.text,
          );
      final user = await ref.read(authRepositoryProvider).getCurrentProfile();
      if (!mounted) return;

      if (user == null) {
        setState(() => _error = const AppError(
              title: 'Profil belum tersedia',
              message: 'Login berhasil, tetapi data profil akun tidak ditemukan.',
              hint: 'Hubungi admin sekolah untuk melengkapi profil Anda.',
              code: 'profile_missing',
            ));
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }

      if (!user.isActive) {
        setState(() => _error = const AppError(
              title: 'Akun nonaktif',
              message: 'Akun ini dinonaktifkan oleh admin.',
              hint: 'Hubungi admin sekolah untuk mengaktifkan kembali.',
              code: 'inactive',
            ));
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }

      if (user.role == UserRole.unknown) {
        setState(() => _error = const AppError(
              title: 'Peran tidak dikenali',
              message: 'Akun ini tidak memiliki peran admin atau guru.',
              hint: 'Hubungi admin sekolah untuk memperbaiki data akun.',
              code: 'unknown_role',
            ));
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }

      // Segarkan status global lalu tunggu agar router tidak melempar balik.
      ref.invalidate(currentUserProvider);
      try {
        await ref.read(currentUserProvider.future);
      } catch (_) {
        // biarkan halaman tujuan menampilkan pesan errornya sendiri
      }
      if (!mounted) return;

      context.go(user.role == UserRole.admin ? '/admin' : '/guru');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppError.from(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Hero(
                      tag: 'edutask-logo',
                      child: const EduTaskLogo(size: 86),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Center(
                    child: Text(
                      AppInfo.appName,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      AppInfo.tagline,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (SupabaseConfig.isNotConfigured) ...[
                    const AppNotice.warning(
                      title: 'Mode terbatas',
                      text: 'Build ini belum memiliki konfigurasi server. Login dinonaktifkan, '
                          'tetapi halaman siswa tetap dapat dibuka.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Masuk',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gunakan akun yang diberikan admin sekolah.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextFormField(
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enabled: !_loading,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'nama@email.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                            ),
                            validator: Validators.email,
                            onFieldSubmitted: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _passC,
                            focusNode: _passFocus,
                            obscureText: _obscure,
                            enabled: !_loading,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi',
                              hintText: 'Masukkan kata sandi',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: Validators.password,
                            onFieldSubmitted: (_) => _loading ? null : _login(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            AppNotice.error(
                              title: _error!.title,
                              text: _error!.hint == null
                                  ? _error!.message
                                  : '${_error!.message} ${_error!.hint}',
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading || SupabaseConfig.isNotConfigured ? null : _login,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Masuk'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => context.push('/onboarding'),
                            icon: const Icon(Icons.auto_stories_outlined, size: 17),
                            label: const Text('Lihat tutorial aplikasi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/siswa'),
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('Lanjut sebagai siswa'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Siswa tidak perlu login. Status tugas resmi memerlukan kode akses dari '
                    'admin atau guru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/bantuan?from=siswa'),
                          child: const Text('Bantuan'),
                        ),
                        const Text(
                          '•',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        TextButton(
                          onPressed: () => context.push('/tentang'),
                          child: const Text('Tentang EduTask'),
                        ),
                        const Text(
                          '•',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        const AppVersionLabel(fontSize: 11),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Center(
                    child: Text(
                      AppInfo.copyright,
                      style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
