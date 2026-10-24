import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/models/status_tugas.dart';
import '../../../../core/config/supabase_config.dart';

class TeacherTaskStatusPage extends StatefulWidget {
  final String taskId;
  const TeacherTaskStatusPage({super.key, required this.taskId});

  @override
  State<TeacherTaskStatusPage> createState() => _TeacherTaskStatusPageState();
}

class _TeacherTaskStatusPageState extends State<TeacherTaskStatusPage> {
  List<StatusTugasSiswa> _list = [];
  Map<String, int> _summary = {};
  bool _loading = true;
  String _filter = 'Semua';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseConfig.isNotConfigured) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final s = await TugasRepository().fetchStatusForTugas(widget.taskId);
      final sum = await TugasRepository().fetchSummary(widget.taskId);
      setState(() { _list = s; _summary = sum; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'Semua' ? _list : _list.where((e) => e.status == (_filter == 'Selesai' ? 'selesai' : 'belum_selesai')).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Status Penyelesaian'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: _loading
          ? const LoadingView()
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _box('Total Siswa', '${_summary['total'] ?? 0}', AppColors.primary),
                        const SizedBox(width: 8),
                        _box('Selesai', '${_summary['selesai'] ?? 0}', AppColors.success),
                        const SizedBox(width: 8),
                        _box('Belum', '${_summary['belum'] ?? 0}', AppColors.error),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedButton<String>(
                    segments: const [ButtonSegment(value: 'Semua', label: Text('Semua')), ButtonSegment(value: 'Selesai', label: Text('Selesai')), ButtonSegment(value: 'Belum', label: Text('Belum'))],
                    selected: {_filter},
                    onSelectionChanged: (s) => setState(() => _filter = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(icon: Icons.people, title: 'Belum Ada Data', subtitle: 'Belum ada siswa yang mengubah status. Siswa perlu verifikasi kode untuk laporan resmi.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = filtered[i];
                            final done = s.status == 'selesai';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: done ? AppColors.successContainer : AppColors.errorContainer, child: Icon(done ? Icons.check : Icons.pending, color: done ? AppColors.success : AppColors.error, size: 18)),
                                title: Text(s.siswaNama ?? s.siswaId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(done ? 'Selesai pada ${s.selesaiPada != null ? s.selesaiPada.toString() : "-"}' : 'Belum selesai', style: const TextStyle(fontSize: 12)),
                                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: done ? AppColors.successContainer : AppColors.errorContainer, borderRadius: BorderRadius.circular(6)), child: Text(done ? 'Selesai' : 'Belum', style: TextStyle(color: done ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600))),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _box(String label, String value, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 18)), Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)])));
  }
}
