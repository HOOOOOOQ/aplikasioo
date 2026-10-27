import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/deadline_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/tugas.dart';
import '../../../shared/repositories/tugas_repository.dart';
import '../../student/identity/student_identity_provider.dart';
import 'akademik_widgets.dart';

/// Kalender tenggat tugas: daftar tugas dikelompokkan per tanggal.
///
/// Berbeda dari `KalenderPage` (agenda sekolah), halaman ini khusus tenggat
/// tugas dari kelas siswa, dengan penanda lewat tenggat / hari ini / mendatang.
final _tenggatProvider = FutureProvider.autoDispose<List<Tugas>>((ref) async {
  if (SupabaseConfig.isNotConfigured) return const [];
  final identity = ref.watch(studentIdentityProvider);
  final kelasId = identity.kelasId;
  if (kelasId == null || kelasId.isEmpty) return const [];
  return TugasRepository().fetchAll(kelasId: kelasId, siswaId: identity.siswaId);
});

class TenggatPage extends ConsumerStatefulWidget {
  const TenggatPage({super.key});

  @override
  ConsumerState<TenggatPage> createState() => _TenggatPageState();
}

class _TenggatPageState extends ConsumerState<TenggatPage> {
  /// 0 = semua, 7 = 7 hari ke depan, 30 = 30 hari ke depan.
  int _range = 30;
  bool _hideDone = true;

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final async = ref.watch(_tenggatProvider);
    final local = ref.watch(localTaskStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kalender Tenggat')),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 5)],
        ),
        error: (e, _) => AkademikErrorView(
          error: e,
          onRetry: () async => ref.invalidate(_tenggatProvider),
        ),
        data: (all) {
          final now = DateTime.now();
          final until = _range == 0 ? null : now.add(Duration(days: _range));

          final items = all.where((t) {
            final done = t.statusSiswa == 'selesai' || local[t.id] == 'selesai';
            if (_hideDone && done) return false;
            if (until != null && t.tenggatWaktu.isAfter(until)) return false;
            return true;
          }).toList()
            ..sort((a, b) => a.tenggatWaktu.compareTo(b.tenggatWaktu));

          final grouped = <String, List<Tugas>>{};
          for (final t in items) {
            final key = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(t.tenggatWaktu.toLocal());
            grouped.putIfAbsent(key, () => []).add(t);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_tenggatProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('7 hari'),
                      selected: _range == 7,
                      onSelected: (_) => setState(() => _range = 7),
                    ),
                    ChoiceChip(
                      label: const Text('30 hari'),
                      selected: _range == 30,
                      onSelected: (_) => setState(() => _range = 30),
                    ),
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _range == 0,
                      onSelected: (_) => setState(() => _range = 0),
                    ),
                    FilterChip(
                      label: const Text('Sembunyikan selesai'),
                      selected: _hideDone,
                      onSelected: (v) => setState(() => _hideDone = v),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!identity.isIdentified)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppNotice.info(
                      title: 'Mode tanpa verifikasi',
                      text: 'Status selesai hanya tersimpan di perangkat ini. Hubungkan kode akses '
                          'agar status dan nilai tercatat resmi di server.',
                    ),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'Tidak ada tenggat',
                      subtitle: _range == 0
                          ? 'Belum ada tugas untuk kelas Anda.'
                          : 'Tidak ada tugas yang jatuh tempo dalam $_range hari ke depan.',
                      actionLabel: 'Tampilkan semua',
                      onAction: () => setState(() {
                        _range = 0;
                        _hideDone = false;
                      }),
                    ),
                  )
                else
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                      ),
                    ),
                    for (final tugas in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _TenggatCard(tugas: tugas, done: tugas.statusSiswa == 'selesai' || local[tugas.id] == 'selesai'),
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

class _TenggatCard extends StatelessWidget {
  final Tugas tugas;
  final bool done;

  const _TenggatCard({required this.tugas, required this.done});

  @override
  Widget build(BuildContext context) {
    final status = DeadlineHelper.getStatus(deadline: tugas.tenggatWaktu, isCompleted: done);
    return AppCard(
      onTap: () => context.push('/siswa/tugas/${tugas.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(tugas.tenggatWaktu.toLocal()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tugas.judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tugas.mataPelajaranNama ?? 'Mata pelajaran'} • ${DeadlineHelper.labelForStatus(status)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: DeadlineHelper.colorForStatus(status)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
