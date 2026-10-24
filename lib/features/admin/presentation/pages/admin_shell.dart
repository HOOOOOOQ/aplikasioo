import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    final items = [
      _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', '/admin'),
      _NavItem(Icons.people_outline, Icons.people, 'Data Siswa', '/admin/siswa'),
      _NavItem(Icons.badge_outlined, Icons.badge, 'Data Guru', '/admin/guru'),
      _NavItem(Icons.class_outlined, Icons.class_, 'Data Kelas', '/admin/kelas'),
      _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Mata Pelajaran', '/admin/mapel'),
      _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Jadwal', '/admin/jadwal'),
      _NavItem(Icons.assignment_outlined, Icons.assignment, 'Tugas', '/admin/tugas'),
      _NavItem(Icons.analytics_outlined, Icons.analytics, 'Laporan', '/admin/laporan'),
      _NavItem(Icons.settings_outlined, Icons.settings, 'Pengaturan', '/admin/pengaturan'),
    ];

    String currentPath = GoRouterState.of(context).uri.toString();

    return Scaffold(
      appBar: AppBar(
        title: const EduTaskHeaderBanner(isAppBar: true),
        backgroundColor: AppColors.primary,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 12))),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: AppColors.headerGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset('assets/images/edutask_logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.school, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EduTask', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Tugas & Jadwal', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(user?.email ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(user?.role.label ?? 'Admin', style: const TextStyle(color: Colors.white, fontSize: 11))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: items.map((e) {
                  final sel = currentPath == e.route;
                  return ListTile(
                    leading: Icon(sel ? e.selected : e.icon, color: sel ? AppColors.primary : AppColors.textSecondary),
                    title: Text(e.label, style: TextStyle(color: sel ? AppColors.primary : AppColors.textPrimary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                    selected: sel,
                    selectedTileColor: AppColors.primaryContainer,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(e.route);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: child,
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selected;
  final String label;
  final String route;
  _NavItem(this.icon, this.selected, this.label, this.route);
}
