import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/mapel_repository.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class AdminSchedulesPage extends StatefulWidget {
  const AdminSchedulesPage({super.key});

  @override
  State<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends State<AdminSchedulesPage> {
  List<Jadwal> _list = [];
  bool _loading = true;
  String? _error;
  String? _filterKelas;
  String? _filterHari;

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
      final d = await JadwalRepository().fetchAll(kelasId: _filterKelas, hari: _filterHari);
      if (!mounted) return;
      setState(() { _list = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showForm({Jadwal? existing}) async {
    if (!SupabaseService.isReady) {
      showAppSnackBar(context, 'Supabase belum dikonfigurasi', isError: true);
      return;
    }
    final kelasList = await KelasRepository().fetchAll();
    final mapelList = await MapelRepository().fetchAll();
    if (kelasList.isEmpty || mapelList.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Data kelas/mapel belum tersedia', isError: true);
      return;
    }
    final tryC = SupabaseService.tryClient;
    if (tryC == null) throw Exception('Supabase belum siap');
    final guruData = await tryC.from('profiles').select('id, full_name').eq('role', 'guru');
    final gurus = (guruData as List).cast<Map<String, dynamic>>();

    String? kelasId = existing?.kelasId ?? kelasList.firstOrNull?.id;
    String? guruId = existing?.guruId ?? gurus.firstOrNull?['id'] as String?;
    String? mapelId = existing?.mataPelajaranId ?? mapelList.firstOrNull?.id;
    String hari = existing?.hari ?? 'Senin';
    final jamMulaiC = TextEditingController(text: existing != null ? AppDateUtils.formatJamFromString(existing.jamMulai) : '07:00');
    final jamSelesaiC = TextEditingController(text: existing != null ? AppDateUtils.formatJamFromString(existing.jamSelesai) : '08:00');
    final ruangC = TextEditingController(text: existing?.ruang ?? '');
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(value: kelasId, decoration: const InputDecoration(labelText: 'Kelas *'), items: kelasList.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(), onChanged: (v) => kelasId = v, validator: (v) => Validators.requiredField(v, fieldName: 'Kelas')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: hari, decoration: const InputDecoration(labelText: 'Hari *'), items: AppDateUtils.daftarHari.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(), onChanged: (v) => hari = v!),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: jamMulaiC, decoration: const InputDecoration(labelText: 'Jam Mulai (HH:mm) *'), validator: (v) => Validators.requiredField(v, fieldName: 'Jam Mulai'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: jamSelesaiC, decoration: const InputDecoration(labelText: 'Jam Selesai (HH:mm) *'), validator: (v) => Validators.requiredField(v, fieldName: 'Jam Selesai'))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: guruId, decoration: const InputDecoration(labelText: 'Guru *'), items: gurus.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['full_name'] as String))).toList(), onChanged: (v) => guruId = v, validator: (v) => Validators.requiredField(v, fieldName: 'Guru')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: mapelId, decoration: const InputDecoration(labelText: 'Mata Pelajaran *'), items: mapelList.map((m) => DropdownMenuItem(value: m.id, child: Text(m.namaMapel))).toList(), onChanged: (v) => mapelId = v, validator: (v) => Validators.requiredField(v, fieldName: 'Mapel')),
                const SizedBox(height: 12),
                TextFormField(controller: ruangC, decoration: const InputDecoration(labelText: 'Ruang')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () {
            final timeErr = Validators.timeRange(jamMulaiC.text, jamSelesaiC.text);
            if (timeErr != null) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(timeErr))); return; }
            if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
          }, child: Text(existing == null ? 'Tambah' : 'Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final payload = {'kelas_id': kelasId, 'guru_id': guruId, 'mata_pelajaran_id': mapelId, 'hari': hari, 'jam_mulai': '${jamMulaiC.text}:00', 'jam_selesai': '${jamSelesaiC.text}:00', 'ruang': ruangC.text.trim().isEmpty ? null : ruangC.text.trim()};
      if (existing == null) {
        await JadwalRepository().create(payload);
        if (mounted) showAppSnackBar(context, 'Jadwal ditambahkan');
      } else {
        await JadwalRepository().update(existing.id, payload);
        if (mounted) showAppSnackBar(context, 'Jadwal diperbarui');
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
      appBar: AppBar(title: const Text('Jadwal Pelajaran'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Tambah Jadwal')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder(
                    future: SupabaseConfig.isNotConfigured ? Future.value(<Kelas>[]) : KelasRepository().fetchAll(),
                    builder: (ctx, snap) {
                      final list = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: _filterKelas,
                        hint: const Text('Filter Kelas'),
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: [const DropdownMenuItem(value: null, child: Text('Semua Kelas')), ...list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas)))],
                        onChanged: (v) { setState(() => _filterKelas = v); _load(); },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterHari,
                    hint: const Text('Filter Hari'),
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: [const DropdownMenuItem(value: null, child: Text('Semua Hari')), ...AppDateUtils.daftarHari.map((h) => DropdownMenuItem(value: h, child: Text(h)))],
                    onChanged: (v) { setState(() => _filterHari = v); _load(); },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _list.isEmpty
                        ? const EmptyState(icon: Icons.calendar_month, title: 'Belum Ada Jadwal', subtitle: 'Tambahkan jadwal untuk menampilkan ke siswa dan guru.')
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _list.length,
                            itemBuilder: (ctx, i) {
                              final j = _list[i];
                              return Card(
                                child: ListTile(
                                  leading: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(j.hari.length >= 3 ? j.hari.substring(0, 3) : j.hari, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11))),
                                  title: Text('${j.mataPelajaranNama ?? "-"} • ${AppDateUtils.formatJamFromString(j.jamMulai)}-${AppDateUtils.formatJamFromString(j.jamSelesai)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('${j.kelasNama ?? "-"} • ${j.guruNama ?? "-"} • ${j.ruang ?? "-"}', style: const TextStyle(fontSize: 12)),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (ctx) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'hapus', child: Text('Hapus'))],
                                    onSelected: (v) async {
                                      if (v == 'edit') _showForm(existing: j);
                                      if (v == 'hapus') {
                                        final ok = await showConfirmDialog(context, title: 'Hapus Jadwal?', content: 'Hapus jadwal ${j.mataPelajaranNama} hari ${j.hari}?');
                                        if (ok) {
                                          try {
                                            await JadwalRepository().delete(j.id);
                                            if (mounted) showAppSnackBar(context, 'Jadwal dihapus');
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
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
