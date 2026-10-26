import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../../../shared/services/attachment_service.dart';

final adminTaskDetailProvider = FutureProvider.autoDispose.family<Tugas?, String>((ref, id) {
  return TugasRepository().fetchById(id);
});

class AdminTaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const AdminTaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<AdminTaskDetailPage> createState() => _AdminTaskDetailPageState();
}

class _AdminTaskDetailPageState extends ConsumerState<AdminTaskDetailPage> {
  bool _busy = false;

  Future<void> _openAttachment(Tugas tugas) async {
    final path = tugas.lampiranPath;
    if (path == null || path.isEmpty) return;
    final url = await AttachmentService.signedUrl(path);
    if (!mounted) return;
    if (url == null) {
      showAppSnackBar(context, 'Lampiran tidak dapat dibuka (file hilang atau akses ditolak).', isError: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      showAppSnackBar(context, 'Tidak ada aplikasi untuk membuka file ini.', isError: true);
    }
  }

  Future<void> _togglePublish(Tugas tugas) async {
    final next = tugas.isPublished ? 'draft' : 'published';
    setState(() => _busy = true);
    try {
      await TugasRepository().update(tugas.id, {'status_publikasi': next});
      if (!mounted) return;
      ref.invalidate(adminTaskDetailProvider(widget.taskId));
      showAppSnackBar(context, next == 'published' ? 'Tugas diterbitkan.' : 'Tugas dijadikan draft.');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Tugas tugas) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus tugas?',
      content: '"${tugas.judul}" beserta seluruh status pengerjaan siswa akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await TugasRepository().delete(tugas.id);
      if (tugas.lampiranPath != null) {
        await AttachmentService.delete(tugas.lampiranPath!);
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Tugas dan lampirannya dihapus.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/admin/tugas');
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminTaskDetailProvider(widget.taskId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          IconButton(
            tooltip: 'Status siswa',
            onPressed: () => context.push('/admin/tugas/${widget.taskId}/status'),
            icon: const Icon(Icons.groups_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminTaskDetailProvider(widget.taskId)),
        child: async.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 3)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(error: e, onRetry: () => ref.invalidate(adminTaskDetailProvider(widget.taskId))),
            ],
          ),
          data: (tugas) {
            if (tugas == null) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Tugas tidak ditemukan',
                      subtitle: 'Tugas mungkin sudah dihapus.',
                      actionLabel: 'Kembali',
                      onAction: () => context.canPop() ? context.pop() : context.go('/admin/tugas'),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  eyebrow: '${tugas.kelasNama ?? '-'} • ${tugas.mataPelajaranNama ?? '-'}',
                  title: tugas.judul,
                  subtitle: 'Guru: ${tugas.guruNama ?? '-'}',
                  footer: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(
                        status: DeadlineHelper.getStatus(deadline: tugas.tenggatWaktu, isCompleted: false),
                      ),
                      MetaPill(
                        label: tugas.statusPublikasi == 'published'
                            ? 'Terbit'
                            : tugas.statusPublikasi == 'draft'
                                ? 'Draft'
                                : 'Arsip',
                        icon: Icons.visibility_outlined,
                      ),
                      if (tugas.hasLampiran) const MetaPill(label: 'Berlampiran', icon: Icons.attach_file_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow(label: 'Tanggal mulai', value: AppDateUtils.formatTanggalJam(tugas.tanggalMulai), icon: Icons.play_circle_outline_rounded),
                      InfoRow(label: 'Tenggat', value: AppDateUtils.formatTanggalJam(tugas.tenggatWaktu), icon: Icons.event_busy_rounded),
                      InfoRow(label: 'Dibuat', value: AppDateUtils.formatTanggalJam(tugas.createdAt), icon: Icons.add_circle_outline_rounded),
                      InfoRow(label: 'Diperbarui', value: AppDateUtils.formatTanggalJam(tugas.updatedAt), icon: Icons.update_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Instruksi', icon: Icons.notes_rounded),
                      Text(
                        tugas.deskripsi.trim().isEmpty ? 'Tidak ada instruksi.' : tugas.deskripsi,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      if (tugas.hasLampiran) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _openAttachment(tugas),
                          icon: const Icon(Icons.attach_file_rounded, size: 18),
                          label: Text(AttachmentService.displayName(tugas.lampiranPath!)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => context.push('/admin/tugas/${tugas.id}/edit'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit tugas'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _togglePublish(tugas),
                        icon: Icon(tugas.isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded, size: 18),
                        label: Text(tugas.isPublished ? 'Jadikan draft' : 'Terbitkan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => context.push('/admin/tugas/${tugas.id}/status'),
                        icon: const Icon(Icons.insights_rounded, size: 18),
                        label: const Text('Laporan siswa'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _delete(tugas),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                        label: const Text('Hapus', style: TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppNotice.info(
                  text: 'Admin dapat memoderasi, memperbarui, dan menghapus tugas. Kepemilikan '
                      'tugas (guru_id) tidak berubah saat admin menyunting.',
                ),
                if (_busy) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
