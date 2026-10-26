import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../shared/models/kelas.dart';
import '../../../shared/models/siswa.dart';
import '../../../shared/repositories/jadwal_repository.dart';
import '../../../shared/repositories/kelas_repository.dart';
import '../../../shared/repositories/siswa_repository.dart';
import '../../../shared/services/supabase_service.dart';
import '../data/access_code_repository.dart';
import '../domain/access_code.dart';

class AccessCodesPage extends ConsumerStatefulWidget {
  /// Guru hanya boleh menerbitkan kode untuk kelas yang ditanganinya.
  final bool isTeacher;

  const AccessCodesPage({super.key, this.isTeacher = false});

  @override
  ConsumerState<AccessCodesPage> createState() => _AccessCodesPageState();
}

class _AccessCodesPageState extends ConsumerState<AccessCodesPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<AccessCode>> _future;
  AccessCodeStatus? _statusFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AccessCode>> _load() {
    return ref.read(accessCodeRepositoryProvider).fetchCodes();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<List<Kelas>> _allowedKelas() async {
    final kelas = await KelasRepository().fetchAll();
    if (!widget.isTeacher) return kelas;

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    final jadwal = await JadwalRepository().fetchByGuru(uid);
    final handled = <String>{
      for (final j in jadwal) j.kelasId,
    };
    return kelas
        .where((k) => handled.contains(k.id) || k.waliKelasId == uid)
        .toList();
  }

  Future<void> _openIssueSheet() async {
    List<Kelas> kelasList;
    try {
      kelasList = await _allowedKelas();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
      return;
    }

    if (!mounted) return;
    if (kelasList.isEmpty) {
      showAppSnackBar(
        context,
        widget.isTeacher
            ? 'Anda belum ditugaskan pada kelas mana pun. Hubungi admin.'
            : 'Belum ada kelas. Tambahkan kelas terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final issued = await showModalBottomSheet<IssuedAccessCode>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IssueCodeSheet(kelasList: kelasList, isTeacher: widget.isTeacher),
    );

    if (issued == null) return;
    await _refresh();
    if (!mounted) return;
    await _showIssuedDialog(issued);
  }

  Future<void> _showIssuedDialog(IssuedAccessCode issued) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.key_rounded, size: 30, color: AppColors.success),
        title: const Text('Kode berhasil dibuat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Berikan kode ini kepada siswa. Kode hanya ditampilkan sekali dan tidak dapat dilihat lagi setelah dialog ini ditutup.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: SelectableText(
                issued.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            if (issued.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Berlaku sampai ${AppDateUtils.formatTanggalJam(issued.expiresAt)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issued.code));
              if (!dialogContext.mounted || !context.mounted) return;
              Navigator.pop(dialogContext);
              showAppSnackBar(context, 'Kode disalin ke clipboard.');
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Salin kode'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(AccessCode code) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cabut kode ${code.prefix}?',
      content: 'Kode yang dicabut tidak dapat dipakai lagi. Siswa yang sudah terhubung '
          'tidak kehilangan identitasnya.',
      confirmLabel: 'Cabut kode',
    );
    if (!confirmed) return;

    try {
      await ref.read(accessCodeRepositoryProvider).revoke(code.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Kode berhasil dicabut.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openIssueSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Terbitkan kode'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AccessCode>>(
          future: _future,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <AccessCode>[];

            var filtered = all;
            if (_statusFilter != null) {
              filtered = filtered.where((c) => c.status == _statusFilter).toList();
            }
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              filtered = filtered
                  .where((c) =>
                      c.prefix.toLowerCase().contains(needle) ||
                      (c.kelasNama?.toLowerCase().contains(needle) ?? false) ||
                      (c.siswaNama?.toLowerCase().contains(needle) ?? false) ||
                      (c.usedByNama?.toLowerCase().contains(needle) ?? false))
                  .toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: widget.isTeacher ? 'Guru' : 'Administrator',
                  title: 'Kode Akses Siswa',
                  subtitle: widget.isTeacher
                      ? 'Terbitkan kode untuk kelas yang Anda ampu.'
                      : 'Kelola kode untuk menghubungkan identitas siswa.',
                  footer: Row(
                    children: [
                      _heroStat('Total', '${all.length}'),
                      const SizedBox(width: AppSpacing.lg),
                      _heroStat('Aktif', '${all.where((c) => c.isActive).length}'),
                      const SizedBox(width: AppSpacing.lg),
                      _heroStat('Dipakai', '${all.where((c) => c.status == AccessCodeStatus.used).length}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppNotice.info(
                  title: 'Kode dibuat di server',
                  text: 'Kode diacak dengan CSPRNG dan disimpan sebagai hash. Kode lengkap hanya '
                      'ditampilkan sekali saat dibuat. Verifikasi dilakukan server, sehingga kode '
                      'tidak bisa dipalsukan dari aplikasi.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari kode, kelas, atau nama siswa…',
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusChip('Semua', null),
                      for (final status in AccessCodeStatus.values) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _statusChip(status.label, status),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (filtered.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.key_off_rounded,
                      title: all.isEmpty ? 'Belum ada kode akses' : 'Tidak ada kode yang cocok',
                      subtitle: all.isEmpty
                          ? 'Terbitkan kode agar siswa dapat menghubungkan identitas dan mengirim status tugas resmi.'
                          : 'Ubah filter status atau kata pencarian.',
                      actionLabel: all.isEmpty ? 'Terbitkan kode' : null,
                      onAction: all.isEmpty ? _openIssueSheet : null,
                    ),
                  )
                else
                  ...filtered.map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _AccessCodeCard(
                          code: code,
                          onRevoke: code.isActive ? () => _revoke(code) : null,
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _statusChip(String label, AccessCodeStatus? status) {
    final selected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = selected ? null : status),
    );
  }
}

class _AccessCodeCard extends StatelessWidget {
  final AccessCode code;
  final VoidCallback? onRevoke;

  const _AccessCodeCard({required this.code, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final status = code.status;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(status.icon, size: 20, color: status.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${code.prefix}•••',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _pill(status.label, status.color),
                        if (code.isSingleUse) ...[
                          const SizedBox(width: 4),
                          _pill('Sekali pakai', AppColors.textSecondary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Untuk ${code.targetLabel} • Kelas ${code.kelasNama ?? '-'}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (onRevoke != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'revoke') onRevoke!();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'revoke',
                      child: Text('Cabut kode', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _meta(Icons.event_outlined, 'Dibuat ${dateFormat.format(code.createdAt)}'),
              if (code.expiresAt != null)
                _meta(
                  Icons.timer_outlined,
                  'Berlaku s/d ${dateFormat.format(code.expiresAt!)}',
                )
              else
                _meta(Icons.all_inclusive_rounded, 'Tanpa masa berlaku'),
              if (code.usedAt != null)
                _meta(
                  Icons.task_alt_rounded,
                  'Dipakai ${code.usedByNama ?? 'siswa'} • ${dateFormat.format(code.usedAt!)}',
                ),
              if (code.createdByNama != null) _meta(Icons.person_outline_rounded, code.createdByNama!),
            ],
          ),
          if (code.note != null && code.note!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              code.note!,
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}

/// Form penerbitan kode di dalam bottom sheet.
class _IssueCodeSheet extends ConsumerStatefulWidget {
  final List<Kelas> kelasList;
  final bool isTeacher;

  const _IssueCodeSheet({required this.kelasList, required this.isTeacher});

  @override
  ConsumerState<_IssueCodeSheet> createState() => _IssueCodeSheetState();
}

class _IssueCodeSheetState extends ConsumerState<_IssueCodeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteC = TextEditingController();

  late String _kelasId;
  bool _forSingleStudent = true;
  String? _siswaId;
  bool _singleUse = true;
  int? _expiresInDays = 30;

  List<Siswa> _roster = const [];
  bool _loadingRoster = false;
  bool _submitting = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _kelasId = widget.kelasList.first.id;
    _loadRoster();
  }

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _loadingRoster = true;
      _siswaId = null;
      _roster = const [];
    });
    try {
      final roster = await SiswaRepository().fetchByKelas(_kelasId);
      if (!mounted) return;
      setState(() => _roster = roster);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppError.from(e));
    } finally {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_forSingleStudent && _siswaId == null) {
      setState(() => _error = const AppError(
            title: 'Pilih siswa',
            message: 'Tentukan siswa yang akan memakai kode ini.',
            code: 'missing_siswa',
          ));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final issued = await ref.read(accessCodeRepositoryProvider).issue(
            kelasId: _kelasId,
            siswaId: _forSingleStudent ? _siswaId : null,
            singleUse: _singleUse,
            expiresInDays: _expiresInDays,
            note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, issued);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppError.from(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Terbitkan kode akses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Kode dibuat acak oleh server dan hanya ditampilkan sekali.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                value: _kelasId,
                decoration: const InputDecoration(
                  labelText: 'Kelas',
                  prefixIcon: Icon(Icons.class_outlined, size: 20),
                ),
                items: widget.kelasList
                    .map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _kelasId = value);
                        _loadRoster();
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Satu siswa'), icon: Icon(Icons.person_rounded, size: 16)),
                  ButtonSegment(value: false, label: Text('Satu kelas'), icon: Icon(Icons.groups_rounded, size: 16)),
                ],
                selected: {_forSingleStudent},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => setState(() => _forSingleStudent = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_forSingleStudent)
                _loadingRoster
                    ? const AppLoading(message: 'Memuat siswa…', compact: true)
                    : _roster.isEmpty
                        ? const AppNotice.warning(
                            text: 'Belum ada siswa aktif di kelas ini. Tambahkan siswa atau pakai kode kelas.',
                          )
                        : DropdownButtonFormField<String>(
                            value: _siswaId,
                            decoration: const InputDecoration(
                              labelText: 'Siswa',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            ),
                            items: _roster
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.nama} • ${s.nomorInduk}'),
                                    ))
                                .toList(),
                            onChanged: _submitting ? null : (value) => setState(() => _siswaId = value),
                            validator: (value) =>
                                _forSingleStudent && value == null ? 'Pilih siswa' : null,
                          )
              else
                const AppNotice.warning(
                  text: 'Kode kelas dapat dipakai beberapa siswa. Siswa memilih namanya sendiri '
                      'saat verifikasi, dan server memastikan siswa benar-benar di kelas ini.',
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int?>(
                value: _expiresInDays,
                decoration: const InputDecoration(
                  labelText: 'Masa berlaku',
                  prefixIcon: Icon(Icons.timer_outlined, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 hari')),
                  DropdownMenuItem(value: 30, child: Text('30 hari')),
                  DropdownMenuItem(value: 90, child: Text('90 hari')),
                  DropdownMenuItem(value: null, child: Text('Tanpa masa berlaku')),
                ],
                onChanged: _submitting ? null : (value) => setState(() => _expiresInDays = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _singleUse,
                onChanged: _submitting ? null : (value) => setState(() => _singleUse = value),
                title: const Text('Sekali pakai', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Kode otomatis tidak berlaku setelah dipakai satu siswa.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _noteC,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Mis. kode untuk siswa pindahan',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppNotice.error(
                  title: _error!.title,
                  text: _error!.hint == null ? _error!.message : '${_error!.message} ${_error!.hint}',
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.key_rounded, size: 18),
                  label: Text(_submitting ? 'Membuat kode…' : 'Buat kode'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.isTeacher
                    ? 'Sebagai guru, Anda hanya dapat menerbitkan kode untuk kelas yang Anda ampu.'
                    : 'Admin dapat menerbitkan kode untuk seluruh kelas.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
