import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_info.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';

class AboutPage extends StatelessWidget {
  /// Rute kembali bila halaman ini dibuka langsung (bukan via push).
  final String fallbackRoute;

  const AboutPage({super.key, this.fallbackRoute = '/siswa'});

  Future<void> _openInstagram(BuildContext context, String url, String handle) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppSnackBar(context, 'Tautan Instagram tidak valid.', isError: true);
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        showAppSnackBar(context, 'Tidak dapat membuka Instagram. Coba buka $handle secara manual.');
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Tidak dapat membuka Instagram. Coba buka $handle secara manual.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang EduTask'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          _buildHero(context),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Tentang aplikasi', icon: Icons.info_outline_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppInfo.description, style: const TextStyle(fontSize: 13, height: 1.55)),
                const SizedBox(height: AppSpacing.md),
                const _FeatureRow(icon: Icons.calendar_month_rounded, text: 'Jadwal pelajaran per kelas dan guru'),
                const _FeatureRow(icon: Icons.assignment_rounded, text: 'Tugas, lampiran, dan pengingat tenggat'),
                const _FeatureRow(icon: Icons.verified_user_rounded, text: 'Kode akses siswa untuk status tugas resmi'),
                const _FeatureRow(icon: Icons.insights_rounded, text: 'Laporan penyelesaian tugas untuk guru & admin'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppInfo.privacyNote,
                  style: const TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Tim pengembang', icon: Icons.groups_rounded),
          ...AppInfo.team.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    InitialsAvatar(name: member.name, size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(
                            member.role,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            member.instagramHandle,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buka Instagram ${member.name}',
                      onPressed: () => _openInstagram(context, member.instagramUrl, member.instagramHandle),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const SectionHeader(title: 'Institusi', icon: Icons.apartment_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                  title: Text(AppInfo.schoolName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(AppInfo.schoolInstagramHandle, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Instagram sekolah',
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    onPressed: () => _openInstagram(
                      context,
                      AppInfo.schoolInstagramUrl,
                      AppInfo.schoolInstagramHandle,
                    ),
                  ),
                ),
                const Divider(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code_rounded, color: AppColors.primary),
                  title: Text(
                    AppInfo.departmentName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(AppInfo.departmentInstagramHandle, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'Instagram jurusan',
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    onPressed: () => _openInstagram(
                      context,
                      AppInfo.departmentInstagramUrl,
                      AppInfo.departmentInstagramHandle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Kontak & dukungan', icon: Icons.support_agent_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Untuk masalah akun, kode akses, atau data sekolah, hubungi admin/guru '
                  'yang mengelola EduTask di sekolah Anda.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Aplikasi ini bukan aplikasi resmi sekolah. Status resmi hanya berlaku '
                  'untuk laporan yang tercatat di server EduTask.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Column(
              children: [
                Text(
                  AppInfo.teamMotto,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppInfo.copyright,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: AppColors.headerGradient,
      border: Border.all(color: Colors.transparent),
      child: Column(
        children: [
          const EduTaskLogo(size: 76, withShadow: false),
          const SizedBox(height: AppSpacing.md),
          const Text(
            AppInfo.appName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
          ),
          Text(
            AppInfo.tagline,
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Versi ${AppInfo.version} • ${AppInfo.packageName}',
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
