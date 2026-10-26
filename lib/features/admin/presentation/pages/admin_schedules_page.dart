import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/mata_pelajaran.dart';
import '../../../../shared/repositories/akun_repository.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/mapel_repository.dart';

class AdminSchedulesPage extends ConsumerStatefulWidget {
  const AdminSchedulesPage({super.key});

  @override
  ConsumerState<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends ConsumerState<AdminSchedulesPage> {
  late Future<List<Jadwal>> _future;
  List<Kelas> _kelas = const [];
  String? _filterKelas;
  String? _filterHari;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    try {
      final list = await KelasRepository().fetchAll();
      if (mounted) setState(() => _kelas = list);
    } catch (_) {}
  }

  Future<List<Jadwal>> _load() => JadwalRepository().fetchAll(kelasId: _filterKelas, hari: _filterHari);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  TimeOfDay _parseTime(String value, {TimeOfDay fallback = const TimeOfDay(hour: 7, minute: 0)}) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _showForm({Jadwal? existing}) async {
    final resultados = await Future.wait([
      KelasRepository().fetchAll(),
      MapelRepository().fetchAll(),
      ref.read(akunRepositoryProvider).fetchProfiles(role: 'guru'),
    ]);
    if (!mounted) return;

    final kelasList = resultados[0] as List<Kelas>;
    final mapelList = resultados[1] as List<MataPelajaran>;
    final gurus = resultados[2] as List<ProfileRow>;

    if (kelasList.isEmpty || mapelList.isEmpty || gurus.isEmpty) {
      showAppSnackBar(context, 'Lengkapi kelas, mata pelajaran, dan akun guru terlebih dahulu.', isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    var kelasId = existing?.kelasId ?? kelasList.first.id;
    var mapelId = existing?.mataPelajaranId ?? mapelList.first.id;
    var guruId = existing?.guruId ?? gurus.first.id;
    var hari = existing?.hari ?? 'Senin';
    var mulai = _parseTime(existing?.jamMulai ?? '07:00:00');
    var selesai = _parseTime(existing?.jamSelesai ?? '08:30:00');
    final ruangC = TextEditingController(text: existing?.ruang ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah jadwal' : 'Edit jadwal'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: kelasId,
                      decoration: const InputDecoration(labelText: 'Kelas'),
                      items: kelasList.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(),
                      onChanged: (v) => setDialogState(() => kelasId = v!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: mapelId,
                      decoration: const InputDecoration(labelText: 'Mata pelajaran'),
                      items: mapelList.map((m) => DropdownMenuItem(value: m.id, child: Text(m.namaMapel))).toList(),
                      onChanged: (v) => setDialogState(() => mapelId = v!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: guruId,
                      decoration: const InputDecoration(labelText: 'Guru pengampu'),
                      items: gurus.map((g) => DropdownMenuItem(value: g.id, child: Text(g.fullName))).toList(),
                      onChanged: (v) => setDialogState(() => guruId = v!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: hari,
                      decoration: const InputDecoration(labelText: 'Hari'),
                      items: AppDateUtils.daftarHari
                          .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => hari = v!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(context: ctx, initialTime: mulai);
                              if (picked != null) setDialogState(() => mulai = picked);
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 17),
                            label: Text('Mulai ${mulai.format(ctx)}'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(context: ctx, initialTime: selesai);
                              if (picked != null) setDialogState(() => selesai = picked);
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 17),
                            label: Text('Selesai ${selesai.format(ctx)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: ruangC,
                      decoration: const InputDecoration(labelText: 'Ruang (opsional)', hintText: 'Mis. Lab 2'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppNotice.info(
                      text: 'Server menolak jadwal yang bentrok untuk kelas atau guru yang sama '
                          'pada hari dan jam yang sama.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final minutesA = mulai.hour * 60 + mulai.minute;
                final minutesB = selesai.hour * 60 + selesai.minute;
                if (minutesB <= minutesA) {
                  showAppSnackBar(ctx, 'Jam selesai harus setelah jam mulai.', isError: true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    final ruang = ruangC.text.trim();
    ruangC.dispose();
    if (saved != true) return;

    final payload = {
      'kelas_id': kelasId,
      'mata_pelajaran_id': mapelId,
      'guru_id': guruId,
      'hari': hari,
      'jam_mulai': _formatTime(mulai),
      'jam_selesai': _formatTime(selesai),
      'ruang': ruang.isEmpty ? null : ruang,
    };

    try {
      if (existing == null) {
        await JadwalRepository().create(payload);
      } else {
        await JadwalRepository().update(existing.id, payload);
      }
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? 'Jadwal ditambahkan.' : 'Jadwal diperbarui.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _delete(Jadwal jadwal) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus jadwal?',
      content: '${jadwal.mataPelajaranNama ?? '-'} • ${jadwal.hari} '
          '${AppDateUtils.formatJamFromString(jadwal.jamMulai)}–${AppDateUtils.formatJamFromString(jadwal.jamSelesai)}',
    );
    if (!confirmed) return;
    try {
      await JadwalRepository().delete(jadwal.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Jadwal dihapus.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah jadwal'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Jadwal>>(
          future: _future,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <Jadwal>[];
            final grouped = <String, List<Jadwal>>{};
            for (final item in list) {
              grouped.putIfAbsent(item.hari, () => []).add(item);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Jadwal sekolah',
                  title: 'Jadwal Pelajaran',
                  subtitle: '${list.length} slot jadwal • anti-bentrok otomatis di server.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterKelas,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Kelas', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Semua kelas')),
                          ..._kelas.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))),
                        ],
                        onChanged: (value) {
                          setState(() => _filterKelas = value);
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterHari,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Hari', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Semua hari')),
                          ...AppDateUtils.daftarHari.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                        ],
                        onChanged: (value) {
                          setState(() => _filterHari = value);
                          _refresh();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'Belum ada jadwal',
                      subtitle: 'Tambahkan jadwal agar guru dan siswa melihat pelajaran harian.',
                      actionLabel: 'Tambah jadwal',
                      onAction: () => _showForm(),
                    ),
                  )
                else
                  ...grouped.entries.map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: entry.key, subtitle: '${entry.value.length} pelajaran'),
                          ...entry.value.map((jadwal) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Column(
                                        children: [
                                          Text(
                                            AppDateUtils.formatJamFromString(jadwal.jamMulai),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                          ),
                                          Text(
                                            AppDateUtils.formatJamFromString(jadwal.jamSelesai),
                                            style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 3,
                                        height: 42,
                                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              jadwal.mataPelajaranNama ?? '-',
                                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              '${jadwal.kelasNama ?? '-'} • ${jadwal.guruNama ?? '-'}'
                                              '${jadwal.ruang != null && jadwal.ruang!.isNotEmpty ? ' • ${jadwal.ruang}' : ''}',
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') _showForm(existing: jadwal);
                                          if (value == 'delete') _delete(jadwal);
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Hapus', style: TextStyle(color: AppColors.error)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
