import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/repositories/akun_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_provider.dart';

class AdminTeachersPage extends ConsumerStatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  ConsumerState<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends ConsumerState<AdminTeachersPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<ProfileRow>> _future;
  String _search = '';
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(akunRepositoryProvider).fetchProfiles(role: 'guru');
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = ref.read(akunRepositoryProvider).fetchProfiles(role: 'guru'));
    await _future;
  }

  Future<void> _invite() async {
    final formKey = GlobalKey<FormState>();
    final namaC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    var obscure = true;

    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Undang guru'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: namaC,
                      decoration: const InputDecoration(labelText: 'Nama lengkap'),
                      validator: (v) => Validators.nama(v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: emailC,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: passC,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi awal',
                        helperText: 'Minimal 6 karakter. Minta guru menggantinya setelah login.',
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppNotice.info(
                      text: 'Akun dibuat oleh Edge Function create-teacher dengan service role di server. '
                          'Password tidak disimpan di aplikasi.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, {
                  'nama': namaC.text.trim(),
                  'email': emailC.text.trim(),
                  'password': passC.text,
                });
              },
              child: const Text('Buat akun'),
            ),
          ],
        ),
      ),
    );

    namaC.dispose();
    emailC.dispose();
    passC.dispose();
    if (payload == null) return;

    setState(() => _inviting = true);
    try {
      await ref.read(authRepositoryProvider).createTeacherAccount(
            email: payload['email']!,
            password: payload['password']!,
            fullName: payload['nama']!,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Akun guru berhasil dibuat.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      final error = AppError.from(e);
      if (e is TeacherInviteException && e.requiresRelogin) {
        final relogin = await showConfirmDialog(
          context,
          title: 'Sesi berakhir',
          content: 'Sesi admin sudah tidak berlaku. Login ulang untuk melanjutkan?',
          confirmLabel: 'Login ulang',
          isDestructive: false,
        );
        if (relogin && mounted) {
          await ref.read(authControllerProvider.notifier).signOut();
          if (mounted) context.go('/login');
        }
        return;
      }
      showAppSnackBar(context, error.shortMessage, isError: true);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _toggleActive(ProfileRow guru) async {
    try {
      await ref.read(akunRepositoryProvider).setActive(guru.id, !guru.isActive);
      if (!mounted) return;
      showAppSnackBar(context, guru.isActive ? 'Akun guru dinonaktifkan.' : 'Akun guru diaktifkan.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviting ? null : _invite,
        icon: _inviting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_inviting ? 'Memproses…' : 'Undang guru'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ProfileRow>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <ProfileRow>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list
                  .where((g) =>
                      g.fullName.toLowerCase().contains(needle) ||
                      g.email.toLowerCase().contains(needle))
                  .toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Akun guru',
                  title: 'Data Guru',
                  subtitle: 'Guru dapat membuat tugas dan mengelola kelas yang diampu.',
                  footer: Text(
                    '${list.where((g) => g.isActive).length} aktif dari ${snapshot.data?.length ?? 0} akun guru',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari nama atau email guru…',
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.badge_outlined,
                      title: 'Belum ada akun guru',
                      subtitle: 'Undang guru dengan email agar bisa masuk dan mengelola tugas.',
                      actionLabel: 'Undang guru',
                      onAction: _invite,
                    ),
                  )
                else
                  ...list.map((guru) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              InitialsAvatar(name: guru.fullName, size: 42),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            guru.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        _badge(
                                          guru.isActive ? 'Aktif' : 'Nonaktif',
                                          guru.isActive ? AppColors.success : AppColors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        _badge(guru.roleLabel, AppColors.primary),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      guru.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: guru.isActive,
                                onChanged: (_) => _toggleActive(guru),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: AppSpacing.lg),
                const AppNotice.info(
                  text: 'Akun guru dibuat melalui Edge Function create-teacher. Jika function belum '
                      'dideploy, pembuatan akun akan gagal dengan pesan yang jelas — bukan diam-diam.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
