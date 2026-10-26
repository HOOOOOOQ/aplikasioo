import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/deadline_helper.dart';

/// Label status tenggat tugas (selesai / mendekati tenggat / terlambat / aktif).
class StatusChip extends StatelessWidget {
  final DeadlineStatus status;
  final String? customLabel;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.status,
    this.customLabel,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = DeadlineHelper.colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(DeadlineHelper.iconForStatus(status), size: fontSize + 1, color: color),
          const SizedBox(width: 4),
          Text(
            customLabel ?? DeadlineHelper.labelForStatus(status),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menjelaskan apakah status tugas tersimpan di server (terlihat guru)
/// atau hanya di perangkat ini. Ini mencegah siswa salah paham.
class StatusSourceBadge extends StatelessWidget {
  final bool official;
  final bool compact;

  const StatusSourceBadge({super.key, required this.official, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = official ? AppColors.success : AppColors.textSecondary;
    final bg = official ? AppColors.successContainer : AppColors.surfaceVariant;
    final label = official ? 'Tercatat di server' : 'Hanya di perangkat';
    final icon = official ? Icons.cloud_done_outlined : Icons.phone_android_rounded;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label netral dengan ikon (dipakai untuk kelas, mapel, dsb).
class MetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const MetaPill({super.key, required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}
