import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../services/app_preferences.dart';
import '../services/onboarding_service.dart';
import '../services/welcome_sound.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';

/// Bagian pengaturan yang dipakai bersama oleh admin, guru, dan siswa.
///
/// Hanya berisi preferensi yang benar-benar dipakai aplikasi:
/// * `Suara pembuka` — dibaca oleh splash sebelum memutar aset audio.
/// * `Putar ulang tutorial` — mengatur ulang penanda onboarding lalu membuka
///   tutorial (tanpa menyentuh sesi login).
/// * `Tentang EduTask` — halaman identitas aplikasi.
///
/// Tema gelap sengaja belum ditampilkan karena seluruh halaman belum memakai
/// token warna gelap; menampilkannya sekarang akan menjadi kontrol palsu.
class AppPreferencesSection extends ConsumerWidget {
  /// Rute halaman Tentang yang sesuai peran.
  final String aboutRoute;

  const AppPreferencesSection({super.key, required this.aboutRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

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
                  await ref.read(appPreferencesProvider.notifier).setWelcomeSound(value);
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
                  'Diputar sekali saat aplikasi dibuka. Tidak diputar ulang ketika kembali dari halaman lain.',
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
                leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
                title: const Text('Putar ulang tutorial', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  'Melihat kembali 5 langkah pengenalan aplikasi.',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () async {
                  await OnboardingService.reset();
                  if (!context.mounted) return;
                  context.go('/onboarding?replay=1');
                },
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
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Column(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }
}
