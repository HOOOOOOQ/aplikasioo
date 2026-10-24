import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'date_utils.dart';

enum DeadlineStatus { selesai, terlambat, mendekatiTenggat, normal }

class DeadlineHelper {
  static const int warningHours = 24;

  static DeadlineStatus getStatus({
    required DateTime? deadline,
    required bool isCompleted,
  }) {
    if (isCompleted) return DeadlineStatus.selesai;
    if (deadline == null) return DeadlineStatus.normal;
    final now = AppDateUtils.nowJakarta();
    final jktDeadline = AppDateUtils.toJakarta(deadline);
    if (jktDeadline.isBefore(now)) return DeadlineStatus.terlambat;
    final diff = jktDeadline.difference(now);
    if (diff.inHours < warningHours) return DeadlineStatus.mendekatiTenggat;
    return DeadlineStatus.normal;
  }

  static Color colorForStatus(DeadlineStatus status) {
    switch (status) {
      case DeadlineStatus.selesai:
        return AppColors.success;
      case DeadlineStatus.terlambat:
        return AppColors.error;
      case DeadlineStatus.mendekatiTenggat:
        return AppColors.warning;
      case DeadlineStatus.normal:
        return AppColors.primary;
    }
  }

  static Color bgForStatus(DeadlineStatus status) {
    switch (status) {
      case DeadlineStatus.selesai:
        return AppColors.successContainer;
      case DeadlineStatus.terlambat:
        return AppColors.errorContainer;
      case DeadlineStatus.mendekatiTenggat:
        return AppColors.warningContainer;
      case DeadlineStatus.normal:
        return AppColors.primaryContainer;
    }
  }

  static String labelForStatus(DeadlineStatus status) {
    switch (status) {
      case DeadlineStatus.selesai:
        return 'Selesai';
      case DeadlineStatus.terlambat:
        return 'Terlambat';
      case DeadlineStatus.mendekatiTenggat:
        return 'Mendekati Tenggat';
      case DeadlineStatus.normal:
        return 'Aktif';
    }
  }

  static IconData iconForStatus(DeadlineStatus status) {
    switch (status) {
      case DeadlineStatus.selesai:
        return Icons.check_circle;
      case DeadlineStatus.terlambat:
        return Icons.error;
      case DeadlineStatus.mendekatiTenggat:
        return Icons.warning_amber_rounded;
      case DeadlineStatus.normal:
        return Icons.schedule;
    }
  }
}
