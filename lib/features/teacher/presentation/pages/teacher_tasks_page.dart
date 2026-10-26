import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class TeacherTasksPage extends StatefulWidget {
  const TeacherTasksPage({super.key});

  @override
  State<TeacherTasksPage> createState() => _TeacherTasksPageState();
}

class _TeacherTasksPageState extends State<TeacherTasksPage> {
  List<Tugas> _list = [];
  bool _loading = true;
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
    setState(() { _loading = true; _error = null; });
    try {
      if (!SupabaseService.isReady) throw Exception('Supabase belum siap');
      final guruId = SupabaseService.tryClient?.auth.currentUser?.id;
      final data = await TugasRepository().fetchAll(guruId: guruId);
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
      appBar: AppBar(title: const Text('Daftar Tugas'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/guru/tugas/tambah'), icon: const Icon(Icons.add), label: const Text('Tambah Tugas')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.assignment, title: 'Belum Ada Tugas', subtitle: 'Buat tugas pertama untuk kelas Anda.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final t = _list[i];
                        final status = DeadlineHelper.getStatus(deadline: t.tenggatWaktu, isCompleted: false);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Expanded(child: Text(t.judul, style: const TextStyle(fontWeight: FontWeight.w600))), StatusChip(status: status)]),
                                const SizedBox(height: 4),
                                Text('${t.mataPelajaranNama ?? "-"} • ${t.kelasNama ?? "-"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text('Tenggat: ${AppDateUtils.formatTanggalJam(t.tenggatWaktu)} • ${AppDateUtils.relativeDeadline(t.tenggatWaktu)}', style: TextStyle(fontSize: 11, color: DeadlineHelper.colorForStatus(status))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(onPressed: () => context.push('/guru/tugas/${t.id}'), child: const Text('Detail')),
                                    TextButton(onPressed: () => context.push('/guru/tugas/${t.id}/status'), child: const Text('Status Siswa')),
                                    const Spacer(),
                                    PopupMenuButton(
                                      itemBuilder: (ctx) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'hapus', child: Text('Hapus'))],
                                      onSelected: (v) async {
                                        if (v == 'edit') context.push('/guru/tugas/${t.id}/edit');
                                        if (v == 'hapus') {
                                          final ok = await showConfirmDialog(context, title: 'Hapus Tugas?', content: 'Hapus "${t.judul}"?');
                                          if (ok) {
                                            try {
                                              await TugasRepository().delete(t.id);
                                              if (mounted) showAppSnackBar(context, 'Tugas dihapus');
                                              _load();
                                            } catch (e) {
                                              if (mounted) showAppSnackBar(context, 'Gagal: $e', isError: true);
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
