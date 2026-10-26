import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../student/identity/student_identity_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

String statusPengumpulanLabel(String status) => switch (status) {
      'draft' => 'Draf',
      'terkirim' => 'Menunggu nilai',
      'dinilai' => 'Sudah dinilai',
      'revisi' => 'Perlu revisi',
      _ => status,
    };

Color statusPengumpulanColor(String status) => switch (status) {
      'dinilai' => AppColors.success,
      'revisi' => AppColors.error,
      'terkirim' => AppColors.info,
      _ => AppColors.textSecondary,
    };

/// Bagian pengumpulan jawaban untuk SISWA pada satu tugas.
class StudentPengumpulanSection extends ConsumerStatefulWidget {
  final String tugasId;

  const StudentPengumpulanSection({super.key, required this.tugasId});

  @override
  ConsumerState<StudentPengumpulanSection> createState() => _StudentPengumpulanSectionState();
}

class _StudentPengumpulanSectionState extends ConsumerState<StudentPengumpulanSection> {
  final _jawaban = TextEditingController();
  bool _sending = false;
  bool _expanded = false;

  @override
  void dispose() {
    _jawaban.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final teks = _jawaban.text.trim();
    if (teks.length < 3) {
      akademikSnack(context, 'Tulis jawaban minimal 3 karakter.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(studentGatewayProvider).submitTask(tugasId: widget.tugasId, jawabanTeks: teks);
      if (!mounted) return;
      _jawaban.clear();
      ref.invalidate(mySubmissionsProvider(widget.tugasId));
      setState(() {
        _sending = false;
        _expanded = false;
      });
      akademikSnack(context, 'Jawaban terkirim ke guru.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      await showAkademikErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final async = ref.watch(mySubmissionsProvider(widget.tugasId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Pengumpulan jawaban', icon: Icons.upload_file_rounded),
        AppCard(
          child: !identity.isIdentified
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hubungkan identitas dengan kode akses untuk mengirim jawaban dan melihat nilai.',
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/siswa/identitas'),
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: const Text('Hubungkan identitas'),
                    ),
                  ],
                )
              : async.when(
                  loading: () => const AppLoading(message: 'Memuat pengumpulan…', compact: true),
                  error: (e, _) => _inlineError(e, () => ref.invalidate(mySubmissionsProvider(widget.tugasId))),
                  data: (items) {
                    final terakhir = items.isEmpty ? null : items.first;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (terakhir != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusPengumpulanColor(terakhir.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusPengumpulanLabel(terakhir.status),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: statusPengumpulanColor(terakhir.status),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Revisi ke-${terakhir.revisiKe}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                              ),
                              const Spacer(),
                              if (terakhir.sudahDinilai)
                                Text(
                                  'Nilai ${terakhir.nilai!.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                          if (terakhir.jawabanTeks != null && terakhir.jawabanTeks!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              terakhir.jawabanTeks!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, height: 1.45),
                            ),
                          ],
                          if (terakhir.umpanBalik != null && terakhir.umpanBalik!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.infoContainer,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Umpan balik guru',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    terakhir.umpanBalik!,
                                    style: const TextStyle(fontSize: 12, height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (!_expanded)
                          FilledButton.icon(
                            onPressed: () => setState(() => _expanded = true),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: Text(terakhir == null ? 'Tulis jawaban' : 'Kirim revisi jawaban'),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _jawaban,
                                maxLines: 6,
                                maxLength: 8000,
                                enabled: !_sending,
                                decoration: InputDecoration(
                                  hintText: terakhir == null
                                      ? 'Tulis jawaban atau rangkuman pekerjaan Anda…'
                                      : 'Tulis perbaikan jawaban (revisi ke-${terakhir.revisiKe + 1})…',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: _sending ? null : () => setState(() => _expanded = false),
                                    child: const Text('Batal'),
                                  ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: _sending ? null : _submit,
                                    icon: _sending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.send_rounded, size: 17),
                                    label: Text(_sending ? 'Mengirim…' : 'Kirim jawaban'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Bagian penilaian untuk GURU/ADMIN pada satu tugas.
class StaffPengumpulanSection extends ConsumerStatefulWidget {
  final String tugasId;

  const StaffPengumpulanSection({super.key, required this.tugasId});

  @override
  ConsumerState<StaffPengumpulanSection> createState() => _StaffPengumpulanSectionState();
}

class _StaffPengumpulanSectionState extends ConsumerState<StaffPengumpulanSection> {
  String? _processing;

  Future<void> _nilai(Pengumpulan item) async {
    final nilaiC = TextEditingController(text: item.nilai?.toStringAsFixed(0) ?? '');
    final umpanC = TextEditingController(text: item.umpanBalik ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nilai jawaban', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.jawabanTeks != null && item.jawabanTeks!.isNotEmpty) ...[
                  Text(
                    item.jawabanTeks!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: nilaiC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Nilai (0–100)'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null) return 'Masukkan angka.';
                    if (n < 0 || n > 100) return 'Nilai harus 0–100.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: umpanC,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Umpan balik (opsional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Simpan nilai'),
          ),
        ],
      ),
    );

    final nilai = double.tryParse(nilaiC.text.replaceAll(',', '.'));
    final umpan = umpanC.text.trim();
    nilaiC.dispose();
    umpanC.dispose();
    if (saved != true || nilai == null || !mounted) return;

    setState(() => _processing = item.id);
    try {
      await ref.read(penilaianRepositoryProvider).beriNilai(
            pengumpulanId: item.id,
            nilai: nilai,
            umpanBalik: umpan.isEmpty ? null : umpan,
          );
      if (!mounted) return;
      ref.invalidate(tugasPengumpulanProvider(widget.tugasId));
      akademikSnack(context, 'Nilai tersimpan.');
    } catch (e) {
      if (!mounted) return;
      await showAkademikErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tugasPengumpulanProvider(widget.tugasId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Jawaban siswa', icon: Icons.assignment_turned_in_rounded),
        AppCard(
          child: async.when(
            loading: () => const AppLoading(message: 'Memuat jawaban…', compact: true),
            error: (e, _) => _inlineError(e, () => ref.invalidate(tugasPengumpulanProvider(widget.tugasId))),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Belum ada yang mengumpulkan',
                  subtitle: 'Jawaban siswa akan muncul di sini setelah dikirim.',
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusPengumpulanColor(item.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusPengumpulanLabel(item.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusPengumpulanColor(item.status),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Revisi ${item.revisiKe} • ${formatTanggalWaktu(item.submittedAt)}',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                              ),
                              const Spacer(),
                              if (item.nilai != null)
                                Text(
                                  item.nilai!.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
                                ),
                            ],
                          ),
                          if (item.jawabanTeks != null && item.jawabanTeks!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.jawabanTeks!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, height: 1.45),
                            ),
                          ],
                          if (item.lampiranPath != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Lampiran: ${item.lampiranPath}',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _processing == item.id ? null : () => _nilai(item),
                              icon: _processing == item.id
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.grade_rounded, size: 17),
                              label: Text(item.sudahDinilai ? 'Ubah nilai' : 'Beri nilai'),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Diskusi tugas (komentar siswa & guru) pada satu tugas.
class TugasDiskusiSection extends ConsumerStatefulWidget {
  final String tugasId;
  final bool staff;

  const TugasDiskusiSection({super.key, required this.tugasId, required this.staff});

  @override
  ConsumerState<TugasDiskusiSection> createState() => _TugasDiskusiSectionState();
}

class _TugasDiskusiSectionState extends ConsumerState<TugasDiskusiSection> {
  final _isi = TextEditingController();
  bool _sending = false;
  bool _expanded = false;

  @override
  void dispose() {
    _isi.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final teks = _isi.text.trim();
    if (teks.isEmpty) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    final identity = ref.read(studentIdentityProvider);

    setState(() => _sending = true);
    try {
      if (widget.staff) {
        if (user == null) {
          throw const AppError(
            title: 'Sesi berakhir',
            message: 'Masuk kembali untuk mengirim komentar.',
            code: 'session_expired',
          );
        }
        await ref.read(komentarRepositoryProvider).add(
              tugasId: widget.tugasId,
              isi: teks,
              authorNama: user.fullName,
              authorRole: user.role == UserRole.admin ? 'admin' : 'guru',
            );
      } else {
        if (!identity.isIdentified) {
          throw const AppError(
            title: 'Identitas belum terhubung',
            message: 'Hubungkan identitas dengan kode akses untuk ikut berdiskusi.',
            code: 'identity_required',
          );
        }
        await ref.read(studentGatewayProvider).addComment(tugasId: widget.tugasId, isi: teks);
      }
      if (!mounted) return;
      _isi.clear();
      ref.invalidate(komentarTugasProvider((tugasId: widget.tugasId, staff: widget.staff)));
      setState(() {
        _sending = false;
        _expanded = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      await showAkademikErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (tugasId: widget.tugasId, staff: widget.staff);
    final async = ref.watch(komentarTugasProvider(args));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Diskusi tugas',
          icon: Icons.forum_outlined,
          actionLabel: _expanded ? null : 'Tulis',
          onAction: _expanded ? null : () => setState(() => _expanded = true),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              async.when(
                loading: () => const AppLoading(message: 'Memuat diskusi…', compact: true),
                error: (e, _) => _inlineError(
                  e,
                  () => ref.invalidate(komentarTugasProvider(args)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Text(
                      'Belum ada komentar. Ajukan pertanyaan atau beri klarifikasi di sini.',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    );
                  }
                  return Column(
                    children: [
                      for (final row in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InitialsAvatar(name: row['author_nama']?.toString() ?? '?', size: 28),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            row['author_nama']?.toString() ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          row['author_role']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      row['isi']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 12.5, height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _isi,
                  maxLines: 3,
                  maxLength: 1500,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar…',
                    alignLabelWithHint: true,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _sending ? null : () => setState(() => _expanded = false),
                      child: const Text('Batal'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _sending ? null : _kirim,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(_sending ? 'Mengirim…' : 'Kirim'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Widget _inlineError(Object error, VoidCallback onRetry) {
  final app = error is AppError ? error : AppError.from(error);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        app.title,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.error),
      ),
      const SizedBox(height: 2),
      Text(app.message, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.xs),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Coba lagi'),
      ),
    ],
  );
}
