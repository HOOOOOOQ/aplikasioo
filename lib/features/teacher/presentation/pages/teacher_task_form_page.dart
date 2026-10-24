import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/mapel_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/config/supabase_config.dart';

class TeacherTaskFormPage extends StatefulWidget {
  final String? taskId;
  const TeacherTaskFormPage({super.key, this.taskId});

  @override
  State<TeacherTaskFormPage> createState() => _TeacherTaskFormPageState();
}

class _TeacherTaskFormPageState extends State<TeacherTaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulC = TextEditingController();
  final _deskripsiC = TextEditingController();
  String? _kelasId;
  String? _mapelId;
  DateTime? _tanggalMulai;
  DateTime? _tenggat;
  String? _lampiranPath;
  List<int>? _lampiranBytes;
  String? _lampiranName;
  bool _loading = false;
  bool _initialLoading = false;

  @override
  void initState() {
    super.initState();
    _tanggalMulai = DateTime.now();
    _tenggat = DateTime.now().add(const Duration(days: 7));
    if (widget.taskId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _initialLoading = true);
    try {
      final t = await TugasRepository().fetchById(widget.taskId!);
      if (t != null) {
        _judulC.text = t.judul;
        _deskripsiC.text = t.deskripsi;
        _kelasId = t.kelasId;
        _mapelId = t.mataPelajaranId;
        _tanggalMulai = t.tanggalMulai;
        _tenggat = t.tenggatWaktu;
        _lampiranPath = t.lampiranPath;
      }
    } catch (_) {}
    setState(() => _initialLoading = false);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.size > 10 * 1024 * 1024) {
      if (mounted) showAppSnackBar(context, 'File melebihi 10MB', isError: true);
      return;
    }
    final name = file.name;
    if (!FileUtils.isAllowedExtension(name)) {
      if (mounted) showAppSnackBar(context, 'Ekstensi tidak diizinkan', isError: true);
      return;
    }
    setState(() {
      _lampiranBytes = file.bytes;
      _lampiranName = name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dateErr = Validators.dateRange(_tanggalMulai, _tenggat);
    if (dateErr != null) {
      showAppSnackBar(context, dateErr, isError: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.taskId == null ? 'Simpan Tugas?' : 'Perbarui Tugas?'),
        content: const Text('Pastikan data sudah benar sebelum menyimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      String? lampiranPath = _lampiranPath;
      if (_lampiranBytes != null && _lampiranName != null) {
        lampiranPath = await TugasRepository().uploadLampiran(fileName: _lampiranName!, bytes: _lampiranBytes!);
      }
      final guruId = SupabaseService.tryClient?.auth.currentUser?.id;
      if (guruId == null) throw Exception('Belum login — silakan login ulang');
      final payload = {
        'judul': _judulC.text.trim(),
        'deskripsi': _deskripsiC.text.trim(),
        'guru_id': guruId,
        'kelas_id': _kelasId,
        'mata_pelajaran_id': _mapelId,
        'tanggal_mulai': _tanggalMulai!.toIso8601String(),
        'tenggat_waktu': _tenggat!.toIso8601String(),
        'lampiran_path': lampiranPath,
        'status_publikasi': 'published',
      };
      if (widget.taskId == null) {
        await TugasRepository().create(payload);
        if (mounted) {
          showAppSnackBar(context, 'Tugas berhasil dibuat');
          Navigator.pop(context);
        }
      } else {
        await TugasRepository().update(widget.taskId!, payload);
        if (mounted) {
          showAppSnackBar(context, 'Tugas diperbarui');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return Scaffold(appBar: AppBar(title: const Text('Memuat...')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.taskId == null ? 'Tambah Tugas' : 'Edit Tugas'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _judulC, decoration: const InputDecoration(labelText: 'Judul Tugas *', prefixIcon: Icon(Icons.title)), validator: Validators.title),
              const SizedBox(height: 12),
              TextFormField(controller: _deskripsiC, decoration: const InputDecoration(labelText: 'Deskripsi / Instruksi *'), maxLines: 5, validator: Validators.description),
              const SizedBox(height: 12),
              FutureBuilder(future: KelasRepository().fetchAll(), builder: (ctx, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(value: _kelasId, decoration: const InputDecoration(labelText: 'Kelas Tujuan *', prefixIcon: Icon(Icons.class_outlined)), items: list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(), onChanged: (v) => setState(() => _kelasId = v), validator: (v) => Validators.requiredField(v, fieldName: 'Kelas'));
              }),
              const SizedBox(height: 12),
              FutureBuilder(future: MapelRepository().fetchAll(), builder: (ctx, snap) {
                final list = snap.data ?? [];
                return DropdownButtonFormField<String>(value: _mapelId, decoration: const InputDecoration(labelText: 'Mata Pelajaran *', prefixIcon: Icon(Icons.menu_book_outlined)), items: list.map((m) => DropdownMenuItem(value: m.id, child: Text(m.namaMapel))).toList(), onChanged: (v) => setState(() => _mapelId = v), validator: (v) => Validators.requiredField(v, fieldName: 'Mata Pelajaran'));
              }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateField('Tanggal Mulai *', _tanggalMulai, (d) => setState(() => _tanggalMulai = d))),
                const SizedBox(width: 8),
                Expanded(child: _dateField('Tenggat Waktu *', _tenggat, (d) => setState(() => _tenggat = d))),
              ]),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Lampiran (opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_lampiranName != null) ...[
                      Row(children: [const Icon(Icons.attach_file, size: 16), const SizedBox(width: 4), Expanded(child: Text(_lampiranName!, style: const TextStyle(fontSize: 12))), IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() { _lampiranBytes = null; _lampiranName = null; }))]),
                    ] else if (_lampiranPath != null)
                      Text('File saat ini: $_lampiranPath', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text('Pilih File (max 10MB)')),
                    const Text('PDF, DOC, PPT, JPG, PNG, ZIP diizinkan', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(height: 48, child: ElevatedButton(onPressed: _loading ? null : _save, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.taskId == null ? 'Buat Tugas' : 'Perbarui Tugas'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d == null) return;
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()));
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event)),
        child: Text(value != null ? AppDateUtils.formatTanggalJam(value) : '-', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
