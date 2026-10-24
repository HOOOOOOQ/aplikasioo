import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/siswa.dart';
import '../../../../shared/repositories/siswa_repository.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../core/config/supabase_config.dart';

class AdminStudentsPage extends ConsumerStatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  ConsumerState<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends ConsumerState<AdminStudentsPage> {
  String? _kelasFilter;
  String _search = '';
  final _searchC = TextEditingController();
  List<Siswa> _list = [];
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
      final data = await SiswaRepository().fetchAll(kelasId: _kelasFilter, search: _search);
      setState(() { _list = data; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showForm({Siswa? existing}) async {
    final namaC = TextEditingController(text: existing?.nama ?? '');
    final nisC = TextEditingController(text: existing?.nomorInduk ?? '');
    String? kelasId = existing?.kelasId;
    final formKey = GlobalKey<FormState>();
    List<dynamic> kelasList = [];
    try {
      kelasList = await KelasRepository().fetchAll();
    } catch (_) {}

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Siswa' : 'Edit Siswa'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nisC, decoration: const InputDecoration(labelText: 'Nomor Induk *'), validator: (v) => Validators.nomorInduk(v)),
                const SizedBox(height: 12),
                TextFormField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama Lengkap *'), validator: (v) => Validators.nama(v)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kelasId,
                  decoration: const InputDecoration(labelText: 'Kelas'),
                  items: kelasList.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(),
                  onChanged: (v) => kelasId = v,
                ),
                const SizedBox(height: 8),
                const Text('Kode akses siswa akan dibuat otomatis. Siswa gunakan kode untuk menandai tugas selesai.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          }, child: Text(existing == null ? 'Tambah' : 'Simpan')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      // generate kode akses if new
      String? kodeAkses;
      if (existing == null) {
        kodeAkses = 'SISWA-${nisC.text.trim().toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      }
      if (existing == null) {
        await SiswaRepository().create(nomorInduk: nisC.text.trim(), nama: namaC.text.trim(), kelasId: kelasId, kodeAkses: kodeAkses);
        if (mounted) showAppSnackBar(context, 'Siswa ditambahkan. Kode: $kodeAkses');
      } else {
        await SiswaRepository().update(existing.id, {'nomor_induk': nisC.text.trim(), 'nama': namaC.text.trim(), 'kelas_id': kelasId});
        if (mounted) showAppSnackBar(context, 'Siswa diperbarui');
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
      appBar: AppBar(title: const Text('Data Siswa'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Tambah Siswa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _searchC, decoration: InputDecoration(hintText: 'Cari nama/NIS...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onChanged: (v) { setState(() => _search = v); _load(); })),
                const SizedBox(width: 8),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          FutureBuilder(
            future: _safeKelasFilter(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) return const SizedBox();
              final list = snap.data!;
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ChoiceChip(label: const Text('Semua Kelas'), selected: _kelasFilter == null, onSelected: (_) { setState(() => _kelasFilter = null); _load(); }),
                    const SizedBox(width: 8),
                    for (final k in list)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(k.namaKelas), selected: _kelasFilter == k.id, onSelected: (_) { setState(() => _kelasFilter = k.id); _load(); }),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _list.isEmpty
                        ? const EmptyState(icon: Icons.people, title: 'Belum Ada Siswa', subtitle: 'Tambahkan data siswa untuk memulai.')
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _list.length,
                            itemBuilder: (ctx, i) {
                              final s = _list[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: AppColors.primaryContainer, child: Text(s.nama.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary))),
                                  title: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('${s.nomorInduk} • ${s.kelasNama ?? "-"}', style: const TextStyle(fontSize: 12)),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                                    ],
                                    onSelected: (v) async {
                                      if (v == 'edit') _showForm(existing: s);
                                      if (v == 'hapus') {
                                        final ok = await showConfirmDialog(context, title: 'Hapus Siswa?', content: 'Hapus ${s.nama}? Data status tugasnya akan ikut terhapus.');
                                        if (ok) {
                                          try {
                                            await SiswaRepository().delete(s.id);
                                            if (mounted) showAppSnackBar(context, 'Siswa dihapus');
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
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _safeKelasFilter() async {
    if (SupabaseConfig.isNotConfigured) return [];
    try {
      return await KelasRepository().fetchAll();
    } catch (_) {
      return [];
    }
  }
}
