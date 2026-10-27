import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../student/identity/student_identity_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

/// Daftar guru yang mengajar di kelas siswa beserta tombol chat.
///
/// Data diambil dari Edge Function bertoken (`student-chat` → `guru_list`),
/// sehingga daftar ini tidak dapat dipalsukan dari sisi klien dan hanya
/// memuat guru yang benar-benar terhubung dengan kelas siswa.
final guruKelasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final gateway = ref.watch(studentGatewayProvider);
  if (!gateway.hasIdentity) return const [];
  return gateway.fetchGuruKelas();
});

class GuruKelasPage extends ConsumerStatefulWidget {
  const GuruKelasPage({super.key});

  @override
  ConsumerState<GuruKelasPage> createState() => _GuruKelasPageState();
}

class _GuruKelasPageState extends ConsumerState<GuruKelasPage> {
  String? _busyId;

  Future<void> _chat(String guruId, String nama) async {
    if (_busyId != null) return;
    setState(() => _busyId = guruId);
    try {
      final thread = await ref.read(studentGatewayProvider).openThread(tipe: 'direct', guruId: guruId);
      if (!mounted) return;
      setState(() => _busyId = null);
      if (thread != null) {
        await context.push('/siswa/chat/${thread.id}?judul=${Uri.encodeComponent(nama)}');
        ref.invalidate(chatThreadsProvider(AkademikAudience.siswa));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      await showAkademikErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final async = ref.watch(guruKelasProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Guru Kelas')),
      body: !identity.isIdentified
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SizedBox(height: 40),
                EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'Identitas belum terhubung',
                  subtitle: 'Hubungkan identitas dengan kode akses untuk melihat guru kelas Anda.',
                  actionLabel: 'Hubungkan identitas',
                  onAction: () => context.go('/siswa/identitas'),
                ),
              ],
            )
          : async.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 4)],
              ),
              error: (e, _) => AkademikErrorView(
                error: e,
                onRetry: () async => ref.invalidate(guruKelasProvider),
              ),
              data: (guru) {
                if (guru.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: const [
                      SizedBox(height: 40),
                      EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'Belum ada guru terhubung',
                        subtitle: 'Guru akan muncul di sini setelah admin menambahkan jadwal pelajaran '
                            'atau menetapkan wali kelas untuk kelas Anda.',
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(guruKelasProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      if (identity.kelasNama != null) ...[
                        AppCard(
                          color: AppColors.primaryContainer,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              const Icon(Icons.class_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Kelas ${identity.kelasNama}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              Text(
                                '${guru.length} guru',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (final g in guru)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                InitialsAvatar(name: g['full_name']?.toString() ?? 'G', size: 40),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g['full_name']?.toString() ?? 'Guru',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Guru pengampu kelas Anda',
                                        style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _busyId == null
                                      ? () => _chat(
                                            g['id'].toString(),
                                            g['full_name']?.toString() ?? 'Guru',
                                          )
                                      : null,
                                  icon: _busyId == g['id']
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                  label: const Text('Chat'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
