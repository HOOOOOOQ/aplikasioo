import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/repositories/akun_repository.dart';
import '../../../../shared/repositories/kelas_repository.dart';

class AdminClassesPage extends ConsumerStatefulWidget {
  const AdminClassesPage({super.key});

  @override
  ConsumerState<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends ConsumerState<AdminClassesPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<Kelas>> _future;
  Map<String, int> _jumlahSiswa = const {};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<List<Kelas>> _load() async {
    final repo = KelasRepository();
    final results = await Future.wait([repo.fetchAll(), repo.countSiswaPerKelas()]);
    _jumlahSiswa = results[1] as Map<String, int>;
    return results[0] as List<Kelas>;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showForm({Kelas? existing}) async {
    List<ProfileRow> gurus;
    try {
      gurus = await ref.read(akunRepositoryProvider).fetchProfiles(role: 'guru');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
      return;
    }
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final namaC = TextEditingController(text: existing?.namaKelas ?? '');
    final tingkatC = TextEditingController(text: existing?.tingkat ?? '');
    final tahunC = TextEditingController(text: existing?.tahunAjaran ?? '');
    var waliId = existing?.waliKelasId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah kelas' : 'Edit kelas'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: namaC,
                      decoration: const InputDecoration(labelText: 'Nama kelas', hintText: 'Mis. X PPLG 1'),
                      validator: (v) => Validators.nama(v, field: 'Nama kelas'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tingkatC,
                            decoration: const InputDecoration(labelText: 'Tingkat', hintText: 'X / XI / XII'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: tahunC,
                            decoration: const InputDecoration(labelText: 'Tahun ajaran', hintText: '2026/2027'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: waliId,
                      decoration: const InputDecoration(labelText: 'Wali kelas (opsional)'),
                      items: gurus
                          .map((g) => DropdownMenuItem(value: g.id, child: Text(g.fullName)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => waliId = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, {
                  'nama_kelas': namaC.text.trim(),
                  'tingkat': tingkatC.text.trim().isEmpty ? null : tingkatC.text.trim(),
                  'tahun_ajaran': tahunC.text.trim().isEmpty ? null : tahunC.text.trim(),
                  'wali_kelas_id': waliId,
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    namaC.dispose();
    tingkatC.dispose();
    tahunC.dispose();
    if (result == null) return;

    try {
      if (existing == null) {
        await KelasRepository().create(
          namaKelas: result['nama_kelas'] as String,
          tingkat: result['tingkat'] as String?,
          tahunAjaran: result['tahun_ajaran'] as String?,
          waliKelasId: result['wali_kelas_id'] as String?,
        );
      } else {
        await KelasRepository().update(existing.id, result);
      }
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? 'Kelas ditambahkan.' : 'Kelas diperbarui.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _delete(Kelas kelas) async {
    final jumlah = _jumlahSiswa[kelas.id] ?? 0;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus ${kelas.namaKelas}?',
      content: jumlah > 0
          ? 'Kelas ini memiliki $jumlah siswa. Siswa akan kehilangan kelas dan tugas '
              'terkait kelas ini juga terhapus. Tindakan ini tidak bisa dibatalkan.'
          : 'Jadwal dan tugas terkait kelas ini juga akan terhapus.',
    );
    if (!confirmed) return;
    try {
      await KelasRepository().delete(kelas.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Kelas dihapus.');
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
        label: const Text('Tambah kelas'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Kelas>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <Kelas>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list.where((k) => k.namaKelas.toLowerCase().contains(needle)).toList();
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Struktur sekolah',
                  title: 'Manajemen Kelas',
                  subtitle: '${snapshot.data?.length ?? 0} kelas terdaftar.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari kelas…',
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
                      icon: Icons.class_outlined,
                      title: 'Belum ada kelas',
                      subtitle: 'Kelas diperlukan untuk siswa, jadwal, dan tugas.',
                      actionLabel: 'Tambah kelas',
                      onAction: () => _showForm(),
                    ),
                  )
                else
                  ...list.map((kelas) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: const Icon(Icons.class_rounded, size: 20, color: AppColors.primary),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(kelas.namaKelas,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_jumlahSiswa[kelas.id] ?? 0} siswa • Wali: ${kelas.waliKelasNama ?? '-'}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                    if (kelas.tingkat != null || kelas.tahunAjaran != null)
                                      Text(
                                        '${kelas.tingkat ?? '-'} • ${kelas.tahunAjaran ?? '-'}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showForm(existing: kelas);
                                  if (value == 'delete') _delete(kelas);
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
