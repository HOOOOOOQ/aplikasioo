import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_banner.dart';

/// Header gradien untuk dashboard dan halaman utama.
class AppHeroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final Widget? footer;
  final LinearGradient gradient;
  final bool compact;

  const AppHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.footer,
    this.gradient = AppColors.headerGradient,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        compact ? AppSpacing.lg : AppSpacing.xl,
        AppSpacing.xl,
        compact ? AppSpacing.lg : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EduTaskLogo(size: 42, withShadow: false),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          eyebrow!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Kotak pencarian dengan tombol bersihkan.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Cari…',
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                        onClear?.call();
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
