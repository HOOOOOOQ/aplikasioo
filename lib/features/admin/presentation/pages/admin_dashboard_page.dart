import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
                const Spacer(),
                const Icon(Icons.trending_up, size: 16, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

final adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  if (SupabaseConfig.isNotConfigured) return {'siswa': 0, 'guru': 0, 'kelas': 0, 'mapel': 0, 'jadwal': 0, 'tugas': 0};
  final c = SupabaseService.client;
  final results = await Future.wait([
    c.from('siswa').select('id'),
    c.from('profiles').select('id').eq('role', 'guru'),
    c.from('kelas').select('id'),
    c.from('mata_pelajaran').select('id'),
    c.from('jadwal_pelajaran').select('id'),
    c.from('tugas').select('id').eq('status_publikasi', 'published'),
  ]);
  return {
    'siswa': (results[0] as List).length,
    'guru': (results[1] as List).length,
    'kelas': (results[2] as List).length,
    'mapel': (results[3] as List).length,
    'jadwal': (results[4] as List).length,
    'tugas': (results[5] as List).length,
  };
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Ringkasan data sekolah', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            stats.when(
              loading: () => const LoadingView(),
              error: (e, _) => Text('Error: $e'),
              data: (m) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  StatCard(title: 'Total Siswa', value: '${m['siswa']}', icon: Icons.people, color: AppColors.primary),
                  StatCard(title: 'Total Guru', value: '${m['guru']}', icon: Icons.badge, color: AppColors.success),
                  StatCard(title: 'Total Kelas', value: '${m['kelas']}', icon: Icons.class_, color: AppColors.warning),
                  StatCard(title: 'Mata Pelajaran', value: '${m['mapel']}', icon: Icons.menu_book, color: AppColors.info),
                  StatCard(title: 'Jadwal', value: '${m['jadwal']}', icon: Icons.calendar_month, color: AppColors.primaryDark),
                  StatCard(title: 'Tugas Aktif', value: '${m['tugas']}', icon: Icons.assignment, color: AppColors.error),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Akses Cepat', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _quickBtn(context, 'Kelola Siswa', Icons.person_add, '/admin/siswa'),
                        _quickBtn(context, 'Tambah Jadwal', Icons.calendar_today, '/admin/jadwal'),
                        _quickBtn(context, 'Lihat Laporan', Icons.analytics, '/admin/laporan'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn(BuildContext ctx, String label, IconData icon, String route) {
    return ElevatedButton.icon(onPressed: () {}, icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 12)));
  }
}
