import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Banner logo EduTask — dipakai di Splash, AppBar, Login, Drawer, Tentang
class EduTaskLogo extends StatelessWidget {
  final double size;
  final bool withShadow;
  const EduTaskLogo({super.key, this.size = 80, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: withShadow ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/edutask_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, _, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(size * 0.22)),
          child: Icon(Icons.school_rounded, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

class EduTaskBanner extends StatelessWidget {
  final double height;
  final bool compact;
  const EduTaskBanner({super.key, this.height = 48, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EduTaskLogo(size: 36, withShadow: false),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('EduTask', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85))),
            ],
          ),
        ],
      );
    }
    return Container(
      height: height + 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Image.asset(
        'assets/images/edutask_banner.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (ctx, _, __) => Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EduTask', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full width header banner with gradient background — untuk AppBar/header
class EduTaskHeaderBanner extends StatelessWidget {
  final bool isAppBar;
  const EduTaskHeaderBanner({super.key, this.isAppBar = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isAppBar ? 0 : 16, vertical: isAppBar ? 0 : 12),
      decoration: isAppBar ? null : const BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Row(
        children: [
          Container(
            width: isAppBar ? 36 : 44,
            height: isAppBar ? 36 : 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/edutask_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.school, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EduTask', style: TextStyle(fontSize: isAppBar ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: isAppBar ? 11 : 12, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
          if (!isAppBar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Resmi', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
