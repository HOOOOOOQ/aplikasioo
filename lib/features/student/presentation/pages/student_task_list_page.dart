import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/tugas.dart';
import '../../../notifications/notification_service.dart';
import '../../identity/student_identity_provider.dart';
import 'student_main_page.dart';

class StudentTaskListPage extends ConsumerStatefulWidget {
  const StudentTaskListPage({super.key});

  @override
  ConsumerState<StudentTaskListPage> createState() => _StudentTaskListPageState();
}

class _StudentTaskListPageState extends ConsumerState<StudentTaskListPage> {
  final TextEditingController _searchC = TextEditingController();
  String _search = '';
  String _filter = 'semua';

  /// Pengingat tenggat dijadwalkan sekali per kunjungan, setelah daftar tugas
  /// berhasil dimuat (bukan saat startup) agar tidak meminta izin terlalu dini.
  bool _remindersSynced = false;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    final localStatus = ref.watch(localTaskStatusProvider);
    final kelasAsync = ref.watch(kelasListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tugas')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/siswa');
          if (index == 1) context.go('/siswa/jadwal');
          if (index == 3) context.push('/siswa/identitas');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Identitas'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kelasListProvider);
          ref.invalidate(studentTasksProvider);
          await ref.read(kelasListProvider.future);
        },
        child: kelasAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 4)],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              AppErrorState(error: e, onRetry: () => ref.invalidate(kelasListProvider)),
            ],
          ),
          data: (kelasList) {
            if (kelasList.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SizedBox(height: AppSpacing.xxl),
                  AppCard(
                    child: AppEmptyState(
                      icon: Icons.class_outlined,
                      title: 'Belum ada kelas',
                      subtitle: 'Tugas akan muncul setelah admin menambahkan kelas Anda.',
                    ),
                  ),
                ],
              );
            }

            final kelasId = effectiveKelasId(ref, kelasList);
            final kelasAktif = kelasList.firstWhere((k) => k.id == kelasId, orElse: () => kelasList.first);
            final tugasAsync = ref.watch(studentTasksProvider(kelasId ?? ''));

            return tugasAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [SizedBox(height: AppSpacing.xl), AppSkeletonList(count: 4)],
              ),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  AppErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(studentTasksProvider(kelasAktif.id)),
                  ),
                ],
              ),
              data: (all) {
                if (!_remindersSynced) {
                  _remindersSynced = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final prefs = ref.read(appPreferencesProvider);
                    NotificationService.scheduleUpcoming(
                      all,
                      enabled: prefs.deadlineReminders,
                    );
                  });
                }

                var list = all;
                if (_filter == 'selesai') {
                  list = list
                      .where((t) => t.statusSiswa == 'selesai' || localStatus[t.id] == 'selesai')
                      .toList();
                } else if (_filter == 'belum') {
                  list = list
                      .where((t) => !(t.statusSiswa == 'selesai' || localStatus[t.id] == 'selesai'))
                      .toList();
                }
                if (_search.trim().isNotEmpty) {
                  final needle = _search.trim().toLowerCase();
                  list = list
                      .where((t) =>
                          t.judul.toLowerCase().contains(needle) ||
                          (t.mataPelajaranNama?.toLowerCase().contains(needle) ?? false))
                      .toList();
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    AppHeroHeader(
                      compact: true,
                      eyebrow: '${kelasAktif.namaKelas} • ${all.length} tugas',
                      title: 'Daftar Tugas',
                      subtitle: identity.isIdentified
                          ? 'Status resmi tercatat di server.'
                          : 'Belum terverifikasi — status tersimpan di perangkat ini saja.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSearchField(
                      controller: _searchC,
                      hint: 'Cari judul atau mata pelajaran…',
                      onChanged: (value) => setState(() => _search = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _filter == 'semua',
                          onSelected: (_) => setState(() => _filter = 'semua'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: const Text('Belum selesai'),
                          selected: _filter == 'belum',
                          onSelected: (selected) => setState(() => _filter = selected ? 'belum' : 'semua'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: const Text('Selesai'),
                          selected: _filter == 'selesai',
                          onSelected: (selected) => setState(() => _filter = selected ? 'selesai' : 'semua'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (all.isEmpty)
                      const AppCard(
                        child: AppEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'Belum ada tugas',
                          subtitle: 'Guru belum menerbitkan tugas untuk kelas ini.',
                        ),
                      )
                    else if (list.isEmpty)
                      AppCard(
                        child: AppEmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: 'Tidak ada tugas yang cocok',
                          subtitle: 'Ubah filter atau kata pencarian.',
                          actionLabel: 'Reset filter',
                          onAction: () => setState(() {
                            _filter = 'semua';
                            _search = '';
                            _searchC.clear();
                          }),
                        ),
                      )
                    else
                      ...list.map((tugas) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _TugasCard(
                              tugas: tugas,
                              localStatus: localStatus[tugas.id],
                              onTap: () => context.push('/siswa/tugas/${tugas.id}'),
                            ),
                          )),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TugasCard extends StatelessWidget {
  final Tugas tugas;
  final String? localStatus;
  final VoidCallback onTap;

  const _TugasCard({required this.tugas, required this.localStatus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final official = tugas.statusSiswa == 'selesai';
    final local = localStatus == 'selesai';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tugas.judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (tugas.hasLampiran)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${tugas.mataPelajaranNama ?? '-'} • ${tugas.guruNama ?? '-'}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                status: DeadlineHelper.getStatus(
                  deadline: tugas.tenggatWaktu,
                  isCompleted: official || local,
                ),
              ),
              MetaPill(
                label: AppDateUtils.formatTanggal(tugas.tenggatWaktu),
                icon: Icons.event_outlined,
              ),
              if (official)
                const StatusSourceBadge(official: true)
              else if (local)
                const StatusSourceBadge(official: false),
            ],
          ),
        ],
      ),
    );
  }
}
