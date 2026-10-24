import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../core/config/supabase_config.dart';

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key});

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends State<AdminTasksPage> {
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
      final data = await TugasRepository().fetchAll();
      setState(() { _list = data; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Manajemen Tugas'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.assignment, title: 'Belum Ada Tugas', subtitle: 'Tugas yang dibuat guru akan tampil di sini.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final t = _list[i];
                        final status = DeadlineHelper.getStatus(deadline: t.tenggatWaktu, isCompleted: false);
                        return Card(
                          child: ListTile(
                            title: Text(t.judul, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${t.mataPelajaranNama ?? "-"} • ${t.kelasNama ?? "-"} • ${t.guruNama ?? "-"}\nTenggat: ${AppDateUtils.formatTanggalJam(t.tenggatWaktu)}', style: const TextStyle(fontSize: 12)),
                            isThreeLine: true,
                            trailing: Icon(DeadlineHelper.iconForStatus(status), color: DeadlineHelper.colorForStatus(status)),
                          ),
                        );
                      },
                    ),
    );
  }
}
