import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/app_error.dart';

/// Loading sederhana namun konsisten (bukan spinner polos di tengah layar).
class AppLoading extends StatelessWidget {
  final String? message;
  final bool compact;
  const AppLoading({super.key, this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder untuk daftar yang masih dimuat.
class AppSkeletonList extends StatelessWidget {
  final int count;
  const AppSkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(width: 160, height: 14),
              const SizedBox(height: AppSpacing.sm),
              _bar(width: double.infinity, height: 10),
              const SizedBox(height: AppSpacing.xs),
              _bar(width: 210, height: 10),
            ],
          ),
        );
      }),
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, this.error, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final appError = error == null
        ? AppError(title: 'Terjadi kesalahan', message: message ?? 'Data gagal dimuat.')
        : AppError.from(error!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            appError.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            appError.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
          if (appError.hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              appError.hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pemberitahuan sebaris (banner) dengan empat tingkatan.
class AppNotice extends StatelessWidget {
  final String text;
  final String? title;
  final IconData icon;
  final Color color;
  final Color background;
  final Widget? action;

  const AppNotice({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.info,
    this.background = AppColors.infoContainer,
    this.action,
  });

  const AppNotice.info({super.key, required this.text, this.title, this.action})
      : icon = Icons.info_outline_rounded,
        color = AppColors.info,
        background = AppColors.infoContainer;

  const AppNotice.success({super.key, required this.text, this.title, this.action})
      : icon = Icons.check_circle_outline_rounded,
        color = AppColors.success,
        background = AppColors.successContainer;

  const AppNotice.warning({super.key, required this.text, this.title, this.action})
      : icon = Icons.warning_amber_rounded,
        color = AppColors.warning,
        background = AppColors.warningContainer;

  const AppNotice.error({super.key, required this.text, this.title, this.action})
      : icon = Icons.error_outline_rounded,
        color = AppColors.error,
        background = AppColors.errorContainer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
