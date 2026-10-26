import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/kelas.dart';
import '../../../shared/repositories/kelas_repository.dart';
import '../../student/identity/student_identity_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';
import 'pengumuman_page.dart' show kelasOptionsProvider;

/// Daftar percakapan.
///
/// * Staff (admin/guru): thread yang diikuti + grup kelas yang diampu (RLS).
/// * Siswa: thread yang diikuti lewat Edge Function bertoken.
class ChatThreadsPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;

  const ChatThreadsPage({super.key, required this.audience});

  @override
  ConsumerState<ChatThreadsPage> createState() => _ChatThreadsPageState();
}

class _ChatThreadsPageState extends ConsumerState<ChatThreadsPage> {
  bool _busy = false;

  String _prefix(String path) {
    if (path.startsWith('/admin')) return '/admin';
    if (path.startsWith('/guru')) return '/guru';
    return '/siswa';
  }

  Future<void> _refresh() async {
    ref.invalidate(chatThreadsProvider(widget.audience));
    await ref
        .read(chatThreadsProvider(widget.audience).future)
        .catchError((_) => const <ChatThread>[]);
  }

  Future<void> _openRoom(String threadId, {String? judul}) async {
    final prefix = _prefix(GoRouterState.of(context).uri.path);
    final query = judul == null ? '' : '?judul=${Uri.encodeComponent(judul)}';
    await context.push('$prefix/chat/$threadId$query');
    if (mounted) ref.invalidate(chatThreadsProvider(widget.audience));
  }

  Future<void> _startStudentChat() async {
    final gateway = ref.read(studentGatewayProvider);
    final kelasId = ref.read(studentIdentityProvider).kelasId;
    setState(() => _busy = true);
    try {
      final pilihan = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('Mulai percakapan', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.groups_rounded, color: AppColors.primary),
                title: const Text('Grup kelas'),
                subtitle: Text(kelasId == null ? 'Kelas belum ditentukan' : 'Semua siswa di kelas Anda'),
                enabled: kelasId != null,
                onTap: () => Navigator.of(ctx).pop('kelas'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                title: const Text('Pesan guru'),
                subtitle: const Text('Tanya langsung ke guru pengampu'),
                onTap: () => Navigator.of(ctx).pop('guru'),
              ),
            ],
          ),
        ),
      );
      if (pilihan == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      ChatThread? thread;
      if (pilihan == 'kelas') {
        thread = await gateway.openThread(tipe: 'kelas');
      } else {
        final guru = await gateway.fetchGuruKelas();
        if (!mounted) return;
        if (guru.isEmpty) {
          akademikSnack(context, 'Belum ada guru yang terhubung dengan kelas Anda.', isError: true);
          setState(() => _busy = false);
          return;
        }
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in guru)
                  ListTile(
                    leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                    title: Text(g['full_name']?.toString() ?? 'Guru'),
                    onTap: () => Navigator.of(ctx).pop(g['id']?.toString()),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) {
          setState(() => _busy = false);
          return;
        }
        thread = await gateway.openThread(tipe: 'direct', guruId: picked);
      }

      if (!mounted) return;
      setState(() => _busy = false);
      if (thread != null) {
        await _openRoom(thread.id, judul: thread.judul);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAkademikErrorDialog(context, e);
    }
  }

  Future<void> _startStaffChat() async {
    final kelas = await ref.read(kelasOptionsProvider.future).catchError((_) => const <Kelas>[]);
    if (!mounted) return;
    if (kelas.isEmpty) {
      akademikSnack(context, 'Belum ada kelas yang bisa dibuatkan grup.', isError: true);
      return;
    }
    final picked = await showModalBottomSheet<Kelas>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Buat grup kelas', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final k in kelas)
              ListTile(
                leading: const Icon(Icons.groups_rounded, color: AppColors.primary),
                title: Text(k.namaKelas),
                onTap: () => Navigator.of(ctx).pop(k),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final id = await ref.read(akademikRepositoryProvider).ensureKelasThread(
            kelasId: picked.id,
            judul: 'Grup ${picked.namaKelas}',
          );
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(chatThreadsProvider(widget.audience));
      if (id != null) await _openRoom(id, judul: picked.namaKelas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAkademikErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatThreadsProvider(widget.audience));
    final identity = ref.watch(studentIdentityProvider);
    final needsIdentity = widget.audience == AkademikAudience.siswa && !identity.isIdentified;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: needsIdentity
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy
                  ? null
                  : (widget.audience == AkademikAudience.siswa ? _startStudentChat : _startStaffChat),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.edit_rounded),
              label: const Text('Baru'),
            ),
      body: needsIdentity
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SizedBox(height: 40),
                EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Chat butuh identitas',
                  subtitle: 'Hubungkan identitas siswa dengan kode akses agar bisa mengobrol dengan guru.',
                  actionLabel: 'Hubungkan identitas',
                  onAction: () => context.go('/siswa/identitas'),
                ),
              ],
            )
          : async.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 5)],
              ),
              error: (e, _) => AkademikErrorView(
                error: e,
                onRetry: () async {
                  ref.invalidate(chatThreadsProvider(widget.audience));
                },
              ),
              data: (threads) {
                if (threads.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Belum ada percakapan',
                          subtitle: widget.audience == AkademikAudience.siswa
                              ? 'Mulai percakapan dengan guru atau grup kelas Anda.'
                              : 'Buat grup kelas untuk mengirim informasi ke seluruh siswa.',
                          actionLabel: 'Mulai percakapan',
                          onAction: widget.audience == AkademikAudience.siswa
                              ? _startStudentChat
                              : _startStaffChat,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      return _ChatThreadTile(
                        thread: thread,
                        onTap: () => _openRoom(thread.id, judul: thread.judul),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;

  const _ChatThreadTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGroup = thread.tipe != 'direct';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primaryContainer,
            child: Icon(
              isGroup ? Icons.groups_rounded : Icons.person_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: thread.unread > 0 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  chatThreadTipeLabel(thread.tipe),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (thread.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                thread.unread > 99 ? '99+' : '${thread.unread}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (thread.lastMessageAt != null)
            Text(
              formatTanggal(thread.lastMessageAt!),
              style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// Dipakai halaman lain yang perlu daftar kelas tanpa membuat provider baru.
final daftarKelasProvider = FutureProvider.autoDispose<List<Kelas>>((ref) async {
  return KelasRepository().fetchAll();
});
