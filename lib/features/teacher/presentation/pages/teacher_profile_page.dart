import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_info.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/app_preferences_section.dart';
import '../../../../core/services/app_version.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../auth/domain/app_user.dart';

class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        AppHeroHeader(
          eyebrow: 'Akun guru',
          title: user?.fullName ?? 'Profil',
          subtitle: user?.email ?? '-',
          trailing: InitialsAvatar(name: user?.fullName ?? 'G', size: 46),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: [
              InfoRow(label: 'Peran', value: user?.role.label ?? '-', icon: Icons.badge_outlined),
              InfoRow(label: 'Status akun', value: (user?.isActive ?? false) ? 'Aktif' : 'Nonaktif', icon: Icons.verified_user_outlined),
              InfoRow(
                label: 'Versi aplikasi',
                value: AppInfo.version,
                icon: Icons.info_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPreferencesSection(aboutRoute: '/guru/tentang', helpRoute: '/guru/bantuan'),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Bantuan', icon: Icons.help_outline_rounded),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Tentang EduTask'),
                subtitle: const Text('Tim pengembang dan informasi aplikasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/tentang?from=guru'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Kode akses siswa'),
                subtitle: const Text('Terbitkan atau cabut kode untuk kelas yang Anda ampu'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/guru/kode-akses'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppNotice.info(
          text: 'Ganti kata sandi akun melalui admin sekolah. Aplikasi ini tidak menyimpan '
              'kata sandi di perangkat.',
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Keluar dari akun?',
              content: 'Anda perlu login kembali untuk membuka dashboard guru.',
              confirmLabel: 'Keluar',
            );
            if (!confirmed) return;
            await ref.read(authControllerProvider.notifier).signOut();
            ref.invalidate(currentUserProvider);
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
          label: const Text('Keluar', style: TextStyle(color: AppColors.error)),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Column(
            children: [
              AppVersionLabel(fontSize: 10.5, suffix: AppInfo.appName),
              const SizedBox(height: 2),
              Text(
                AppInfo.copyright,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
