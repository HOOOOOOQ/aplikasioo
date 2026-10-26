import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class TeacherSchedulesPage extends StatefulWidget {
  const TeacherSchedulesPage({super.key});

  @override
  State<TeacherSchedulesPage> createState() => _TeacherSchedulesPageState();
}

class _TeacherSchedulesPageState extends State<TeacherSchedulesPage> {
  bool _loading = true;
  List<dynamic> _list = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseConfig.isNotConfigured) {
      setState(() { _loading = false; _error = 'Supabase belum dikonfigurasi'; });
      return;
    }
    setState(() { _loading = true; });
    try {
      if (!SupabaseService.isReady) throw Exception('Supabase belum siap');
      final guruId = SupabaseService.tryClient?.auth.currentUser?.id;
      if (guruId == null) throw Exception('Belum login');
      final data = await JadwalRepository().fetchByGuru(guruId);
      if (!mounted) return;
      setState(() { _list = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Jadwal Mengajar'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.calendar_month, title: 'Belum Ada Jadwal', subtitle: 'Admin akan mengatur jadwal mengajar Anda.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final j = _list[i];
                        final isToday = j.hari == AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
                        return Card(
                          child: ListTile(
                            leading: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: isToday ? AppColors.successContainer : AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(j.hari.substring(0, 3), style: TextStyle(color: isToday ? AppColors.success : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11))),
                            title: Text('${j.mataPelajaranNama ?? "-"} • ${AppDateUtils.formatJamFromString(j.jamMulai)}-${AppDateUtils.formatJamFromString(j.jamSelesai)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text('${j.kelasNama ?? "-"} • ${j.ruang ?? "-"}', style: const TextStyle(fontSize: 12)),
                            trailing: isToday ? const Icon(Icons.today, color: AppColors.success) : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
