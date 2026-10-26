import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/student/presentation/pages/student_main_page.dart';
import '../../features/student/presentation/pages/student_schedule_page.dart';
import '../../features/student/presentation/pages/student_task_list_page.dart';
import '../../features/student/presentation/pages/student_task_detail_page.dart';
import '../../features/student/presentation/pages/student_about_page.dart';
import '../../features/student/identity/student_identity_page.dart';
import '../../features/admin/presentation/pages/admin_shell.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_students_page.dart';
import '../../features/admin/presentation/pages/admin_teachers_page.dart';
import '../../features/admin/presentation/pages/admin_classes_page.dart';
import '../../features/admin/presentation/pages/admin_subjects_page.dart';
import '../../features/admin/presentation/pages/admin_schedules_page.dart';
import '../../features/admin/presentation/pages/admin_tasks_page.dart';
import '../../features/admin/presentation/pages/admin_reports_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/teacher/presentation/pages/teacher_shell.dart';
import '../../features/teacher/presentation/pages/teacher_dashboard_page.dart';
import '../../features/teacher/presentation/pages/teacher_schedules_page.dart';
import '../../features/teacher/presentation/pages/teacher_tasks_page.dart';
import '../../features/teacher/presentation/pages/teacher_task_form_page.dart';
import '../../features/teacher/presentation/pages/teacher_task_status_page.dart';
import '../../features/teacher/presentation/pages/teacher_profile_page.dart';
import '../widgets/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final loc = state.uri.toString();
      // Don't redirect splash
      if (loc == '/splash') return null;

      // Student routes are public - no auth required
      if (loc.startsWith('/siswa')) return null;
      if (loc == '/login') return null;

      final user = authAsync.valueOrNull;
      final isLoggedIn = user != null;
      final role = user?.role;

      // Auth protected routes
      if (loc.startsWith('/admin')) {
        if (!isLoggedIn) return '/login';
        if (role != UserRole.admin) return '/login';
      }
      if (loc.startsWith('/guru')) {
        if (!isLoggedIn) return '/login';
        if (role != UserRole.guru && role != UserRole.admin) return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (ctx, s) => const SplashPage()),
      GoRoute(path: '/', redirect: (c, s) => '/siswa'),
      GoRoute(path: '/login', builder: (ctx, s) => const LoginPage()),

      // Student (tanpa login)
      GoRoute(path: '/siswa', builder: (ctx, s) => const StudentMainPage()),
      GoRoute(path: '/siswa/jadwal', builder: (ctx, s) => const StudentSchedulePage()),
      GoRoute(path: '/siswa/tugas', builder: (ctx, s) => const StudentTaskListPage()),
      GoRoute(path: '/siswa/tugas/:id', builder: (ctx, s) {
        final id = s.pathParameters['id'];
        if (id == null || id.isEmpty) return Scaffold(body: Center(child: Text('ID tugas tidak valid'))); 
        return StudentTaskDetailPage(taskId: id);
      }),
      GoRoute(path: '/siswa/tentang', builder: (ctx, s) => const StudentAboutPage()),
      GoRoute(path: '/siswa/identitas', builder: (ctx, s) => const StudentIdentityPage()),

      // Admin Shell
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (ctx, s) => const AdminDashboardPage()),
          GoRoute(path: '/admin/siswa', builder: (ctx, s) => const AdminStudentsPage()),
          GoRoute(path: '/admin/guru', builder: (ctx, s) => const AdminTeachersPage()),
          GoRoute(path: '/admin/kelas', builder: (ctx, s) => const AdminClassesPage()),
          GoRoute(path: '/admin/mapel', builder: (ctx, s) => const AdminSubjectsPage()),
          GoRoute(path: '/admin/jadwal', builder: (ctx, s) => const AdminSchedulesPage()),
          GoRoute(path: '/admin/tugas', builder: (ctx, s) => const AdminTasksPage()),
          GoRoute(path: '/admin/laporan', builder: (ctx, s) => const AdminReportsPage()),
          GoRoute(path: '/admin/pengaturan', builder: (ctx, s) => const AdminSettingsPage()),
        ],
      ),

      // Guru Shell
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(path: '/guru', builder: (ctx, s) => const TeacherDashboardPage()),
          GoRoute(path: '/guru/jadwal', builder: (ctx, s) => const TeacherSchedulesPage()),
          GoRoute(path: '/guru/tugas', builder: (ctx, s) => const TeacherTasksPage()),
          GoRoute(path: '/guru/tugas/tambah', builder: (ctx, s) => const TeacherTaskFormPage()),
          GoRoute(path: '/guru/tugas/:id/edit', builder: (ctx, s) => TeacherTaskFormPage(taskId: s.pathParameters['id'])),
          GoRoute(path: '/guru/tugas/:id/status', builder: (ctx, s) {
            final id = s.pathParameters['id'];
            if (id == null || id.isEmpty) return Scaffold(body: Center(child: Text('ID tugas tidak valid')));
            return TeacherTaskStatusPage(taskId: id);
          }),
          GoRoute(path: '/guru/tugas/:id', builder: (ctx, s) {
            final id = s.pathParameters['id'];
            if (id == null || id.isEmpty) return Scaffold(body: Center(child: Text('ID tugas tidak valid')));
            return StudentTaskDetailPage(taskId: id, isTeacherView: true);
          }),
          GoRoute(path: '/guru/profil', builder: (ctx, s) => const TeacherProfilePage()),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Halaman tidak ditemukan: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => ctx.go('/siswa'), child: const Text('Kembali ke Beranda')),
          ],
        ),
      ),
    ),
  );
});
