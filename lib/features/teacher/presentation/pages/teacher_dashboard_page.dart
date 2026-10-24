import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/repositories/tugas_repository.dart';

final teacherStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  if (!SupabaseService.isReady) return {'jadwalHariIni': 0, 'tugasAktif': 0, 'mendekati': 0, 'selesai': 0, 'belum': 0};
  final user = SupabaseService.tryClient?.auth.currentUser;
  if (user == null) return {'jadwalHariIni': 0, 'tugasAktif': 0, 'mendekati': 0, 'selesai': 0, 'belum': 0};
  final guruId = user.id;
  final hari = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
  try {
    final c = SupabaseService.tryClient;
    if (c == null) return {'jadwalHariIni': 0, 'tugasAktif': 0, 'mendekati': 0, 'selesai': 0, 'belum': 0};
    final jadwal = await c.from('jadwal_pelajaran').select('id').eq('guru_id', guruId).eq('hari', hari);
    final tugasList = await TugasRepository().fetchAll(guruId: guruId);
    int mendekati = 0;
    for (final t in tugasList) {
      final s = DeadlineHelper.getStatus(deadline: t.tenggatWaktu, isCompleted: false);
      if (s == DeadlineStatus.mendekatiTenggat) mendekati++;
    }
    return {'jadwalHariIni': (jadwal as List).length, 'tugasAktif': tugasList.length, 'mendekati': mendekati, 'selesai': 0, 'belum': 0};
  } catch (_) {
    return {'jadwalHariIni': 0, 'tugasAktif': 0, 'mendekati': 0, 'selesai': 0, 'belum': 0};
  }
});

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(teacherStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EduTaskBanner(height: 38),
            const SizedBox(height: 12),
            const Text('Dashboard Guru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Ringkasan mengajar & tugas', style: TextStyle(color: AppColors.textSecondary)),
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
                  _stat('Jadwal Hari Ini', '${m['jadwalHariIni']}', Icons.schedule, AppColors.primary),
                  _stat('Tugas Aktif', '${m['tugasAktif']}', Icons.assignment, AppColors.info),
                  _stat('Mendekati Tenggat', '${m['mendekati']}', Icons.warning_amber, AppColors.warning),
                  _stat('Belum Selesai', '${m['belum']}', Icons.pending, AppColors.error),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }
}
