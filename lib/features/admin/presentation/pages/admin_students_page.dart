import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/siswa.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/siswa_repository.dart';

class AdminStudentsPage extends ConsumerStatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  ConsumerState<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends ConsumerState<AdminStudentsPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<Siswa>> _future;
  List<Kelas> _kelas = const [];
  String? _kelasFilter;
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

  Future<List<Siswa>> _load() {
    return SiswaRepository().fetchAll(kelasId: _kelasFilter);
  }

  Future<void> _loadKelas() async {
    try {
      final kelas = await KelasRepository().fetchAll();
      if (!mounted) return;
      setState(() => _kelas = kelas);
    } catch (_) {
      // daftar kelas hanya untuk filter; jangan blokir halaman
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showForm({Siswa? existing}) async {
    if (_kelas.isEmpty) {
      showAppSnackBar(context, 'Tambahkan kelas terlebih dahulu.', isError: true);
      return;
    }

    final nomorC = TextEditingController(text: existing?.nomorInduk ?? '');
    final namaC = TextEditingController(text: existing?.nama ?? '');
    var kelasId = existing?.kelasId;
    var aktif = existing?.statusAktif ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah siswa' : 'Edit siswa'),
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
                      decoration: const InputDecoration(labelText: 'Nama lengkap'),
                      validator: (v) => Validators.nama(v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: nomorC,
                      decoration: const InputDecoration(
                        labelText: 'Nomor induk / NIS',
                        hintText: 'Mis. 2024001',
                      ),
                      validator: Validators.nomorInduk,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: kelasId,
                      decoration: const InputDecoration(labelText: 'Kelas'),
                      items: _kelas
                          .map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => kelasId = v),
                      validator: (v) => v == null ? 'Kelas wajib dipilih' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: aktif,
                      onChanged: (v) => setDialogState(() => aktif = v),
                      title: const Text('Siswa aktif', style: TextStyle(fontSize: 13.5)),
                      subtitle: const Text(
                        'Siswa nonaktif tidak muncul di pilihan identitas.',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppNotice.info(
                      text: 'Kode akses tidak dibuat di sini. Gunakan menu Kode Akses agar '
                          'kode dibuat acak oleh server dan hanya ditampilkan sekali.',
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
                  'nama': namaC.text.trim(),
                  'nomor_induk': nomorC.text.trim(),
                  'kelas_id': kelasId,
                  'status_aktif': aktif,
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    nomorC.dispose();
    namaC.dispose();
    if (result == null) return;

    try {
      if (existing == null) {
        await SiswaRepository().create(
          nama: result['nama'] as String,
          nomorInduk: result['nomor_induk'] as String,
          kelasId: result['kelas_id'] as String?,
          statusAktif: result['status_aktif'] as bool? ?? true,
        );
      } else {
        await SiswaRepository().update(existing.id, result);
      }
      if (!mounted) return;
      showAppSnackBar(context, existing == null ? 'Siswa ditambahkan.' : 'Data siswa diperbarui.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _delete(Siswa siswa) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus ${siswa.nama}?',
      content: 'Status tugas siswa ini juga akan terhapus dan tidak bisa dikembalikan.',
    );
    if (!confirmed) return;
    try {
      await SiswaRepository().delete(siswa.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Siswa dihapus.');
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
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah siswa'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Siswa>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <Siswa>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list
                  .where((s) =>
                      s.nama.toLowerCase().contains(needle) ||
                      s.nomorInduk.toLowerCase().contains(needle))
                  .toList();
            }

            final shown = list.take(_visible).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Data siswa',
                  title: 'Manajemen Siswa',
                  subtitle: 'Total ${snapshot.data?.length ?? 0} siswa terdaftar.',
                  footer: Row(
                    children: [
                      _stat('Aktif', '${(snapshot.data ?? const []).where((s) => s.statusAktif).length}'),
                      const SizedBox(width: AppSpacing.xl),
                      _stat('Kelas', '${_kelas.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari nama atau nomor induk…',
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
                        label: const Text('Semua kelas'),
                        selected: _kelasFilter == null,
                        onSelected: (_) {
                          setState(() {
                            _kelasFilter = null;
                            _visible = _pageSize;
                          });
                          _refresh();
                        },
                      ),
                      for (final kelas in _kelas) ...[
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(kelas.namaKelas),
                          selected: _kelasFilter == kelas.id,
                          onSelected: (selected) {
                            setState(() {
                              _kelasFilter = selected ? kelas.id : null;
                              _visible = _pageSize;
                            });
                            _refresh();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 5)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: _kelas.isEmpty ? 'Belum ada kelas' : 'Belum ada siswa',
                      subtitle: _kelas.isEmpty
                          ? 'Tambahkan kelas sebelum menambahkan siswa.'
                          : 'Tambahkan siswa ke kelas agar dapat memakai kode akses.',
                      actionLabel: _kelas.isEmpty ? 'Kelola kelas' : 'Tambah siswa',
                      onAction: _kelas.isEmpty ? () => context.go('/admin/kelas') : () => _showForm(),
                    ),
                  )
                else
                  ...shown.map((siswa) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              InitialsAvatar(name: siswa.nama, size: 42),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            siswa.nama,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        if (!siswa.statusAktif) ...[
                                          const SizedBox(width: AppSpacing.sm),
                                          _badge('Nonaktif', AppColors.error),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'NIS ${siswa.nomorInduk} • ${siswa.kelasNama ?? 'Tanpa kelas'}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showForm(existing: siswa);
                                  if (value == 'delete') _delete(siswa);
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
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
