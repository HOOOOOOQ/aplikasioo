import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_info.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_version.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_preferences_section.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../identity/student_identity_provider.dart';

/// Pengaturan sisi siswa (tanpa login).
///
/// Berisi preferensi perangkat (suara pembuka, tutorial) dan pengelolaan
/// identitas lokal. Tidak ada kontrol administratif di sini.
class StudentSettingsPage extends ConsumerWidget {
  const StudentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(studentIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          const SectionHeader(title: 'Identitas siswa', icon: Icons.badge_outlined),
          AppCard(
            child: identity.isIdentified
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(
                        label: 'Nama',
                        value: identity.siswaNama ?? '-',
                        icon: Icons.person_outline_rounded,
                      ),
                      InfoRow(
                        label: 'Kelas',
                        value: identity.kelasNama ?? '-',
                        icon: Icons.class_outlined,
                      ),
                      InfoRow(
                        label: 'Status',
                        value: 'Terhubung dengan kode akses',
                        icon: Icons.verified_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Lepas identitas di perangkat ini?',
                            content: 'Identitas dapat dihubungkan kembali dengan kode akses baru dari guru. '
                                'Data tugas yang sudah tersimpan di server tidak dihapus.',
                            confirmLabel: 'Lepas',
                            cancelLabel: 'Batal',
                          );
                          if (!confirmed) return;
                          await ref.read(studentIdentityProvider.notifier).clearAll();
                          if (!context.mounted) return;
                          showAppSnackBar(context, 'Identitas dilepas dari perangkat ini.');
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Lepas identitas'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Belum terhubung. Masukkan kode akses dari guru untuk mengaktifkan '
                        'pengumpulan tugas, chat, dan nilai.',
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => context.go('/siswa/identitas'),
                        icon: const Icon(Icons.vpn_key_rounded, size: 18),
                        label: const Text('Hubungkan identitas'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPreferencesSection(aboutRoute: '/siswa/tentang', helpRoute: '/siswa/bantuan'),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                AppVersionLabel(fontSize: 10.5, suffix: AppInfo.packageName),
                const SizedBox(height: 4),
                Text(
                  AppInfo.copyright,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
