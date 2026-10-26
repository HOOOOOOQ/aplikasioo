import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_page.dart';
import '../../features/admin/presentation/pages/admin_accounts_page.dart';
import '../../features/admin/presentation/pages/admin_audit_page.dart';
import '../../features/admin/presentation/pages/admin_classes_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_reports_page.dart';
import '../../features/admin/presentation/pages/admin_schedules_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/admin/presentation/pages/admin_shell.dart';
import '../../features/admin/presentation/pages/admin_students_page.dart';
import '../../features/admin/presentation/pages/admin_subjects_page.dart';
import '../../features/admin/presentation/pages/admin_tasks_page.dart';
import '../../features/admin/presentation/pages/admin_teachers_page.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/access_codes/presentation/access_codes_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/student/identity/student_identity_page.dart';
import '../../features/student/presentation/pages/student_main_page.dart';
import '../../features/student/presentation/pages/student_schedule_page.dart';
import '../../features/student/presentation/pages/student_task_detail_page.dart';
import '../../features/student/presentation/pages/student_task_list_page.dart';
import '../../features/teacher/presentation/pages/teacher_dashboard_page.dart';
import '../../features/teacher/presentation/pages/teacher_profile_page.dart';
import '../../features/teacher/presentation/pages/teacher_schedules_page.dart';
import '../../features/teacher/presentation/pages/teacher_shell.dart';
import '../../features/teacher/presentation/pages/teacher_task_form_page.dart';
import '../../features/teacher/presentation/pages/teacher_task_status_page.dart';
import '../../features/teacher/presentation/pages/teacher_tasks_page.dart';
import '../widgets/error_page.dart';
import '../widgets/splash_page.dart';

/// Memberi tahu GoRouter saat status autentikasi berubah tanpa membuat ulang
/// instance router (membuat ulang router akan mereset posisi navigasi).
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

String _homeFor(AppUser? user) {
  if (user == null || !user.isActive) return '/login';
  return user.role == UserRole.admin ? '/admin' : '/guru';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen<AsyncValue<AppUser?>>(
    currentUserProvider,
    (previous, next) => refresh.ping(),
  );

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = ref.read(currentUserProvider);
      final user = auth.valueOrNull;

      // Rute publik.
      if (path == '/splash' || path == '/onboarding') return null;
      if (path == '/login' || path == '/tentang') return null;
      if (path.startsWith('/siswa')) return null;

      // Jangan pernah menampilkan dashboard sebelum profil & role terverifikasi.
      final isProtected = path.startsWith('/admin') || path.startsWith('/guru');
      if (!isProtected) return null;

      if (auth.isLoading && user == null) return '/splash';
      if (user == null) return '/login';
      if (!user.isActive) return '/login';

      if (path.startsWith('/admin') && user.role != UserRole.admin) {
        return user.role == UserRole.guru ? '/guru' : '/login';
      }
      if (path.startsWith('/guru') &&
          user.role != UserRole.guru &&
          user.role != UserRole.admin) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (ctx, s) => const SplashPage()),
      GoRoute(path: '/', redirect: (c, s) => '/splash'),
      GoRoute(path: '/onboarding', builder: (ctx, s) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (ctx, s) => const LoginPage()),
      GoRoute(
        path: '/tentang',
        builder: (ctx, s) {
          final from = s.uri.queryParameters['from'];
          final fallback = switch (from) {
            'admin' => '/admin',
            'guru' => '/guru',
            _ => '/siswa',
          };
          return AboutPage(fallbackRoute: fallback);
        },
      ),

      // ---------- Siswa (tanpa login, sesuai desain awal aplikasi) ----------
      GoRoute(path: '/siswa', builder: (ctx, s) => const StudentMainPage()),
      GoRoute(path: '/siswa/jadwal', builder: (ctx, s) => const StudentSchedulePage()),
      GoRoute(path: '/siswa/tugas', builder: (ctx, s) => const StudentTaskListPage()),
      GoRoute(
        path: '/siswa/tugas/:id',
        builder: (ctx, s) {
          final id = s.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const AppRouteErrorPage(
              title: 'Tugas tidak ditemukan',
              message: 'Tautan yang Anda buka tidak memuat ID tugas.',
              fallbackRoute: '/siswa/tugas',
            );
          }
          return StudentTaskDetailPage(taskId: id);
        },
      ),
      GoRoute(path: '/siswa/tentang', builder: (ctx, s) => const AboutPage(fallbackRoute: '/siswa')),
      GoRoute(path: '/siswa/identitas', builder: (ctx, s) => const StudentIdentityPage()),

      // ---------- Admin ----------
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
          GoRoute(
            path: '/admin/tugas/:id/status',
            builder: (ctx, s) => TeacherTaskStatusPage(taskId: s.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/admin/tugas/:id/edit',
            builder: (ctx, s) => TeacherTaskFormPage(
              taskId: s.pathParameters['id'],
              adminMode: true,
            ),
          ),
          GoRoute(
            path: '/admin/tugas/:id',
            builder: (ctx, s) => StudentTaskDetailPage(
              taskId: s.pathParameters['id'] ?? '',
              isTeacherView: true,
              adminMode: true,
            ),
          ),
          GoRoute(path: '/admin/laporan', builder: (ctx, s) => const AdminReportsPage()),
          GoRoute(path: '/admin/kode-akses', builder: (ctx, s) => const AccessCodesPage()),
          GoRoute(path: '/admin/akun', builder: (ctx, s) => const AdminAccountsPage()),
          GoRoute(path: '/admin/audit', builder: (ctx, s) => const AdminAuditPage()),
          GoRoute(path: '/admin/pengaturan', builder: (ctx, s) => const AdminSettingsPage()),
          GoRoute(
            path: '/admin/tentang',
            builder: (ctx, s) => const AboutPage(fallbackRoute: '/admin'),
          ),
        ],
      ),

      // ---------- Guru ----------
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(path: '/guru', builder: (ctx, s) => const TeacherDashboardPage()),
          GoRoute(path: '/guru/jadwal', builder: (ctx, s) => const TeacherSchedulesPage()),
          GoRoute(path: '/guru/tugas', builder: (ctx, s) => const TeacherTasksPage()),
          GoRoute(path: '/guru/tugas/tambah', builder: (ctx, s) => const TeacherTaskFormPage()),
          GoRoute(
            path: '/guru/tugas/:id/edit',
            builder: (ctx, s) => TeacherTaskFormPage(taskId: s.pathParameters['id']),
          ),
          GoRoute(
            path: '/guru/tugas/:id/status',
            builder: (ctx, s) => TeacherTaskStatusPage(taskId: s.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/guru/tugas/:id',
            builder: (ctx, s) => StudentTaskDetailPage(
              taskId: s.pathParameters['id'] ?? '',
              isTeacherView: true,
            ),
          ),
          GoRoute(path: '/guru/kode-akses', builder: (ctx, s) => const AccessCodesPage(isTeacher: true)),
          GoRoute(path: '/guru/profil', builder: (ctx, s) => const TeacherProfilePage()),
          GoRoute(
            path: '/guru/tentang',
            builder: (ctx, s) => const AboutPage(fallbackRoute: '/guru'),
          ),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => AppRouteErrorPage(
      title: 'Halaman tidak ditemukan',
      message: 'Rute "${state.uri}" tidak tersedia. Periksa kembali tautan yang dibuka.',
      fallbackRoute: _homeFor(ref.read(currentUserProvider).valueOrNull),
      location: state.uri.toString(),
    ),
  );

  return router;
});
