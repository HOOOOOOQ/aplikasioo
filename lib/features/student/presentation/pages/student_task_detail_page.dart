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
import '../../../akademik/presentation/pengumpulan_section.dart';
import '../../identity/student_identity_provider.dart';

final taskDetailProvider = FutureProvider.autoDispose.family<Tugas?, String>((ref, taskId) async {
  final identity = ref.watch(studentIdentityProvider);
  return TugasRepository().fetchById(taskId, siswaId: identity.siswaId);
});

class StudentTaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  final bool isTeacherView;

  /// Admin membuka tugas guru (moderasi). Tombol ubah/status tetap memakai
  /// otorisasi server, bukan flag ini.
  final bool adminMode;

  const StudentTaskDetailPage({
    super.key,
    required this.taskId,
    this.isTeacherView = false,
    this.adminMode = false,
  });

  @override
  ConsumerState<StudentTaskDetailPage> createState() => _StudentTaskDetailPageState();
}

class _StudentTaskDetailPageState extends ConsumerState<StudentTaskDetailPage> {
  bool _busy = false;

  Future<void> _openAttachment(Tugas tugas) async {
    final path = tugas.lampiranPath;
    if (path == null || path.isEmpty) return;
    showAppSnackBar(context, 'Menyiapkan tautan lampiran…');
    final url = await AttachmentService.signedUrl(path);
    if (!mounted) return;
    if (url == null) {
      showAppSnackBar(
        context,
        'Lampiran tidak dapat dibuka. File mungkin terhapus atau Anda tidak punya akses.',
        isError: true,
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppSnackBar(context, 'Tautan lampiran tidak valid.', isError: true);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showAppSnackBar(context, 'Tidak ada aplikasi yang bisa membuka file ini.', isError: true);
    }
  }

  Future<void> _setOfficialStatus(Tugas tugas, bool selesai) async {
    final identity = ref.read(studentIdentityProvider);
    if (!identity.isIdentified) {
      showAppSnackBar(context, 'Verifikasi kode akses terlebih dahulu untuk laporan resmi.', isError: true);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: selesai ? 'Tandai selesai?' : 'Batalkan status selesai?',
      content: selesai
          ? 'Status ini dikirim ke server dan terlihat oleh guru.'
          : 'Guru akan melihat tugas ini kembali sebagai belum selesai.',
      confirmLabel: selesai ? 'Ya, selesai' : 'Ya, batalkan',
      isDestructive: !selesai,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await TugasRepository().updateStudentStatusViaFunction(
        tugasId: tugas.id,
        siswaId: identity.siswaId!,
        status: selesai ? 'selesai' : 'belum_selesai',
        token: identity.token!,
      );
      if (!mounted) return;
      ref.invalidate(taskDetailProvider(widget.taskId));
      showAppSnackBar(context, selesai ? 'Tugas ditandai selesai (resmi).' : 'Status dikembalikan.');
    } catch (e) {
      if (!mounted) return;
      final error = AppError.from(e);
      // Token identitas siswa (HMAC) berbeda dari sesi login admin/guru.
      const identityCodes = {
        'student_token_missing',
        'student_token_invalid',
        'student_token_expired',
        'token_expired',
        'token_mismatch',
        'missing_token',
        'invalid_token',
        'unauthorized',
      };
      final identityIssue = identityCodes.contains(error.code) ||
          error.message.toLowerCase().contains('verifikasi ulang kode');
      showAppSnackBar(
        context,
        identityIssue
            ? 'Sesi identitas berakhir. Verifikasi ulang kode akses di halaman Identitas.'
            : error.shortMessage,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setLocalStatus(Tugas tugas, bool selesai) async {
    final confirmed = await showConfirmDialog(
      context,
      title: selesai ? 'Tandai selesai di perangkat ini?' : 'Batalkan tanda selesai?',
      content: 'Anda belum memverifikasi kode akses, jadi status ini HANYA tersimpan di perangkat ini '
          'dan tidak dikirim ke guru. Untuk laporan resmi, verifikasi kode akses terlebih dahulu.',
      confirmLabel: 'Mengerti',
      isDestructive: !selesai,
    );
    if (!confirmed || !mounted) return;
    await ref.read(localTaskStatusProvider.notifier).setStatus(
          tugas.id,
          selesai ? 'selesai' : 'belum_selesai',
        );
    if (!mounted) return;
    showAppSnackBar(context, selesai ? 'Ditandai selesai (lokal).' : 'Tanda selesai dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskDetailProvider(widget.taskId));
    final localStatus = ref.watch(localTaskStatusProvider)[widget.taskId];
    final identity = ref.watch(studentIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          if (widget.isTeacherView)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') context.push('/guru/tugas/${widget.taskId}/edit');
                if (value == 'status') context.push('/guru/tugas/${widget.taskId}/status');
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit tugas')),
                PopupMenuItem(value: 'status', child: Text('Status siswa')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(taskDetailProvider(widget.taskId)),
        child: async.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 3)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(
                error: e,
                onRetry: () => ref.invalidate(taskDetailProvider(widget.taskId)),
              ),
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
                      subtitle: widget.isTeacherView
                          ? 'Tugas sudah dihapus atau bukan milik Anda.'
                          : 'Tugas belum diterbitkan, sudah dihapus, atau bukan untuk kelas Anda.',
                      actionLabel: 'Kembali',
                      onAction: () => context.canPop() ? context.pop() : context.go('/siswa'),
                    ),
                  ),
                ],
              );
            }

            final official = tugas.statusSiswa == 'selesai';
            final local = localStatus == 'selesai';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  eyebrow: '${tugas.mataPelajaranNama ?? '-'} • ${tugas.kelasNama ?? '-'}',
                  title: tugas.judul,
                  subtitle: 'Guru: ${tugas.guruNama ?? '-'}',
                  footer: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(
                        status: DeadlineHelper.getStatus(
                          deadline: tugas.tenggatWaktu,
                          isCompleted: official || local,
                        ),
                      ),
                      if (!widget.isTeacherView && official)
                        const StatusSourceBadge(official: true)
                      else if (!widget.isTeacherView && local)
                        const StatusSourceBadge(official: false),
                      if (widget.isTeacherView)
                        MetaPill(
                          label: tugas.isPublished ? 'Terbit' : (tugas.statusPublikasi == 'draft' ? 'Draft' : 'Arsip'),
                          icon: Icons.visibility_outlined,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Rincian tenggat', icon: Icons.schedule_rounded),
                      InfoRow(
                        label: 'Mulai',
                        value: AppDateUtils.formatTanggalJam(tugas.tanggalMulai),
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      InfoRow(
                        label: 'Tenggat',
                        value: AppDateUtils.formatTanggalJam(tugas.tenggatWaktu),
                        icon: Icons.event_busy_rounded,
                      ),
                      InfoRow(
                        label: 'Sisa waktu',
                        value: AppDateUtils.relativeDeadline(tugas.tenggatWaktu),
                        icon: Icons.timelapse_rounded,
                      ),
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
                        tugas.deskripsi.trim().isEmpty ? 'Guru tidak menuliskan instruksi tambahan.' : tugas.deskripsi,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      if (tugas.hasLampiran) ...[
                        const SizedBox(height: AppSpacing.lg),
                        InkWell(
                          onTap: _busy ? null : () => _openAttachment(tugas),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file_rounded, color: AppColors.primaryDark),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AttachmentService.displayName(tugas.lampiranPath!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const Text(
                                        'Buka lampiran (tautan aman 1 jam)',
                                        style: TextStyle(fontSize: 10.5, color: AppColors.primaryDark),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.primaryDark),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!widget.isTeacherView) ...[
                  if (!identity.isIdentified)
                    const AppNotice.warning(
                      title: 'Mode tanpa verifikasi',
                      text: 'Status yang Anda tandai hanya tersimpan di perangkat ini dan tidak '
                          'dihitung oleh guru. Verifikasi kode akses di halaman Identitas untuk '
                          'mencatat status resmi.',
                    )
                  else
                    AppNotice.success(
                      title: 'Identitas terverifikasi',
                      text: 'Perubahan status dikirim ke server dan tercatat sebagai laporan resmi.',
                    ),
                  const SizedBox(height: AppSpacing.md),
                  if (official)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _setOfficialStatus(tugas, false),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Batalkan status selesai'),
                    )
                  else if (identity.isIdentified)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _setOfficialStatus(tugas, true),
                      icon: const Icon(Icons.task_alt_rounded, size: 18),
                      label: const Text('Tandai selesai (resmi)'),
                    )
                  else if (local)
                    Column(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _setLocalStatus(tugas, false),
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Batalkan tanda selesai lokal'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => context.push('/siswa/identitas'),
                          icon: const Icon(Icons.verified_user_outlined, size: 18),
                          label: const Text('Verifikasi kode untuk laporan resmi'),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _setLocalStatus(tugas, true),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Tandai selesai di perangkat'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => context.push('/siswa/identitas'),
                          icon: const Icon(Icons.verified_user_outlined, size: 18),
                          label: const Text('Verifikasi kode untuk laporan resmi'),
                        ),
                      ],
                    ),
                  if (_busy) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/guru/tugas/${tugas.id}/edit'),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit tugas'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => widget.adminMode
                              ? context.push('/admin/tugas/${tugas.id}/status')
                              : context.push('/guru/tugas/${tugas.id}/status'),
                          icon: const Icon(Icons.groups_rounded, size: 18),
                          label: const Text('Status siswa'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (widget.isTeacherView) ...[
                  StaffPengumpulanSection(tugasId: tugas.id),
                  const SizedBox(height: AppSpacing.lg),
                  TugasDiskusiSection(tugasId: tugas.id, staff: true),
                ] else ...[
                  StudentPengumpulanSection(tugasId: tugas.id),
                  const SizedBox(height: AppSpacing.lg),
                  TugasDiskusiSection(tugasId: tugas.id, staff: false),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
