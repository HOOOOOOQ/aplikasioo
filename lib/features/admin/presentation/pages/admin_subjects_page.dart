import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/mata_pelajaran.dart';
import '../../../../shared/repositories/mapel_repository.dart';
import '../../../../core/config/supabase_config.dart';

class AdminSubjectsPage extends StatefulWidget {
  const AdminSubjectsPage({super.key});

  @override
  State<AdminSubjectsPage> createState() => _AdminSubjectsPageState();
}

class _AdminSubjectsPageState extends State<AdminSubjectsPage> {
  List<MataPelajaran> _list = [];
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
      final d = await MapelRepository().fetchAll();
      setState(() { _list = d; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showForm({MataPelajaran? existing}) async {
    final namaC = TextEditingController(text: existing?.namaMapel ?? '');
    final descC = TextEditingController(text: existing?.deskripsi ?? '');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Mata Pelajaran' : 'Edit Mata Pelajaran'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama Mapel *'), validator: (v) => Validators.requiredField(v, fieldName: 'Nama Mapel')),
              const SizedBox(height: 12),
              TextFormField(controller: descC, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(existing == null ? 'Tambah' : 'Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (existing == null) {
        await MapelRepository().create(nama: namaC.text.trim(), deskripsi: descC.text.trim().isEmpty ? null : descC.text.trim());
        if (mounted) showAppSnackBar(context, 'Mapel ditambahkan');
      } else {
        await MapelRepository().update(existing.id, {'nama_mapel': namaC.text.trim(), 'deskripsi': descC.text.trim()});
        if (mounted) showAppSnackBar(context, 'Mapel diperbarui');
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
      appBar: AppBar(title: const Text('Mata Pelajaran'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Tambah Mapel')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.menu_book, title: 'Belum Ada Mata Pelajaran', subtitle: 'Tambahkan mata pelajaran untuk digunakan di jadwal dan tugas.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final m = _list[i];
                        return Card(
                          child: ListTile(
                            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.infoContainer, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.menu_book, color: AppColors.info)),
                            title: Text(m.namaMapel, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(m.deskripsi ?? '-'),
                            trailing: PopupMenuButton(
                              itemBuilder: (ctx) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'hapus', child: Text('Hapus'))],
                              onSelected: (v) async {
                                if (v == 'edit') _showForm(existing: m);
                                if (v == 'hapus') {
                                  final ok = await showConfirmDialog(context, title: 'Hapus Mapel?', content: 'Hapus ${m.namaMapel}?');
                                  if (ok) {
                                    try {
                                      await MapelRepository().delete(m.id);
                                      if (mounted) showAppSnackBar(context, 'Mapel dihapus');
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
