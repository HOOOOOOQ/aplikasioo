import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/auth_provider.dart';

class TeacherShell extends ConsumerWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final loc = GoRouterState.of(context).uri.toString();

    final items = [
      _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', '/guru'),
      _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Jadwal Mengajar', '/guru/jadwal'),
      _NavItem(Icons.assignment_outlined, Icons.assignment, 'Daftar Tugas', '/guru/tugas'),
      _NavItem(Icons.add_task, Icons.add_task, 'Tambah Tugas', '/guru/tugas/tambah'),
      _NavItem(Icons.person_outline, Icons.person, 'Profil', '/guru/profil'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduTask Guru'),
        backgroundColor: AppColors.primary,
        actions: [
          if (user != null) Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 12)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async { await ref.read(authControllerProvider.notifier).signOut(); if (context.mounted) context.go('/login'); }),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.school, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                const Text('EduTask Guru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(user?.email ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Expanded(
              child: ListView(
                children: items.map((e) {
                  final sel = loc == e.route;
                  return ListTile(
                    leading: Icon(sel ? e.selected : e.icon, color: sel ? AppColors.primary : AppColors.textSecondary),
                    title: Text(e.label, style: TextStyle(color: sel ? AppColors.primary : AppColors.textPrimary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                    selected: sel,
                    selectedTileColor: AppColors.primaryContainer,
                    onTap: () { Navigator.pop(context); context.go(e.route); },
                  );
                }).toList(),
              ),
            ),
            ListTile(leading: const Icon(Icons.logout, color: AppColors.error), title: const Text('Logout', style: TextStyle(color: AppColors.error)), onTap: () async { await ref.read(authControllerProvider.notifier).signOut(); if (context.mounted) context.go('/login'); }),
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
