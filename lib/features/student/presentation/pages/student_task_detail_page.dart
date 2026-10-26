import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/models/tugas.dart';
import '../../identity/student_identity_provider.dart';

class StudentTaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  final bool isTeacherView;
  const StudentTaskDetailPage({super.key, required this.taskId, this.isTeacherView = false});

  @override
  ConsumerState<StudentTaskDetailPage> createState() => _StudentTaskDetailPageState();
}

class _StudentTaskDetailPageState extends ConsumerState<StudentTaskDetailPage> {
  bool _loadingAction = false;

  Future<Tugas?> _fetch() async {
    if (SupabaseConfig.isNotConfigured) return null;
    final identity = ref.read(studentIdentityProvider);
    return TugasRepository().fetchById(widget.taskId, siswaId: identity.siswaId);
  }

  Future<void> _toggleStatus(Tugas tugas) async {
    final identity = ref.read(studentIdentityProvider);
    final isCompleted = identity.isIdentified ? tugas.isCompleted : (ref.read(localTaskStatusProvider)[tugas.id] == 'selesai');
    final newStatus = isCompleted ? 'belum_selesai' : 'selesai';

    // If no identity, use local storage with warning
    if (!identity.isIdentified) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Simpan Lokal?'),
          content: const Text('Kamu belum verifikasi identitas. Status hanya akan tersimpan di perangkat ini dan TIDAK menjadi laporan resmi untuk guru. Lanjutkan?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isCompleted ? 'Tandai Belum Selesai' : 'Tandai Selesai')),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _loadingAction = true);
      await ref.read(localTaskStatusProvider.notifier).setStatus(tugas.id, newStatus == 'selesai' ? 'selesai' : 'belum_selesai');
      if (mounted) {
        showAppSnackBar(context, newStatus == 'selesai' ? 'Ditandai selesai (lokal)' : 'Ditandai belum selesai (lokal)');
        setState(() => _loadingAction = false);
      }
      return;
    }

    setState(() => _loadingAction = true);
    try {
      final repo = TugasRepository();
      // Try secure via token, fallback direct
      if (identity.token != null && identity.token!.startsWith('local-') == false) {
        await repo.updateStudentStatusViaFunction(tugasId: tugas.id, siswaId: identity.siswaId!, status: newStatus, token: identity.token!);
      } else {
        await repo.updateStatusDirect(tugasId: tugas.id, siswaId: identity.siswaId!, status: newStatus);
      }
      if (mounted) {
        showAppSnackBar(context, newStatus == 'selesai' ? 'Tugas ditandai selesai' : 'Tugas ditandai belum selesai');
        setState(() {});
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Gagal mengubah status: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SupabaseConfig.isNotConfigured) {
      return Scaffold(appBar: AppBar(title: const Text('Detail Tugas')), body: const Center(child: Text('Supabase belum dikonfigurasi')));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Tugas')),
      body: FutureBuilder<Tugas?>(
        future: _fetch(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final tugas = snap.data;
          if (tugas == null) return const Center(child: Text('Tugas tidak ditemukan'));
          final identity = ref.watch(studentIdentityProvider);
          final locals = ref.watch(localTaskStatusProvider);
          final isCompleted = identity.isIdentified ? tugas.isCompleted : (locals[tugas.id] == 'selesai');
          final status = DeadlineHelper.getStatus(deadline: tugas.tenggatWaktu, isCompleted: isCompleted);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(tugas.mataPelajaranNama ?? '-', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                            const Spacer(),
                            StatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(tugas.judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(tugas.guruNama ?? '-', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.class_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(tugas.kelasNama ?? '-', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 20),
                        _infoRow('Tanggal Pemberian', AppDateUtils.formatTanggalJam(tugas.tanggalMulai)),
                        _infoRow('Tenggat Waktu', AppDateUtils.formatTanggalJam(tugas.tenggatWaktu)),
                        _infoRow('Sisa Waktu', AppDateUtils.relativeDeadline(tugas.tenggatWaktu), isHighlight: true, highlightColor: DeadlineHelper.colorForStatus(status)),
                        if (tugas.selesaiPada != null) _infoRow('Diselesaikan', AppDateUtils.formatTanggalJam(tugas.selesaiPada!)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deskripsi / Instruksi', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(tugas.deskripsi, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                ),
                if (tugas.lampiranPath != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lampiran', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tugas.lampiranPath!, style: const TextStyle(fontSize: 12))),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      final url = TugasRepository().getPublicUrl(tugas.lampiranPath!);
                                      if (url.isEmpty) {
                                        if (mounted) showAppSnackBar(context, 'Link lampiran tidak tersedia (mode demo)', isError: true);
                                        return;
                                      }
                                      final uri = Uri.tryParse(url);
                                      if (uri == null || !uri.hasScheme) {
                                        if (mounted) showAppSnackBar(context, 'Link lampiran tidak valid', isError: true);
                                        return;
                                      }
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (mounted) showAppSnackBar(context, 'Tidak ada aplikasi untuk membuka link', isError: true);
                                      }
                                    } catch (e) {
                                      if (mounted) showAppSnackBar(context, 'Gagal membuka lampiran', isError: true);
                                    }
                                  },
                                  child: const Text('Buka'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status Penyelesaian', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: DeadlineHelper.bgForStatus(status), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(DeadlineHelper.iconForStatus(status), color: DeadlineHelper.colorForStatus(status)),
                              const SizedBox(width: 8),
                              Text(DeadlineHelper.labelForStatus(status), style: TextStyle(color: DeadlineHelper.colorForStatus(status), fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(isCompleted ? 'Selesai' : 'Belum selesai', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (!identity.isIdentified)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                                SizedBox(width: 8),
                                Expanded(child: Text('Mode lokal: status tidak menjadi laporan resmi. Verifikasi kode siswa untuk laporan ke guru.', style: TextStyle(fontSize: 11, color: AppColors.warningDark))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loadingAction ? null : () => _toggleStatus(tugas),
                            icon: Icon(isCompleted ? Icons.undo : Icons.check_circle),
                            label: _loadingAction
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(isCompleted ? 'Tandai Belum Selesai' : 'Tandai Selesai'),
                            style: ElevatedButton.styleFrom(backgroundColor: isCompleted ? AppColors.textSecondary : AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          const Text(': '),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal, color: highlightColor))),
        ],
      ),
    );
  }
}
