import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key});

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  List<Kelas> _list = [];
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
      final data = await KelasRepository().fetchAll();
      if (!mounted) return;
      setState(() { _list = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showForm({Kelas? existing}) async {
    final namaC = TextEditingController(text: existing?.namaKelas ?? '');
    final tingkatC = TextEditingController(text: existing?.tingkat ?? '');
    final tahunC = TextEditingController(text: existing?.tahunAjaran ?? '2024/2025');
    final formKey = GlobalKey<FormState>();
    String? waliKelasId = existing?.waliKelasId;
    List<Map<String, dynamic>> gurus = [];
    try {
      final c = SupabaseService.tryClient;
      if (c != null) {
        final d = await c.from('profiles').select('id, full_name').eq('role', 'guru');
        gurus = (d as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Kelas' : 'Edit Kelas'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama Kelas *'), validator: (v) => Validators.requiredField(v, fieldName: 'Nama Kelas')),
                const SizedBox(height: 12),
                TextFormField(controller: tingkatC, decoration: const InputDecoration(labelText: 'Tingkat (misal: 7, 8, 9)')),
                const SizedBox(height: 12),
                TextFormField(controller: tahunC, decoration: const InputDecoration(labelText: 'Tahun Ajaran')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: waliKelasId,
                  decoration: const InputDecoration(labelText: 'Wali Kelas (opsional)'),
                  items: [const DropdownMenuItem(value: null, child: Text('- Tidak ada -')), ...gurus.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['full_name'] as String)))],
                  onChanged: (v) => waliKelasId = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () { if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true); }, child: Text(existing == null ? 'Tambah' : 'Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (existing == null) {
        await KelasRepository().create(namaKelas: namaC.text.trim(), tingkat: tingkatC.text.trim().isEmpty ? null : tingkatC.text.trim(), tahunAjaran: tahunC.text.trim(), waliKelasId: waliKelasId);
        if (mounted) showAppSnackBar(context, 'Kelas ditambahkan');
      } else {
        await KelasRepository().update(existing.id, {'nama_kelas': namaC.text.trim(), 'tingkat': tingkatC.text.trim(), 'tahun_ajaran': tahunC.text.trim(), 'wali_kelas_id': waliKelasId});
        if (mounted) showAppSnackBar(context, 'Kelas diperbarui');
      }
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Data Kelas'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Tambah Kelas')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.class_, title: 'Belum Ada Kelas', subtitle: 'Tambahkan kelas untuk mengelola siswa, jadwal, dan tugas.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final k = _list[i];
                        return Card(
                          child: ListTile(
                            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.class_, color: AppColors.primary)),
                            title: Text(k.namaKelas, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${k.tingkat ?? "-"} • ${k.tahunAjaran ?? "-"} • Wali: ${k.waliKelasNama ?? "-"}'),
                            trailing: PopupMenuButton(
                              itemBuilder: (ctx) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'hapus', child: Text('Hapus'))],
                              onSelected: (v) async {
                                if (v == 'edit') _showForm(existing: k);
                                if (v == 'hapus') {
                                  final ok = await showConfirmDialog(context, title: 'Hapus Kelas?', content: 'Hapus ${k.namaKelas}? Pastikan tidak ada siswa/jadwal terkait.');
                                  if (ok) {
                                    try {
                                      await KelasRepository().delete(k.id);
                                      if (mounted) showAppSnackBar(context, 'Kelas dihapus');
                                      _load();
                                    } catch (e) {
                                      if (mounted) showAppSnackBar(context, 'Gagal: $e', isError: true);
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
