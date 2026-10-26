import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/mata_pelajaran.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/mapel_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/services/attachment_service.dart';
import '../../../../shared/services/supabase_service.dart';

class TeacherTaskFormPage extends ConsumerStatefulWidget {
  final String? taskId;

  /// Admin boleh memperbarui tugas milik guru (moderasi & lampiran) tanpa
  /// mengambil alih kepemilikan tugas: `guru_id` tidak pernah diubah.
  final bool adminMode;

  const TeacherTaskFormPage({super.key, this.taskId, this.adminMode = false});

  @override
  ConsumerState<TeacherTaskFormPage> createState() => _TeacherTaskFormPageState();
}

class _TeacherTaskFormPageState extends ConsumerState<TeacherTaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulC = TextEditingController();
  final _deskripsiC = TextEditingController();

  late Future<List<Kelas>> _kelasFuture;
  late Future<List<MataPelajaran>> _mapelFuture;

  String? _kelasId;
  String? _mapelId;
  DateTime _tanggalMulai = AppDateUtils.nowJakarta();
  DateTime _tenggat = AppDateUtils.nowJakarta().add(const Duration(days: 7));
  String? _lampiranPath; // path lama yang sudah tersimpan
  String? _ownerGuruId; // guru pemilik tugas (dipakai saat adminMode)
  bool _hapusLampiran = false;

  Uint8List? _fileBytes;
  String? _fileName;

  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEdit => widget.taskId != null && widget.taskId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _kelasFuture = KelasRepository().fetchAll();
    _mapelFuture = MapelRepository().fetchAll();
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() {
    _judulC.dispose();
    _deskripsiC.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _initialLoading = true);
    try {
      final t = await TugasRepository().fetchById(widget.taskId!);
      if (!mounted) return;
      if (t == null) {
        showAppSnackBar(context, 'Tugas tidak ditemukan atau bukan milik Anda.', isError: true);
        _exitAfterSave();
        return;
      }
      setState(() {
        _judulC.text = t.judul;
        _deskripsiC.text = t.deskripsi;
        _kelasId = t.kelasId;
        _mapelId = t.mataPelajaranId;
        _tanggalMulai = t.tanggalMulai;
        _tenggat = t.tenggatWaktu;
        _lampiranPath = t.lampiranPath;
        _ownerGuruId = t.guruId;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      final error = AttachmentService.validate(fileName: file.name, sizeBytes: file.size);
      if (error != null) {
        if (!mounted) return;
        showAppSnackBar(context, error, isError: true);
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        showAppSnackBar(context, 'Gagal membaca file. Coba pilih ulang.', isError: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _hapusLampiran = false;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Tidak dapat membuka pemilih file: ${AppError.from(e).shortMessage}',
          isError: true);
    }
  }

  /// Kembali ke halaman sebelumnya; bila rute dibuka langsung (deep link /
  /// `go`), arahkan ke daftar tugas agar pengguna tidak terjebak.
  void _exitAfterSave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.adminMode ? '/admin/tugas' : '/guru/tugas');
    }
  }

  String? _validateDates() {
    final err = Validators.dateRange(_tanggalMulai, _tenggat);
    if (err != null) return err;
    if (_tenggat.isBefore(_tanggalMulai)) return 'Tenggat tidak boleh sebelum tanggal mulai.';
    return null;
  }

  /// Alur simpan yang aman:
  ///  - tugas BARU: insert tugas (draft) → unggah lampiran → set lampiran_path →
  ///    (opsional) terbitkan. Jika unggah gagal, tugas yang baru dibuat dihapus
  ///    supaya tidak ada tugas setengah jadi tanpa lampiran.
  ///  - tugas LAMA: unggah lampiran baru → update tugas dalam satu patch →
  ///    hapus file lama. Jika update gagal, file baru dihapus lagi.
  Future<void> _save({required bool publish}) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dateErr = _validateDates();
    if (dateErr != null) {
      showAppSnackBar(context, dateErr, isError: true);
      return;
    }
    if (_kelasId == null || _mapelId == null) {
      showAppSnackBar(context, 'Pilih kelas dan mata pelajaran.', isError: true);
      return;
    }

    final sessionUid = SupabaseService.currentUser?.id;
    if (sessionUid == null) {
      showAppSnackBar(context, 'Sesi berakhir. Silakan login ulang.', isError: true);
      return;
    }
    // Pemilik tugas tetap guru aslinya; admin hanya menyunting.
    final guruId = widget.adminMode ? (_ownerGuruId ?? '') : sessionUid;
    if (guruId.isEmpty) {
      showAppSnackBar(context, 'Tugas ini tidak memiliki data guru pemilik.', isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: _isEdit ? 'Simpan perubahan?' : (publish ? 'Terbitkan tugas?' : 'Simpan sebagai draft?'),
      content: publish
          ? 'Tugas akan langsung terlihat oleh siswa di kelas tujuan.'
          : 'Draft hanya terlihat oleh Anda dan admin sampai diterbitkan.',
      confirmLabel: _isEdit ? 'Simpan' : (publish ? 'Terbitkan' : 'Simpan draft'),
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);

    final basePayload = <String, dynamic>{
      'judul': _judulC.text.trim(),
      'deskripsi': _deskripsiC.text.trim(),
      'kelas_id': _kelasId,
      'mata_pelajaran_id': _mapelId,
      'tanggal_mulai': _tanggalMulai.toUtc().toIso8601String(),
      'tenggat_waktu': _tenggat.toUtc().toIso8601String(),
    };
    final repo = TugasRepository();

    // === EDIT ===
    if (_isEdit) {
      final tugasId = widget.taskId!;
      String? newPath;
      var uploadedNew = false;
      try {
        if (_fileBytes != null && _fileName != null) {
          newPath = await AttachmentService.uploadForTugas(
            tugasId: tugasId,
            guruId: guruId,
            fileName: _fileName!,
            bytes: _fileBytes!,
          );
          uploadedNew = true;
        }

        final patch = <String, dynamic>{
          ...basePayload,
          if (uploadedNew) 'lampiran_path': newPath,
          if (_hapusLampiran && !uploadedNew) 'lampiran_path': null,
          if (publish) 'status_publikasi': 'published',
        };

        await repo.update(tugasId, patch);

        // DB sudah commit: bersihkan file lama yang tidak lagi dipakai.
        final oldPath = _lampiranPath;
        if ((uploadedNew || _hapusLampiran) && oldPath != null && oldPath != newPath) {
          await AttachmentService.delete(oldPath);
        }

        if (!mounted) return;
        showAppSnackBar(context, 'Tugas diperbarui.');
        _exitAfterSave();
      } catch (e) {
        if (uploadedNew && newPath != null) {
          // rollback file baru agar tidak yatim
          await AttachmentService.delete(newPath);
        }
        if (!mounted) return;
        showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    // === INSERT BARU ===
    Tugas? created;
    String? uploadedPath;
    try {
      created = await repo.create({
        ...basePayload,
        'guru_id': guruId,
        'lampiran_path': null,
        'status_publikasi': 'draft',
      });

      if (_fileBytes != null && _fileName != null) {
        uploadedPath = await AttachmentService.uploadForTugas(
          tugasId: created.id,
          guruId: guruId,
          fileName: _fileName!,
          bytes: _fileBytes!,
        );
      }

      final finalPatch = <String, dynamic>{
        if (uploadedPath != null) 'lampiran_path': uploadedPath,
        if (publish) 'status_publikasi': 'published',
      };
      if (finalPatch.isNotEmpty) {
        await repo.update(created.id, finalPatch);
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        publish ? 'Tugas diterbitkan.' : 'Tugas disimpan sebagai draft.',
      );
      _exitAfterSave();
    } catch (e) {
      // Bersihkan agar tidak ada tugas/file setengah jadi.
      if (uploadedPath != null) await AttachmentService.delete(uploadedPath);
      if (created != null) {
        try {
          await repo.delete(created.id);
        } catch (_) {
          // jika hapus gagal, tugas tetap draft tanpa lampiran → tidak tampil ke siswa
        }
      }
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime({required bool isDeadline}) async {
    final current = isDeadline ? _tenggat : _tanggalMulai;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null || !mounted) return;
    setState(() {
      final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isDeadline) {
        _tenggat = picked;
      } else {
        _tanggalMulai = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AppHeroHeader(
              compact: true,
              eyebrow: _isEdit ? 'Edit tugas' : 'Tugas baru',
              title: _isEdit ? 'Perbarui Tugas' : 'Buat Tugas',
              subtitle: 'Isi detail tugas, lalu unggah lampiran bila perlu.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _judulC,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Judul tugas',
                hintText: 'Mis. Membuat desain antarmuka aplikasi',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: Validators.title,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _deskripsiC,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Deskripsi / instruksi',
                hintText: 'Jelaskan langkah pengerjaan dan kriteria penilaian.',
                alignLabelWithHint: true,
              ),
              validator: Validators.description,
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<Kelas>>(
              future: _kelasFuture,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <Kelas>[];
                final valid = list.any((k) => k.id == _kelasId) ? _kelasId : null;
                return DropdownButtonFormField<String>(
                  value: valid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kelas tujuan',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(),
                  onChanged: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : (value) => setState(() => _kelasId = value),
                  validator: (v) => Validators.requiredField(v, fieldName: 'Kelas'),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<MataPelajaran>>(
              future: _mapelFuture,
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <MataPelajaran>[];
                final valid = list.any((m) => m.id == _mapelId) ? _mapelId : null;
                return DropdownButtonFormField<String>(
                  value: valid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mata pelajaran',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: list.map((m) => DropdownMenuItem(value: m.id, child: Text(m.namaMapel))).toList(),
                  onChanged: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : (value) => setState(() => _mapelId = value),
                  validator: (v) => Validators.requiredField(v, fieldName: 'Mata pelajaran'),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                    label: 'Tanggal mulai',
                    value: _tanggalMulai,
                    icon: Icons.event_available_rounded,
                    onTap: () => _pickDateTime(isDeadline: false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _dateTile(
                    label: 'Tenggat',
                    value: _tenggat,
                    icon: Icons.event_busy_rounded,
                    onTap: () => _pickDateTime(isDeadline: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Lampiran (opsional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        'Maks ${AppConstants.maxAttachmentSizeMb} MB',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_fileName != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                      title: Text(_fileName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        _fileBytes == null ? '' : FileUtils.formatBytes(_fileBytes!.length),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        tooltip: 'Batalkan pilihan file',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _fileName = null;
                          _fileBytes = null;
                        }),
                      ),
                    )
                  else if (_lampiranPath != null && !_hapusLampiran)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                      title: const Text('Lampiran tersimpan', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        AttachmentService.displayName(_lampiranPath!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        tooltip: 'Hapus lampiran saat disimpan',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(() => _hapusLampiran = true),
                      ),
                    )
                  else if (_hapusLampiran)
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Lampiran akan dihapus setelah tugas disimpan.',
                            style: TextStyle(fontSize: 12, color: AppColors.warning),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _hapusLampiran = false),
                          child: const Text('Urungkan'),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_fileBytes == null ? 'Pilih file' : 'Ganti file'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'PDF, DOC/DOCX, PPT/PPTX, XLS/XLSX, JPG/PNG, ZIP. '
                    'File disimpan di bucket privat dan dibuka lewat signed URL.',
                    style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_isEdit)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _save(publish: false),
                      child: const Text('Simpan draft'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : () => _save(publish: true),
                      child: const Text('Terbitkan'),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _loading ? null : () => _save(publish: false),
                child: Text(widget.adminMode ? 'Simpan perubahan (admin)' : 'Simpan perubahan'),
              ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Menyimpan tugas & mengunggah lampiran…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(
          AppDateUtils.formatTanggalJam(value),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
