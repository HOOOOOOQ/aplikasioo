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
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';

class AdminTasksPage extends ConsumerStatefulWidget {
  const AdminTasksPage({super.key});

  @override
  ConsumerState<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends ConsumerState<AdminTasksPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<Tugas>> _future;
  List<Kelas> _kelas = const [];
  String? _kelasFilter;
  String? _statusFilter;
  String _search = '';
  int _visible = 20;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadKelas();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadKelas() async {
    try {
      final list = await KelasRepository().fetchAll();
      if (mounted) setState(() => _kelas = list);
    } catch (_) {}
  }

  Future<List<Tugas>> _load() {
    return TugasRepository().fetchAll(
      kelasId: _kelasFilter,
      statusPublikasi: _statusFilter ?? '',
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _togglePublish(Tugas tugas) async {
    final next = tugas.statusPublikasi == 'published' ? 'draft' : 'published';
    try {
      await TugasRepository().update(tugas.id, {'status_publikasi': next});
      if (!mounted) return;
      showAppSnackBar(context, next == 'published' ? 'Tugas diterbitkan.' : 'Tugas dijadikan draft.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _delete(Tugas tugas) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus tugas?',
      content: '"${tugas.judul}" beserta status pengerjaan siswa akan terhapus. '
          'Lampiran tidak otomatis terhapus dari Storage.',
    );
    if (!confirmed) return;
    try {
      await TugasRepository().delete(tugas.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Tugas dihapus.');
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Tugas>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <Tugas>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list
                  .where((t) =>
                      t.judul.toLowerCase().contains(needle) ||
                      (t.kelasNama?.toLowerCase().contains(needle) ?? false) ||
                      (t.guruNama?.toLowerCase().contains(needle) ?? false))
                  .toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Tugas & lampiran',
                  title: 'Manajemen Tugas',
                  subtitle: '${snapshot.data?.length ?? 0} tugas dari seluruh guru.',
                  footer: Wrap(
                    spacing: AppSpacing.lg,
                    children: [
                      _stat('Terbit', '${(snapshot.data ?? const []).where((t) => t.isPublished).length}'),
                      _stat('Draft', '${(snapshot.data ?? const []).where((t) => t.statusPublikasi == 'draft').length}'),
                      _stat('Berlampiran', '${(snapshot.data ?? const []).where((t) => t.hasLampiran).length}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari judul, kelas, atau guru…',
                  onChanged: (value) => setState(() {
                        _search = value;
                        _visible = _pageSize;
                      }),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _statusFilter == null,
                        onSelected: (_) {
                          setState(() => _statusFilter = null);
                          _refresh();
                        },
                      ),
                      for (final status in ['published', 'draft', 'archived']) ...[
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(status == 'published' ? 'Terbit' : status == 'draft' ? 'Draft' : 'Arsip'),
                          selected: _statusFilter == status,
                          onSelected: (selected) {
                            setState(() => _statusFilter = selected ? status : null);
                            _refresh();
                          },
                        ),
                      ],
                      const SizedBox(width: AppSpacing.md),
                      if (_kelas.isNotEmpty)
                        DropdownButton<String?>(
                          value: _kelasFilter,
                          hint: const Text('Semua kelas', style: TextStyle(fontSize: 12)),
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Semua kelas')),
                            ..._kelas.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))),
                          ],
                          onChanged: (value) {
                            setState(() => _kelasFilter = value);
                            _refresh();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  const AppCard(
                    child: AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Belum ada tugas',
                      subtitle: 'Tugas yang dibuat guru akan muncul di sini.',
                    ),
                  )
                else
                  ...list.take(_visible).map((tugas) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: () => context.push('/admin/tugas/${tugas.id}'),
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
                                      if (value == 'detail') context.push('/admin/tugas/${tugas.id}');
                                      if (value == 'publish') _togglePublish(tugas);
                                      if (value == 'delete') _delete(tugas);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'detail', child: Text('Lihat detail')),
                                      PopupMenuItem(
                                        value: 'publish',
                                        child: Text(tugas.isPublished ? 'Jadikan draft' : 'Terbitkan'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Hapus', style: TextStyle(color: AppColors.error)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tugas.kelasNama ?? '-'} • ${tugas.mataPelajaranNama ?? '-'} • Guru: ${tugas.guruNama ?? '-'}',
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
                                    label: AppDateUtils.formatTanggalJam(tugas.tenggatWaktu),
                                    icon: Icons.event_outlined,
                                  ),
                                  if (tugas.hasLampiran)
                                    const MetaPill(label: 'Lampiran', icon: Icons.attach_file_rounded),
                                  MetaPill(
                                    label: tugas.statusPublikasi == 'published'
                                        ? 'Terbit'
                                        : tugas.statusPublikasi == 'draft'
                                            ? 'Draft'
                                            : 'Arsip',
                                    icon: Icons.visibility_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                if (list.length > _visible)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _visible += _pageSize),
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text('Muat lebih banyak (${list.length - _visible} lagi)'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}
