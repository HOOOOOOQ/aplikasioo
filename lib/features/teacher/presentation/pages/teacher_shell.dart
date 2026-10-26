import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_info.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/auth_provider.dart';

class TeacherShell extends ConsumerWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  static const List<({String label, String route, IconData icon})> _sections = [
    (label: 'Jadwal', route: '/guru/jadwal', icon: Icons.calendar_month_rounded),
    (label: 'Tugas', route: '/guru/tugas', icon: Icons.assignment_rounded),
    (label: 'Kode Akses', route: '/guru/kode-akses', icon: Icons.key_rounded),
    (label: 'Profil', route: '/guru/profil', icon: Icons.person_rounded),
  ];

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final user = ref.watch(currentUserProvider).valueOrNull;

    final routes = ['/guru', '/guru/jadwal', '/guru/tugas', '/guru/kode-akses', '/guru/profil'];
    var index = routes.indexOf(path);
    if (index < 0) index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const EduTaskLogo(size: 30, withShadow: false),
            const SizedBox(width: AppSpacing.sm),
            const Text('EduTask'),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'GURU',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primaryDark, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tentang aplikasi',
            onPressed: () => context.push('/tentang?from=guru'),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout(context, ref);
              if (value == 'about') context.push('/tentang?from=guru');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('Tentang EduTask')),
              PopupMenuItem(
                value: 'logout',
                child: Text('Keluar', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => context.go(routes[value]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key_rounded), label: 'Kode'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Dipakai halaman guru untuk tombol cepat.
const teacherSections = TeacherShell._sections;

/// Footer kecil yang konsisten.
class TeacherFooter extends StatelessWidget {
  const TeacherFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Center(
        child: Text(
          '${AppInfo.appName} v${AppInfo.version} • ${AppInfo.copyright}',
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
