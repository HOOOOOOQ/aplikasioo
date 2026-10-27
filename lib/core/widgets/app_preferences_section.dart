import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../services/app_preferences.dart';
import '../services/onboarding_service.dart';
import '../services/platform_capabilities.dart';
import '../services/welcome_sound.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../../features/notifications/notification_service.dart';

/// Bagian pengaturan yang dipakai bersama admin, guru, dan siswa.
///
/// Semua kontrol di sini benar-benar dipakai aplikasi:
/// * `Suara pembuka` → dibaca splash sebelum memutar aset audio.
/// * `Pengingat tenggat` → dipakai saat menjadwalkan notifikasi lokal.
/// * `Notifikasi chat` → mengatur notifikasi in-app untuk pesan baru.
/// * `Ukuran teks` → langsung mengubah skala teks seluruh aplikasi.
/// * `Putar ulang tutorial` → membuka onboarding tanpa menyentuh sesi.
class AppPreferencesSection extends ConsumerWidget {
  /// Rute halaman Tentang yang sesuai peran.
  final String aboutRoute;

  /// Rute halaman Bantuan & FAQ.
  final String helpRoute;

  const AppPreferencesSection({
    super.key,
    required this.aboutRoute,
    this.helpRoute = '/bantuan',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tampilan & suara', icon: Icons.tune_rounded),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                value: prefs.welcomeSound,
                onChanged: (value) async {
                  await notifier.setWelcomeSound(value);
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    value
                        ? 'Suara pembuka aktif. Diputar sekali setiap aplikasi dibuka.'
                        : 'Suara pembuka dimatikan.',
                  );
                },
                title: const Text('Suara pembuka', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Diputar sekali saat aplikasi dibuka, tidak saat berpindah halaman.',
                  style: TextStyle(fontSize: 11.5),
                ),
                secondary: Icon(
                  prefs.welcomeSound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: AppColors.primary,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                leading: const Icon(Icons.format_size_rounded, color: AppColors.primary),
                title: const Text('Ukuran teks', style: TextStyle(fontSize: 13.5)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skala ${(prefs.textScale * 100).round()}%',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    Slider(
                      value: prefs.textScale,
                      min: AppPreferences.minTextScale,
                      max: AppPreferences.maxTextScale,
                      divisions: 5,
                      label: '${(prefs.textScale * 100).round()}%',
                      onChanged: (value) => notifier.setTextScale(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Notifikasi', icon: Icons.notifications_outlined),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                value: prefs.deadlineReminders,
                onChanged: !NotificationService.isSupported
                    ? null
                    : (value) async {
                        await notifier.setDeadlineReminders(value);
                        if (!value) {
                          await NotificationService.cancelAll();
                        }
                        if (!context.mounted) return;
                        showAppSnackBar(
                          context,
                          value
                              ? 'Pengingat tenggat aktif untuk tugas yang belum selesai.'
                              : 'Pengingat tenggat dimatikan.',
                        );
                      },
                title: const Text('Pengingat tenggat', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  NotificationService.isSupported
                      ? '24 jam dan 1 jam sebelum tenggat tugas.'
                      : 'Hanya tersedia di aplikasi Android (${PlatformCapabilities.label} memakai pusat notifikasi).',
                  style: const TextStyle(fontSize: 11.5),
                ),
                secondary: const Icon(Icons.alarm_rounded, color: AppColors.primary),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                value: prefs.chatNotifications,
                onChanged: (value) => notifier.setChatNotifications(value),
                title: const Text('Notifikasi chat', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Menampilkan pemberitahuan saat ada pesan baru di percakapan.',
                  style: TextStyle(fontSize: 11.5),
                ),
                secondary: const Icon(Icons.forum_outlined, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Bantuan & informasi', icon: Icons.help_outline_rounded),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
                title: const Text('Putar ulang tutorial', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  'Melihat kembali langkah pengenalan aplikasi.',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () async {
                  await OnboardingService.reset();
                  if (!context.mounted) return;
                  // Kembali ke halaman asal setelah tutorial selesai.
                  final back = aboutRoute.startsWith('/admin')
                      ? '/admin'
                      : aboutRoute.startsWith('/guru')
                          ? '/guru'
                          : '/siswa';
                  context.go('/onboarding?replay=1&from=$back');
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                leading: const Icon(Icons.quiz_outlined, color: AppColors.primary),
                title: const Text('Bantuan & FAQ', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  'Panduan singkat untuk admin, guru, dan siswa.',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => context.push(helpRoute),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                title: const Text('Tentang EduTask', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  'Informasi aplikasi, tim pengembang, dan sekolah.',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () => context.push(aboutRoute),
              ),
              if (!WelcomeSoundService.playedThisLaunch)
                const Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: Text(
                    'Suara pembuka hanya diputar saat aplikasi dibuka, bukan dari halaman ini.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
