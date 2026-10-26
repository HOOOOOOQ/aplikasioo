import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_info.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/onboarding_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../notifications/notification_service.dart';
import '../../../student/identity/student_identity_provider.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        AppHeroHeader(
          compact: true,
          eyebrow: 'Pengaturan',
          title: user?.fullName ?? 'Administrator',
          subtitle: user?.email ?? 'Admin sekolah',
          trailing: IconButton(
            tooltip: 'Tentang',
            onPressed: () => context.push('/tentang?from=admin'),
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Akun & sesi', icon: Icons.manage_accounts_rounded),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Peran akun'),
                subtitle: Text(user == null ? '-' : user.role.label),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.manage_search_rounded),
                title: const Text('Manajemen akun & role'),
                subtitle: const Text('Aktifkan/nonaktifkan akun, ubah peran guru ↔ admin'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/admin/akun'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Keluar', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Keluar dari akun?',
                    content: 'Anda perlu login kembali untuk membuka dashboard.',
                    confirmLabel: 'Keluar',
                  );
                  if (!confirmed) return;
                  await ref.read(authControllerProvider.notifier).signOut();
                  ref.invalidate(currentUserProvider);
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Bantuan & panduan', icon: Icons.menu_book_rounded),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('Putar ulang tutorial'),
                subtitle: const Text('Menampilkan kembali 5 langkah pengenalan aplikasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await OnboardingService.reset();
                  if (!context.mounted) return;
                  context.push('/onboarding');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Tentang EduTask'),
                subtitle: const Text('Tim pengembang, sekolah, dan informasi aplikasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/tentang?from=admin'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Notifikasi', icon: Icons.notifications_outlined),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengingat tenggat tugas dijadwalkan di perangkat siswa. Izin notifikasi '
                'diminta saat fitur dipakai, bukan saat aplikasi dibuka.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  await NotificationService.requestPermission();
                  if (!context.mounted) return;
                  showAppSnackBar(context, 'Permintaan izin notifikasi dikirim.');
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 17),
                label: const Text('Minta izin notifikasi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Data lokal', icon: Icons.storage_rounded),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status tugas lokal dan identitas siswa yang tersimpan di perangkat ini tidak '
                'memengaruhi data server.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Hapus data lokal?',
                          content: 'Status tugas lokal dan identitas siswa di perangkat ini akan dihapus. '
                              'Data di server tidak berubah.',
                          confirmLabel: 'Hapus',
                        );
                        if (!confirmed) return;
                        final sp = await SharedPreferences.getInstance();
                        await sp.remove(AppConstants.spSelectedKelasId);
                        await sp.remove(AppConstants.spStudentIdKey);
                        await sp.remove(AppConstants.spStudentTokenKey);
                        await sp.remove(AppConstants.spStudentNameKey);
                        await sp.remove(AppConstants.spStudentKelasNamaKey);
                        await sp.remove(AppConstants.spStudentVerifiedAtKey);
                        await ref.read(localTaskStatusProvider.notifier).clearAll();
                        ref.invalidate(studentIdentityProvider);
                        if (!context.mounted) return;
                        showAppSnackBar(context, 'Data lokal dibersihkan.');
                      },
                      icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                      label: const Text('Bersihkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Status server', icon: Icons.cloud_outlined),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    SupabaseConfig.isConfigured ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 18,
                    color: SupabaseConfig.isConfigured ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    SupabaseConfig.isConfigured ? 'Terhubung ke Supabase' : 'Belum dikonfigurasi',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (SupabaseConfig.isConfigured)
                Text(
                  Uri.tryParse(SupabaseConfig.supabaseUrl)?.host ?? SupabaseConfig.supabaseUrl,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Anon key bersifat publik dan dilindungi RLS. Service role key tidak pernah '
                'disertakan di aplikasi.',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Column(
            children: [
              const Text(
                '${AppInfo.appName} v${AppInfo.version}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              const Text(AppInfo.copyright, style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
              const SizedBox(height: 2),
              Text(
                AppInfo.teamMotto,
                style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
