import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/kelas.dart';
import '../../../shared/repositories/kelas_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

final kelasOptionsProvider = FutureProvider.autoDispose<List<Kelas>>((ref) async {
  return KelasRepository().fetchAll();
});

/// Daftar pengumuman sekolah.
///
/// * Siswa: hanya pengumuman yang sudah terbit (RLS `anon`).
/// * Guru/admin: pengumuman pada kelas yang diampu + pengumuman umum, dan
///   boleh menulis pengumuman baru (validasi akhir tetap di RLS server).
class PengumumanPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;

  const PengumumanPage({super.key, required this.audience});

  @override
  ConsumerState<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends ConsumerState<PengumumanPage> {
  bool _creating = false;

  Future<void> _refresh() async {
    ref.invalidate(pengumumanProvider(widget.audience));
    await ref.read(pengumumanProvider(widget.audience).future).catchError((_) => const <Pengumuman>[]);
  }

  String _prefix(String path) {
    if (path.startsWith('/admin')) return '/admin';
    if (path.startsWith('/guru')) return '/guru';
    return '/siswa';
  }

  Future<void> _openCreate() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || user.role == UserRole.unknown) {
      akademikSnack(context, 'Masuk sebagai guru atau admin untuk menulis pengumuman.', isError: true);
      return;
    }
    setState(() => _creating = true);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PengumumanForm(user: user),
      ),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (created == true) {
      ref.invalidate(pengumumanProvider(widget.audience));
      akademikSnack(context, 'Pengumuman terbit.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pengumumanProvider(widget.audience));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canWrite = widget.audience == AkademikAudience.staff && user != null && user.role != UserRole.unknown;
    final path = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [
          AkademikActionButton(
            icon: Icons.search_rounded,
            tooltip: 'Cari',
            onPressed: () => context.go('${_prefix(path)}/pencarian'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _creating ? null : _openCreate,
              icon: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.campaign_rounded),
              label: const Text('Tulis'),
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
            ref.invalidate(pengumumanProvider(widget.audience));
          },
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Belum ada pengumuman',
                    subtitle: canWrite
                        ? 'Tulis pengumuman agar siswa dan guru mendapat informasi terbaru.'
                        : 'Pengumuman dari sekolah akan muncul di sini.',
                    actionLabel: canWrite ? 'Tulis pengumuman' : null,
                    onAction: canWrite ? _openCreate : null,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = items[index];
                return _PengumumanCard(
                  item: item,
                  onTap: () => _showDetail(context, item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Pengumuman item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Text(item.judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 4,
              children: [
                AkademikMeta(icon: Icons.schedule_rounded, text: formatTanggalWaktu(item.publishAt)),
                AkademikMeta(
                  icon: Icons.groups_rounded,
                  text: switch (item.target) {
                    'guru' => 'Untuk guru',
                    'siswa' => 'Untuk siswa',
                    _ => 'Untuk semua',
                  },
                ),
                if (item.penulisNama != null)
                  AkademikMeta(icon: Icons.person_outline_rounded, text: item.penulisNama!),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            SelectableText(item.isi, style: const TextStyle(fontSize: 14, height: 1.55)),
          ],
        ),
      ),
    );
  }
}

class _PengumumanCard extends StatelessWidget {
  final Pengumuman item;
  final VoidCallback onTap;

  const _PengumumanCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.campaign_rounded, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.isi,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AkademikMeta(icon: Icons.schedule_rounded, text: formatTanggal(item.publishAt)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}

class _PengumumanForm extends ConsumerStatefulWidget {
  final AppUser user;

  const _PengumumanForm({required this.user});

  @override
  ConsumerState<_PengumumanForm> createState() => _PengumumanFormState();
}

class _PengumumanFormState extends ConsumerState<_PengumumanForm> {
  final _formKey = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _isi = TextEditingController();
  String _target = 'semua';
  String? _kelasId;
  bool _saving = false;

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(akademikRepositoryProvider).createPengumuman(
            judul: _judul.text,
            isi: _isi.text,
            target: _target,
            kelasId: _kelasId,
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
    final kelasAsync = ref.watch(kelasOptionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Pengumuman baru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Diterbitkan sebagai ${widget.user.role == UserRole.admin ? 'admin sekolah' : 'guru'}.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _judul,
                maxLength: 160,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Judul', hintText: 'Contoh: Jadwal UTS'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 3) return 'Judul minimal 3 karakter.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _isi,
                maxLines: 6,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Isi pengumuman',
                  alignLabelWithHint: true,
                  hintText: 'Tuliskan informasi lengkap, tanggal, dan hal yang perlu dilakukan.',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 3) return 'Isi minimal 3 karakter.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Sasaran', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final t in const ['semua', 'siswa', 'guru'])
                    ChoiceChip(
                      label: Text(switch (t) {
                        'siswa' => 'Siswa',
                        'guru' => 'Guru',
                        _ => 'Semua',
                      }),
                      selected: _target == t,
                      onSelected: (_) => setState(() => _target = t),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              kelasAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const Text(
                  'Daftar kelas tidak dapat dimuat. Pengumuman tetap bisa dikirim ke semua.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
                data: (kelas) {
                  if (kelas.isEmpty) return const SizedBox.shrink();
                  final match = kelas.where((k) => k.id == _kelasId).toList();
                  final selected = match.isEmpty ? null : match.first;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.class_outlined, color: AppColors.primary),
                    title: const Text('Khusus kelas (opsional)', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      selected?.namaKelas ?? 'Seluruh sekolah',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.expand_more_rounded),
                    onTap: _saving
                        ? null
                        : () async {
                            final picked = await showModalBottomSheet<String>(
                              context: context,
                              showDragHandle: true,
                              builder: (ctx) => SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    ListTile(
                                      title: const Text('Seluruh sekolah'),
                                      onTap: () => Navigator.of(ctx).pop(''),
                                    ),
                                    for (final k in kelas)
                                      ListTile(
                                        title: Text(k.namaKelas),
                                        onTap: () => Navigator.of(ctx).pop(k.id),
                                      ),
                                  ],
                                ),
                              ),
                            );
                            if (picked == null) return;
                            setState(() => _kelasId = picked.isEmpty ? null : picked);
                          },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_saving ? 'Menerbitkan…' : 'Terbitkan'),
              ),
              const SizedBox(height: AppSpacing.sm),
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
