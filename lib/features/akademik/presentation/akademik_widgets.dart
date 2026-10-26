import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../domain/akademik_models.dart';

String formatTanggal(DateTime dt) => DateFormat('d MMM yyyy', 'id_ID').format(dt.toLocal());

String formatTanggalWaktu(DateTime dt) =>
    DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(dt.toLocal());

String formatJam(DateTime dt) => DateFormat('HH:mm', 'id_ID').format(dt.toLocal());

/// Warna aksen per tipe kalender.
Color kalenderColor(String tipe) => switch (tipe) {
      'libur' => AppColors.success,
      'ujian' => AppColors.error,
      'kegiatan' => AppColors.primary,
      'rapat' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

IconData kalenderIcon(String tipe) => switch (tipe) {
      'libur' => Icons.beach_access_rounded,
      'ujian' => Icons.quiz_rounded,
      'kegiatan' => Icons.celebration_rounded,
      'rapat' => Icons.groups_rounded,
      _ => Icons.event_rounded,
    };

IconData notifikasiIcon(String tipe) => switch (tipe) {
      'tugas' => Icons.assignment_rounded,
      'pengumuman' => Icons.campaign_rounded,
      'chat' => Icons.forum_rounded,
      'nilai' => Icons.grade_rounded,
      'kode' => Icons.key_rounded,
      _ => Icons.notifications_rounded,
    };

/// Kartu error yang menampilkan judul, pesan, dan saran dari [AppError]
/// (bukan pesan generik) plus tombol coba lagi.
class AkademikErrorView extends StatelessWidget {
  final Object error;
  final Future<void> Function()? onRetry;

  const AkademikErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final app = error is AppError ? error : AppError.from(error);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          color: AppColors.errorContainer,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      app.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.errorDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(app.message, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              if (app.hint != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(app.hint!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => onRetry!(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba lagi'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Snackbar pendek yang tidak menutupi tombol utama (floating + margin).
void akademikSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Header kecil di dalam kartu.
class AkademikMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const AkademikMeta({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: color ?? AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Menampilkan error sebagai dialog yang bisa ditutup (dipakai halaman form).
Future<void> showAkademikErrorDialog(BuildContext context, Object error) async {
  final app = error is AppError ? error : AppError.from(error);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(app.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.message, style: const TextStyle(fontSize: 13.5)),
          if (app.hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(app.hint!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Mengerti')),
      ],
    ),
  );
}

/// Pilihan tipe kalender.
Future<String?> pickKalenderTipe(BuildContext context, {String current = 'kegiatan'}) async {
  const tipe = ['kegiatan', 'ujian', 'libur', 'rapat', 'lainnya'];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Jenis agenda', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final t in tipe)
            ListTile(
              leading: Icon(kalenderIcon(t), color: kalenderColor(t)),
              title: Text(kalenderTipeLabel(t)),
              trailing: t == current ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    ),
  );
}

/// Tombol kecil bulat untuk aksi di AppBar.
class AkademikActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  const AkademikActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon));
    if (badge <= 0) return button;
    return Badge(
      label: Text(badge > 99 ? '99+' : '$badge'),
      backgroundColor: AppColors.error,
      child: button,
    );
  }
}

/// Menampilkan konfirmasi standar lalu menjalankan aksi.
Future<bool> confirmAkademik(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Lanjutkan',
  bool isDestructive = false,
}) {
  return showConfirmDialog(
    context,
    title: title,
    content: content,
    confirmLabel: confirmLabel,
    isDestructive: isDestructive,
  );
}
