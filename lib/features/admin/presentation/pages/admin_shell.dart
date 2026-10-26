import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_info.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/auth_provider.dart';

class AdminNavItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  const AdminNavItem(this.label, this.route, this.icon, this.selectedIcon);
}

const List<AdminNavItem> adminNavItems = [
  AdminNavItem('Dashboard', '/admin', Icons.dashboard_outlined, Icons.dashboard_rounded),
  AdminNavItem('Data Guru', '/admin/guru', Icons.badge_outlined, Icons.badge_rounded),
  AdminNavItem('Data Siswa', '/admin/siswa', Icons.people_outline_rounded, Icons.people_rounded),
  AdminNavItem('Kelas', '/admin/kelas', Icons.class_outlined, Icons.class_rounded),
  AdminNavItem('Mata Pelajaran', '/admin/mapel', Icons.menu_book_outlined, Icons.menu_book_rounded),
  AdminNavItem('Jadwal', '/admin/jadwal', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  AdminNavItem('Tugas', '/admin/tugas', Icons.assignment_outlined, Icons.assignment_rounded),
  AdminNavItem('Kode Akses', '/admin/kode-akses', Icons.key_outlined, Icons.key_rounded),
  AdminNavItem('Laporan', '/admin/laporan', Icons.insights_outlined, Icons.insights_rounded),
  AdminNavItem('Pengumuman', '/admin/pengumuman', Icons.campaign_outlined, Icons.campaign_rounded),
  AdminNavItem('Kalender', '/admin/kalender', Icons.event_outlined, Icons.event_rounded),
  AdminNavItem('Chat', '/admin/chat', Icons.forum_outlined, Icons.forum_rounded),
  AdminNavItem('Notifikasi', '/admin/notifikasi', Icons.notifications_outlined, Icons.notifications_rounded),
  AdminNavItem('Akun & Role', '/admin/akun', Icons.manage_accounts_outlined, Icons.manage_accounts_rounded),
  AdminNavItem('Audit Log', '/admin/audit', Icons.history_rounded, Icons.history_rounded),
  AdminNavItem('Pengaturan', '/admin/pengaturan', Icons.settings_outlined, Icons.settings_rounded),
];

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  AdminNavItem _current(String path) {
    AdminNavItem? match;
    for (final item in adminNavItems) {
      if (path == item.route) return item;
      if (path.startsWith('${item.route}/')) match = item;
    }
    return match ?? adminNavItems.first;
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Keluar dari akun?',
      content: 'Anda perlu login kembali untuk membuka dashboard admin.',
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
    final current = _current(path);
    final user = ref.watch(currentUserProvider).valueOrNull;

    final bottomRoutes = ['/admin', '/admin/siswa', '/admin/tugas', '/admin/laporan'];
    var bottomIndex = bottomRoutes.indexOf(current.route);
    if (bottomIndex < 0) bottomIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
          IconButton(
            tooltip: 'Pencarian global',
            onPressed: () => context.go('/admin/pencarian'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Tentang aplikasi',
            onPressed: () => context.push('/tentang?from=admin'),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EduTaskLogo(size: 46, withShadow: false),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      user?.fullName ?? 'Administrator',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Admin sekolah',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ADMINISTRATOR',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    for (final item in adminNavItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          selected: item.route == current.route,
                          selectedTileColor: AppColors.primaryContainer,
                          selectedColor: AppColors.primary,
                          leading: Icon(item.route == current.route ? item.selectedIcon : item.icon, size: 20),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: item.route == current.route ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(item.route);
                          },
                        ),
                      ),
                    const Divider(),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline_rounded, size: 20),
                      title: const Text('Tentang EduTask', style: TextStyle(fontSize: 13)),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/tentang?from=admin');
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.logout_rounded, size: 20, color: AppColors.error),
                      title: const Text(
                        'Keluar',
                        style: TextStyle(fontSize: 13, color: AppColors.error),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _logout(context, ref);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        '${AppInfo.appName} v${AppInfo.version} • ${AppInfo.copyright}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        onDestinationSelected: (index) {
          context.go(bottomRoutes[index]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Siswa'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Laporan'),
        ],
      ),
    );
  }
}
