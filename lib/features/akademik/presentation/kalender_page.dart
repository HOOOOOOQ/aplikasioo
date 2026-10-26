import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

/// Kalender akademik & agenda sekolah.
///
/// Admin dapat menambah agenda; guru & siswa hanya membaca (RLS migration 006
/// membatasi `insert/update/delete` ke admin).
class KalenderPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;

  const KalenderPage({super.key, required this.audience});

  @override
  ConsumerState<KalenderPage> createState() => _KalenderPageState();
}

class _KalenderPageState extends ConsumerState<KalenderPage> {
  String? _filterTipe;
  bool _saving = false;

  Future<void> _refresh() async {
    ref.invalidate(kalenderProvider(widget.audience));
    await ref.read(kalenderProvider(widget.audience).future).catchError((_) => const <KalenderItem>[]);
  }

  Future<void> _openCreate() async {
    setState(() => _saving = true);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _KalenderForm(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == true) {
      ref.invalidate(kalenderProvider(widget.audience));
      akademikSnack(context, 'Agenda ditambahkan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kalenderProvider(widget.audience));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canWrite = widget.audience == AkademikAudience.staff && user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kalender Akademik')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agenda'),
            )
          : null,
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 4)],
        ),
        error: (e, _) => AkademikErrorView(
          error: e,
          onRetry: () async {
            ref.invalidate(kalenderProvider(widget.audience));
          },
        ),
        data: (items) {
          final filtered = _filterTipe == null
              ? items
              : items.where((i) => i.tipe == _filterTipe).toList();
          final grouped = <String, List<KalenderItem>>{};
          for (final item in filtered) {
            final key = DateFormat('MMMM yyyy', 'id_ID').format(item.tanggalMulai.toLocal());
            grouped.putIfAbsent(key, () => []).add(item);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _filterTipe == null,
                        onSelected: (_) => setState(() => _filterTipe = null),
                      ),
                      for (final t in const ['kegiatan', 'ujian', 'libur', 'rapat', 'lainnya'])
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: ChoiceChip(
                            avatar: Icon(kalenderIcon(t), size: 15, color: kalenderColor(t)),
                            label: Text(kalenderTipeLabel(t)),
                            selected: _filterTipe == t,
                            onSelected: (_) => setState(() => _filterTipe = t),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Belum ada agenda',
                      subtitle: canWrite
                          ? 'Tambahkan libur, ujian, atau kegiatan sekolah agar semua tahu jadwalnya.'
                          : 'Agenda dari sekolah akan tampil di sini.',
                      actionLabel: canWrite ? 'Tambah agenda' : null,
                      onAction: canWrite ? _openCreate : null,
                    ),
                  )
                else
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                      ),
                    ),
                    for (final item in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _KalenderCard(item: item),
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KalenderCard extends StatelessWidget {
  final KalenderItem item;

  const _KalenderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = kalenderColor(item.tipe);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('d', 'id_ID').format(item.tanggalMulai.toLocal()),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  DateFormat('MMM', 'id_ID').format(item.tanggalMulai.toLocal()),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(kalenderIcon(item.tipe), size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      kalenderTipeLabel(item.tipe),
                      style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
                    ),
                    if (item.isRange) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          's.d. ${formatTanggal(item.tanggalSelesai!)}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.deskripsi != null && item.deskripsi!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.deskripsi!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KalenderForm extends ConsumerStatefulWidget {
  const _KalenderForm();

  @override
  ConsumerState<_KalenderForm> createState() => _KalenderFormState();
}

class _KalenderFormState extends ConsumerState<_KalenderForm> {
  final _formKey = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _deskripsi = TextEditingController();
  DateTime _mulai = DateTime.now();
  DateTime? _selesai;
  String _tipe = 'kegiatan';
  bool _saving = false;

  @override
  void dispose() {
    _judul.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final initial = end ? (_selesai ?? _mulai) : _mulai;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: end ? 'Tanggal selesai' : 'Tanggal mulai',
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _selesai = picked;
      } else {
        _mulai = picked;
        if (_selesai != null && _selesai!.isBefore(picked)) _selesai = null;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(akademikRepositoryProvider).createKalender(
            judul: _judul.text,
            deskripsi: _deskripsi.text.isEmpty ? null : _deskripsi.text,
            tipe: _tipe,
            tanggalMulai: _mulai,
            tanggalSelesai: _selesai,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showAkademikErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Agenda baru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _judul,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Judul agenda'),
                validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Judul minimal 3 karakter.' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _deskripsi,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Keterangan (opsional)', alignLabelWithHint: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(kalenderIcon(_tipe), color: kalenderColor(_tipe)),
                title: const Text('Jenis agenda'),
                subtitle: Text(kalenderTipeLabel(_tipe)),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: _saving
                    ? null
                    : () async {
                        final picked = await pickKalenderTipe(context, current: _tipe);
                        if (picked != null) setState(() => _tipe = picked);
                      },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                title: const Text('Tanggal mulai'),
                subtitle: Text(formatTanggal(_mulai)),
                onTap: _saving ? null : () => _pickDate(end: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded, color: AppColors.primary),
                title: const Text('Tanggal selesai (opsional)'),
                subtitle: Text(_selesai == null ? 'Satu hari' : formatTanggal(_selesai!)),
                trailing: _selesai == null
                    ? null
                    : IconButton(
                        tooltip: 'Hapus tanggal selesai',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _saving ? null : () => setState(() => _selesai = null),
                      ),
                onTap: _saving ? null : () => _pickDate(end: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Menyimpan…' : 'Simpan agenda'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
