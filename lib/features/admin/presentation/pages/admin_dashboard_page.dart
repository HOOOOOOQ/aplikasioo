import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/akun_repository.dart';
import '../../../../shared/repositories/siswa_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../auth/presentation/auth_provider.dart';

class _DashboardData {
  final int siswa;
  final Map<String, int> counts;
  final List<Tugas> tugas;
  final List<AuditEntry> audit;

  const _DashboardData({
    required this.siswa,
    required this.counts,
    required this.tugas,
    required this.audit,
  });
}

final adminDashboardProvider = FutureProvider.autoDispose<_DashboardData>((ref) async {
  final akun = ref.watch(akunRepositoryProvider);
  final results = await Future.wait([
    SiswaRepository().countAll(),
    akun.fetchDashboardCounts(),
    TugasRepository().fetchAll(limit: 5),
    akun.fetchAudit(limit: 6),
  ]);

  return _DashboardData(
    siswa: results[0] as int,
    counts: results[1] as Map<String, int>,
    tugas: results[2] as List<Tugas>,
    audit: results[3] as List<AuditEntry>,
  );
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final now = AppDateUtils.nowJakarta();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDashboardProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
        children: [
          AppHeroHeader(
            eyebrow: '${AppDateUtils.hariIndonesia(now)}, ${AppDateUtils.formatTanggal(now)}',
            title: 'Halo, ${user?.fullName ?? 'Admin'}',
            subtitle: 'Ringkasan data sekolah hari ini.',
            trailing: IconButton(
              tooltip: 'Tentang aplikasi',
              onPressed: () => context.push('/tentang?from=admin'),
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            loading: () => const AppSkeletonList(count: 3),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(adminDashboardProvider),
            ),
            data: (data) => _buildContent(context, ref, data),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, _DashboardData data) {
    final counts = data.counts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.55,
          children: [
            MetricTile(
              label: 'Siswa aktif',
              value: '${data.siswa}',
              icon: Icons.people_rounded,
              onTap: () => context.go('/admin/siswa'),
            ),
            MetricTile(
              label: 'Guru aktif',
              value: '${counts['guru'] ?? 0}',
              icon: Icons.badge_rounded,
              color: AppColors.info,
              background: AppColors.infoContainer,
              onTap: () => context.go('/admin/guru'),
            ),
            MetricTile(
              label: 'Kelas',
              value: '${counts['kelas'] ?? 0}',
              icon: Icons.class_rounded,
              color: AppColors.success,
              background: AppColors.successContainer,
              onTap: () => context.go('/admin/kelas'),
            ),
            MetricTile(
              label: 'Tugas terbit',
              value: '${counts['tugas'] ?? 0}',
              icon: Icons.assignment_rounded,
              color: AppColors.warning,
              background: AppColors.warningContainer,
              onTap: () => context.go('/admin/tugas'),
            ),
            MetricTile(
              label: 'Jadwal',
              value: '${counts['jadwal'] ?? 0}',
              icon: Icons.schedule_rounded,
              color: AppColors.primaryDark,
              onTap: () => context.go('/admin/jadwal'),
            ),
            MetricTile(
              label: 'Kode akses aktif',
              value: '${counts['kode_aktif'] ?? 0}',
              icon: Icons.key_rounded,
              color: AppColors.info,
              background: AppColors.infoContainer,
              caption: 'Terbit & belum dipakai',
              onTap: () => context.go('/admin/kode-akses'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Aksi cepat', icon: Icons.bolt_rounded),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _QuickAction(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Tambah guru',
              onTap: () => context.go('/admin/guru'),
            ),
            _QuickAction(
              icon: Icons.group_add_rounded,
              label: 'Tambah siswa',
              onTap: () => context.go('/admin/siswa'),
            ),
            _QuickAction(
              icon: Icons.event_available_rounded,
              label: 'Atur jadwal',
              onTap: () => context.go('/admin/jadwal'),
            ),
            _QuickAction(
              icon: Icons.key_rounded,
              label: 'Terbitkan kode',
              onTap: () => context.go('/admin/kode-akses'),
            ),
            _QuickAction(
              icon: Icons.insights_rounded,
              label: 'Lihat laporan',
              onTap: () => context.go('/admin/laporan'),
            ),
            _QuickAction(
              icon: Icons.history_rounded,
              label: 'Audit log',
              onTap: () => context.go('/admin/audit'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Tugas terbaru',
          subtitle: '5 tugas dengan tenggat terdekat',
          actionLabel: 'Lihat semua',
          onAction: () => context.go('/admin/tugas'),
        ),
        if (data.tugas.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada tugas',
                subtitle: 'Tugas yang dibuat guru akan muncul di sini.',
              ),
            ),
          )
        else
          ...data.tugas.map((tugas) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => context.go('/admin/tugas'),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(Icons.assignment_rounded, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tugas.judul,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tugas.kelasNama ?? '-'} • ${tugas.mataPelajaranNama ?? '-'} • '
                              '${AppDateUtils.formatTanggalJam(tugas.tenggatWaktu)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusChip(
                        status: DeadlineHelper.getStatus(
                          deadline: tugas.tenggatWaktu,
                          isCompleted: false,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Aktivitas terbaru',
          subtitle: 'Perubahan data oleh admin & guru',
          actionLabel: 'Audit log',
          onAction: () => context.go('/admin/audit'),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: data.audit.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'Belum ada aktivitas',
                    subtitle: 'Perubahan data akan tercatat di sini.',
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.audit.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          _auditIcon(data.audit[i].action),
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          '${data.audit[i].actionLabel} ${data.audit[i].entityLabel}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${data.audit[i].actorName ?? 'Sistem'} • '
                          '${AppDateUtils.formatTanggalJam(data.audit[i].createdAt)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppNotice.info(
          text: 'Statistik dihitung langsung dari database. Jika angka terlihat tidak sesuai, '
              'tarik ke bawah untuk memuat ulang.',
          action: TextButton(
            onPressed: () => ref.invalidate(adminDashboardProvider),
            child: const Text('Muat ulang'),
          ),
        ),
      ],
    );
  }

  IconData _auditIcon(String action) {
    switch (action) {
      case 'insert':
        return Icons.add_circle_outline_rounded;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'issue':
        return Icons.key_rounded;
      case 'revoke':
        return Icons.block_rounded;
      default:
        return Icons.history_rounded;
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
