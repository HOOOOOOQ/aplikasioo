import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/session_guard.dart';
import '../../../../core/utils/app_error.dart';
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
import '../../../akademik/data/akademik_providers.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../widgets/schema_health_dialog.dart';


class _DashboardData {
  final int siswa;
  final DashboardCounts counts;
  final List<Tugas> tugas;
  final List<AuditEntry> audit;

  /// Bagian yang gagal dimuat (mis. `tugas`/`audit`) tapi tidak fatal.
  final Map<String, AppError> issues;

  const _DashboardData({
    required this.siswa,
    required this.counts,
    required this.tugas,
    required this.audit,
    required this.issues,
  });

  bool get hasIssues => issues.isNotEmpty || counts.hasIssues;

  bool get schemaNotReady =>
      counts.schemaNotReady || issues.values.any((e) => e.code == 'schema_not_ready');
}

final adminDashboardProvider = FutureProvider.autoDispose<_DashboardData>((ref) async {
  final akun = ref.watch(akunRepositoryProvider);
  final issues = <String, AppError>{};

  /// Satu kartu yang gagal tidak boleh menjatuhkan seluruh halaman.
  /// Error sesi/jaringan tetap diteruskan agar UI meminta login/retry.
  Future<T> safe<T>(String key, Future<T> future, T fallback) async {
    try {
      return await future;
    } catch (e) {
      final error = AppError.from(e);
      if (SessionGuard.isSessionErrorCode(error.code) ||
          error.code == 'network' ||
          error.code == 'timeout') {
        rethrow;
      }
      issues[key] = error;
      return fallback;
    }
  }

  final results = await Future.wait<Object>([
    safe<int>('siswa', SiswaRepository().countAll(), 0),
    akun.fetchDashboardCounts(),
    safe<List<Tugas>>('tugas', TugasRepository().fetchAll(limit: 5), const <Tugas>[]),
    safe<List<AuditEntry>>('audit', akun.fetchAudit(limit: 6), const <AuditEntry>[]),
  ]);

  return _DashboardData(
    siswa: results[0] as int,
    counts: results[1] as DashboardCounts,
    tugas: results[2] as List<Tugas>,
    audit: results[3] as List<AuditEntry>,
    issues: issues,
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
            error: (e, _) {
              final error = AppError.from(e);
              if (SessionGuard.isSessionErrorCode(error.code)) {
                return _SessionExpiredView(error: error);
              }
              return AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(adminDashboardProvider),
                actionLabel: error.code == 'schema_not_ready' ? 'Periksa skema' : null,
                onAction: error.code == 'schema_not_ready'
                    ? () => showSchemaHealthDialog(context)
                    : null,
              );
            },
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
        if (data.hasIssues) ...[
          AppNotice.warning(
            title: data.schemaNotReady ? 'Skema database belum lengkap' : 'Sebagian data gagal dimuat',
            text: data.schemaNotReady
                ? 'Beberapa angka belum bisa dihitung karena tabel/fungsi database belum '
                    'tersedia. Jalankan migration 005, lalu tekan Periksa skema. Nilai yang '
                    'gagal dimuat ditampilkan sebagai "—", bukan 0.'
                : 'Nilai yang gagal dimuat ditampilkan sebagai "—" agar tidak menyesatkan. '
                    'Periksa daftar masalahnya, lalu muat ulang.',
            action: TextButton(
              onPressed: () => showSchemaHealthDialog(context),
              child: const Text('Periksa skema'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
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
              value: counts.has('guru') ? '${counts['guru']}' : '—',
              icon: Icons.badge_rounded,
              color: AppColors.info,
              background: AppColors.infoContainer,
              onTap: () => context.go('/admin/guru'),
            ),
            MetricTile(
              label: 'Kelas',
              value: counts.has('kelas') ? '${counts['kelas']}' : '—',
              icon: Icons.class_rounded,
              color: AppColors.success,
              background: AppColors.successContainer,
              onTap: () => context.go('/admin/kelas'),
            ),
            MetricTile(
              label: 'Tugas terbit',
              value: counts.has('tugas') ? '${counts['tugas']}' : '—',
              icon: Icons.assignment_rounded,
              color: AppColors.warning,
              background: AppColors.warningContainer,
              onTap: () => context.go('/admin/tugas'),
            ),
            MetricTile(
              label: 'Jadwal',
              value: counts.has('jadwal') ? '${counts['jadwal']}' : '—',
              icon: Icons.schedule_rounded,
              color: AppColors.primaryDark,
              onTap: () => context.go('/admin/jadwal'),
            ),
            MetricTile(
              label: 'Kode akses aktif',
              value: counts.has('kode_aktif') ? '${counts['kode_aktif']}' : '—',
              icon: Icons.key_rounded,
              color: AppColors.info,
              background: AppColors.infoContainer,
              caption: 'Terbit & belum dipakai',
              onTap: () => context.go('/admin/kode-akses'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const _AkademikStatsCard(),
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

/// Tampilan saat sesi benar-benar tidak valid (bukan error database/jaringan).
///
/// Aplikasi tidak mencoba "menyembuhkan" sesi dengan token buatan: admin
/// diminta masuk kembali melalui alur login resmi.
class _SessionExpiredView extends ConsumerWidget {
  final AppError error;

  const _SessionExpiredView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.lock_clock_rounded, size: 40, color: AppColors.warning),
          const SizedBox(height: AppSpacing.md),
          Text(
            error.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error.hint ?? error.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              ref.invalidate(currentUserProvider);
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Masuk kembali'),
          ),
        ],
      ),
    );
  }
}


/// Ringkasan akademik dari RPC `akademik_stats()` (migration 006).
///
/// Bila function belum ada di server, kartu menampilkan pesan yang jelas tanpa
/// mengganggu bagian dashboard lain.
class _AkademikStatsCard extends ConsumerWidget {
  const _AkademikStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(akademikStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Statistik akademik',
          icon: Icons.insights_rounded,
          actionLabel: async.isLoading ? null : 'Muat ulang',
          onAction: async.isLoading ? null : () => ref.invalidate(akademikStatsProvider),
        ),
        AppCard(
          child: async.when(
            loading: () => const AppLoading(message: 'Menghitung statistik…', compact: true),
            error: (e, _) {
              final app = e is AppError ? e : AppError.from(e);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warning),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.message,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Statistik muncul setelah migration 006 dijalankan di Supabase.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                  ),
                ],
              );
            },
            data: (stats) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Pengumpulan',
                        value: '${stats.pengumpulan}',
                        icon: Icons.upload_file_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Menunggu nilai',
                        value: '${stats.menungguNilai}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                        background: AppColors.warningContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Rata-rata nilai',
                        value: stats.rataNilai.toStringAsFixed(1),
                        icon: Icons.grade_rounded,
                        color: AppColors.success,
                        background: AppColors.successContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricTile(
                        label: 'Pengumuman',
                        value: '${stats.pengumumanTerbit}',
                        icon: Icons.campaign_rounded,
                        color: AppColors.info,
                        background: AppColors.infoContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
