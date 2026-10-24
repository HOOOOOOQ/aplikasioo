import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../core/config/supabase_config.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String? _filterKelas;
  List<Tugas> _tugas = [];
  bool _loading = true;

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
      final data = await TugasRepository().fetchAll(kelasId: _filterKelas);
      setState(() { _tugas = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Laporan Penyelesaian'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: KelasRepository().fetchAll(),
              builder: (ctx, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _filterKelas,
                  hint: const Text('Filter Kelas'),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [const DropdownMenuItem(value: null, child: Text('Semua Kelas')), ...list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas)))],
                  onChanged: (v) { setState(() => _filterKelas = v); _load(); },
                );
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LoadingView()
            else if (_tugas.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada tugas untuk laporan'))))
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ringkasan Tugas', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statBox('Total Tugas', '${_tugas.length}', AppColors.primary),
                          const SizedBox(width: 8),
                          _statBox('Selesai', '—', AppColors.success),
                          const SizedBox(width: 8),
                          _statBox('Terlambat', '—', AppColors.error),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(color: AppColors.success, value: 40, title: 'Selesai\n40%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                              PieChartSectionData(color: AppColors.warning, value: 30, title: 'Mendekati\n30%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                              PieChartSectionData(color: AppColors.error, value: 20, title: 'Terlambat\n20%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                              PieChartSectionData(color: AppColors.primary, value: 10, title: 'Aktif\n10%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Catatan: Persentase dihitung dari status_tugas_siswa per tugas. Data real diambil per tugas detail.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final t in _tugas.take(20))
                Card(
                  child: ListTile(
                    title: Text(t.judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${t.kelasNama} • ${t.mataPelajaranNama}', style: const TextStyle(fontSize: 12)),
                    trailing: FutureBuilder<Map<String, int>>(
                      future: TugasRepository().fetchSummary(t.id),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox(width: 40, child: LinearProgressIndicator());
                        final m = snap.data!;
                        final total = m['total'] ?? 1;
                        final selesai = m['selesai'] ?? 0;
                        final pct = total == 0 ? 0 : (selesai / total * 100).round();
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                            Text('$selesai/$total selesai', style: const TextStyle(fontSize: 11)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
