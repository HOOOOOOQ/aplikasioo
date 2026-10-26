import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/mata_pelajaran.dart';
import '../../../../shared/repositories/mapel_repository.dart';

class AdminSubjectsPage extends ConsumerStatefulWidget {
  const AdminSubjectsPage({super.key});

  @override
  ConsumerState<AdminSubjectsPage> createState() => _AdminSubjectsPageState();
}

class _AdminSubjectsPageState extends ConsumerState<AdminSubjectsPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<MataPelajaran>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = MapelRepository().fetchAll();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = MapelRepository().fetchAll());
    await _future;
  }

  Future<void> _showForm({MataPelajaran? existing}) async {
    final formKey = GlobalKey<FormState>();
    final namaC = TextEditingController(text: existing?.namaMapel ?? '');
    final deskC = TextEditingController(text: existing?.deskripsi ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah mata pelajaran' : 'Edit mata pelajaran'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: namaC,
                  decoration: const InputDecoration(labelText: 'Nama mata pelajaran'),
                  validator: (v) => Validators.nama(v, field: 'Nama mapel'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: deskC,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    final nama = namaC.text.trim();
    final deskripsi = deskC.text.trim();
    namaC.dispose();
    deskC.dispose();
    if (result != true) return;

    try {
      if (existing == null) {
        await MapelRepository().create(nama: nama, deskripsi: deskripsi.isEmpty ? null : deskripsi);
      } else {
        await MapelRepository().update(existing.id, {
          'nama_mapel': nama,
          'deskripsi': deskripsi.isEmpty ? null : deskripsi,
        });
      }
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? 'Mapel ditambahkan.' : 'Mapel diperbarui.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _delete(MataPelajaran mapel) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus ${mapel.namaMapel}?',
      content: 'Jadwal dan tugas yang memakai mata pelajaran ini juga akan terhapus.',
    );
    if (!confirmed) return;
    try {
      await MapelRepository().delete(mapel.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Mapel dihapus.');
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
        label: const Text('Tambah mapel'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MataPelajaran>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <MataPelajaran>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list.where((m) => m.namaMapel.toLowerCase().contains(needle)).toList();
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Kurikulum',
                  title: 'Mata Pelajaran',
                  subtitle: '${snapshot.data?.length ?? 0} mata pelajaran terdaftar.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari mata pelajaran…',
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Belum ada mata pelajaran',
                      subtitle: 'Mapel dipakai pada jadwal dan tugas.',
                      actionLabel: 'Tambah mapel',
                      onAction: () => _showForm(),
                    ),
                  )
                else
                  ...list.map((mapel) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.infoContainer,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.info),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mapel.namaMapel,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    Text(
                                      mapel.deskripsi?.isNotEmpty == true ? mapel.deskripsi! : 'Tanpa deskripsi',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showForm(existing: mapel);
                                  if (value == 'delete') _delete(mapel);
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
              ],
            );
          },
        ),
      ),
    );
  }
}
