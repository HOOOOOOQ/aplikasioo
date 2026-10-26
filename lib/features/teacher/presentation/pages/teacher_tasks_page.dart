import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/services/supabase_service.dart';

final teacherTasksProvider = FutureProvider.autoDispose<List<Tugas>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const [];
  final list = await TugasRepository().fetchAll(guruId: uid, statusPublikasi: '');
  // Tugas yang diarsipkan (soft delete) tidak ditampilkan lagi di daftar aktif.
  return list.where((t) => t.statusPublikasi != 'archived').toList();
});

class TeacherTasksPage extends ConsumerStatefulWidget {
  const TeacherTasksPage({super.key});

  @override
  ConsumerState<TeacherTasksPage> createState() => _TeacherTasksPageState();
}

class _TeacherTasksPageState extends ConsumerState<TeacherTasksPage> {
  final TextEditingController _searchC = TextEditingController();
  String _search = '';
  String? _filter;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  /// Guru melakukan soft delete: tugas diarsipkan agar status siswa & lampiran
  /// tidak hilang. Penghapusan permanen hanya dilakukan admin.
  Future<void> _archive(Tugas tugas) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Arsipkan tugas?',
      content: '"${tugas.judul}" tidak akan tampil lagi untuk siswa. '
          'Data dan status pengerjaan tetap tersimpan.',
      confirmLabel: 'Arsipkan',
      isDestructive: false,
    );
    if (!confirmed) return;
    try {
      await TugasRepository().update(tugas.id, {'status_publikasi': 'archived'});
      if (!mounted) return;
      showAppSnackBar(context, 'Tugas diarsipkan.');
      ref.invalidate(teacherTasksProvider);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _togglePublish(Tugas tugas) async {
    final next = tugas.isPublished ? 'draft' : 'published';
    try {
      await TugasRepository().update(tugas.id, {'status_publikasi': next});
      if (!mounted) return;
      showAppSnackBar(context, next == 'published' ? 'Tugas diterbitkan.' : 'Tugas dijadikan draft.');
      ref.invalidate(teacherTasksProvider);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teacherTasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/guru/tugas/tambah'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherTasksProvider),
        child: async.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              SizedBox(height: AppSpacing.xxl),
              AppSkeletonList(count: 4),
            ],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xxl),
              AppErrorState(error: e, onRetry: () => ref.invalidate(teacherTasksProvider)),
            ],
          ),
          data: (all) {
            var list = all;
            if (_filter != null) {
              list = list.where((t) => t.statusPublikasi == _filter).toList();
            }
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list
                  .where((t) =>
                      t.judul.toLowerCase().contains(needle) ||
                      (t.kelasNama?.toLowerCase().contains(needle) ?? false))
                  .toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Tugas saya',
                  title: 'Kelola Tugas',
                  subtitle: '${all.where((t) => t.isPublished).length} terbit • '
                      '${all.where((t) => t.statusPublikasi == 'draft').length} draft',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari judul tugas atau kelas…',
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: const Text('Terbit'),
                      selected: _filter == 'published',
                      onSelected: (selected) => setState(() => _filter = selected ? 'published' : null),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: const Text('Draft'),
                      selected: _filter == 'draft',
                      onSelected: (selected) => setState(() => _filter = selected ? 'draft' : null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (all.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Belum ada tugas',
                      subtitle: 'Buat tugas pertama untuk kelas yang Anda ampu.',
                      actionLabel: 'Buat tugas',
                      onAction: () => context.go('/guru/tugas/tambah'),
                    ),
                  )
                else if (list.isEmpty)
                  const AppCard(
                    child: AppEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Tidak ada tugas yang cocok',
                      subtitle: 'Ubah filter atau kata pencarian.',
                    ),
                  )
                else
                  ...list.map((tugas) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: () => context.push('/guru/tugas/${tugas.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tugas.judul,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') context.push('/guru/tugas/${tugas.id}/edit');
                                      if (value == 'status') context.push('/guru/tugas/${tugas.id}/status');
                                      if (value == 'publish') _togglePublish(tugas);
                                      if (value == 'archive') _archive(tugas);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit tugas')),
                                      const PopupMenuItem(value: 'status', child: Text('Status siswa')),
                                      PopupMenuItem(
                                        value: 'publish',
                                        child: Text(tugas.isPublished ? 'Jadikan draft' : 'Terbitkan'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'archive',
                                        child: Text('Arsipkan tugas'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                '${tugas.kelasNama ?? '-'} • ${tugas.mataPelajaranNama ?? '-'}',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  StatusChip(
                                    status: DeadlineHelper.getStatus(
                                      deadline: tugas.tenggatWaktu,
                                      isCompleted: false,
                                    ),
                                  ),
                                  MetaPill(
                                    label: AppDateUtils.formatTanggal(tugas.tenggatWaktu),
                                    icon: Icons.event_outlined,
                                  ),
                                  if (tugas.hasLampiran)
                                    const MetaPill(label: 'Lampiran', icon: Icons.attach_file_rounded),
                                  MetaPill(
                                    label: tugas.isPublished ? 'Terbit' : 'Draft',
                                    icon: tugas.isPublished
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
