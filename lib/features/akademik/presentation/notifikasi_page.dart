import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

/// Pusat notifikasi dengan status baca.
///
/// Siswa membaca/menandai lewat Edge Function bertoken; staff lewat RLS
/// (`notifikasi.profile_id = auth.uid()`).
class NotifikasiPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;

  const NotifikasiPage({super.key, required this.audience});

  @override
  ConsumerState<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends ConsumerState<NotifikasiPage> {
  bool _markingAll = false;

  String _prefix(String path) {
    if (path.startsWith('/admin')) return '/admin';
    if (path.startsWith('/guru')) return '/guru';
    return '/siswa';
  }

  Future<void> _refresh() async {
    ref.invalidate(notifikasiProvider(widget.audience));
    await ref
        .read(notifikasiProvider(widget.audience).future)
        .catchError((_) => const <NotifikasiItem>[]);
  }

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      if (widget.audience == AkademikAudience.staff) {
        await ref.read(akademikRepositoryProvider).markAllNotifikasiRead();
      } else {
        await ref.read(studentGatewayProvider).markAllNotifikasiRead();
      }
      if (!mounted) return;
      ref.invalidate(notifikasiProvider(widget.audience));
      akademikSnack(context, 'Semua notifikasi ditandai sudah dibaca.');
    } catch (e) {
      if (!mounted) return;
      await showAkademikErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(NotifikasiItem item) async {
    if (!item.isRead) {
      try {
        if (widget.audience == AkademikAudience.staff) {
          await ref.read(akademikRepositoryProvider).markNotifikasiRead(item.id);
        } else {
          await ref.read(studentGatewayProvider).markNotifikasiRead(item.id);
        }
        if (mounted) ref.invalidate(notifikasiProvider(widget.audience));
      } catch (_) {
        // Gagal menandai tidak menghalangi pengguna membuka tujuan notifikasi.
      }
    }
    if (!mounted) return;
    final prefix = _prefix(GoRouterState.of(context).uri.path);
    switch (item.tipe) {
      case 'tugas':
        if (item.refId != null && item.refId!.isNotEmpty) {
          context.go(widget.audience == AkademikAudience.staff
              ? '$prefix/tugas/${item.refId}'
              : '/siswa/tugas/${item.refId}');
        }
      case 'pengumuman':
        context.go('$prefix/pengumuman');
      case 'chat':
        context.go('$prefix/chat');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notifikasiProvider(widget.audience));
    final items = async.valueOrNull ?? const <NotifikasiItem>[];
    final unread = items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAll,
              child: _markingAll
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Baca semua'),
            ),
        ],
      ),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 5)],
        ),
        error: (e, _) => AkademikErrorView(
          error: e,
          onRetry: () async {
            ref.invalidate(notifikasiProvider(widget.audience));
          },
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Belum ada notifikasi',
                    subtitle: 'Pemberitahuan tugas baru, pengumuman, dan pesan akan tampil di sini.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = list[index];
                return AppCard(
                  onTap: () => _open(item),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: item.isRead ? AppColors.surface : AppColors.primaryContainer.withValues(alpha: 0.45),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.isRead ? AppColors.surfaceMuted : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(
                          notifikasiIcon(item.tipe),
                          size: 18,
                          color: item.isRead ? AppColors.textSecondary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.judul,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                              ),
                            ),
                            if (item.isi != null && item.isi!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.isi!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            AkademikMeta(
                              icon: Icons.schedule_rounded,
                              text: formatTanggalWaktu(item.createdAt),
                            ),
                          ],
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, left: 6),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
