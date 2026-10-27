import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_version.dart';
import '../../../core/services/platform_capabilities.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/app_user.dart';
import 'auth_provider.dart';

/// Informasi sesi perangkat saat ini.
///
/// Menampilkan data yang memang tersedia di klien: email akun, peran, waktu
/// masuk terakhir, masa berlaku token, dan platform. Tidak ada token atau
/// password yang ditampilkan. "Keluar dari semua perangkat" memakai
/// `signOut(scope: global)` milik GoTrue sehingga refresh token di perangkat
/// lain ikut dicabut server.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key});

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  bool _busy = false;

  String _formatDate(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Tidak tersedia';
    return DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(parsed.toLocal());
  }

  Future<void> _signOutEverywhere() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Keluar dari semua perangkat?',
      content: 'Sesi di semua perangkat akan dicabut. Anda perlu masuk kembali di perangkat ini.',
      confirmLabel: 'Keluar semua',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseService.tryAuth?.signOut(scope: SignOutScope.global);
      ref.invalidate(currentUserProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sesi di semua perangkat telah dicabut.')),
      );
      router.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mencabut sesi: ${e is AuthException ? e.message : 'periksa koneksi.'}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final session = SupabaseService.currentSession;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sesi Perangkat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          const SectionHeader(title: 'Akun aktif', icon: Icons.account_circle_outlined),
          AppCard(
            child: Column(
              children: [
                InfoRow(label: 'Nama', value: user?.fullName ?? '-', icon: Icons.person_outline_rounded),
                InfoRow(label: 'Peran', value: user?.role.label ?? '-', icon: Icons.badge_outlined),
                InfoRow(
                  label: 'Status akun',
                  value: (user?.isActive ?? false) ? 'Aktif' : 'Nonaktif',
                  icon: Icons.verified_user_outlined,
                ),
                InfoRow(
                  label: 'Masuk terakhir',
                  value: _formatDate(session?.user.lastSignInAt),
                  icon: Icons.login_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Token & perangkat', icon: Icons.devices_rounded),
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Masa berlaku token',
                  value: _formatDate(session?.expiresAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch((session!.expiresAt ?? 0) * 1000).toIso8601String()),
                  icon: Icons.timer_outlined,
                ),
                InfoRow(
                  label: 'Platform',
                  value: PlatformCapabilities.label,
                  icon: Icons.phone_android_rounded,
                ),
                InfoRow(
                  label: 'Penyimpanan sesi',
                  value: PlatformCapabilities.isWeb
                      ? 'localStorage browser (dikelola Supabase)'
                      : 'Penyimpanan aman aplikasi',
                  icon: Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppNotice.info(
            title: 'Keamanan sesi',
            text: 'Token tidak pernah ditampilkan atau disimpan di luar penyimpanan resmi '
                'Supabase. Gangguan jaringan tidak membuat sesi dianggap berakhir; server hanya '
                'meminta masuk kembali bila refresh token benar-benar ditolak.',
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signOutEverywhere,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded, size: 18),
            label: Text(_busy ? 'Memproses…' : 'Keluar dari semua perangkat'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(child: AppVersionLabel(fontSize: 10.5, suffix: PlatformCapabilities.label)),
        ],
      ),
    );
  }
}
