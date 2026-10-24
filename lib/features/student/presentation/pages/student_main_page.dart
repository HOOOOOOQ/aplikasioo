import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../identity/student_identity_provider.dart';

final kelasListProvider = FutureProvider<List<Kelas>>((ref) async {
  if (SupabaseConfig.isNotConfigured) return [];
  return KelasRepository().fetchAll();
});

final studentJadwalProvider = FutureProvider.family<List<Jadwal>, String>((ref, kelasId) async {
  if (SupabaseConfig.isNotConfigured) return [];
  if (kelasId.isEmpty) return [];
  final hari = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
  // ambil semua jadwal kelas, filter hari ini di UI juga tampil semua
  return JadwalRepository().fetchByKelas(kelasId);
});

final studentTugasProvider = FutureProvider.family<List<Tugas>, String>((ref, kelasId) async {
  if (SupabaseConfig.isNotConfigured) return [];
  if (kelasId.isEmpty) return [];
  final identity = ref.watch(studentIdentityProvider);
  return TugasRepository().fetchAll(kelasId: kelasId, siswaId: identity.siswaId);
});

class StudentMainPage extends ConsumerStatefulWidget {
  const StudentMainPage({super.key});

  @override
  ConsumerState<StudentMainPage> createState() => _StudentMainPageState();
}

class _StudentMainPageState extends ConsumerState<StudentMainPage> {
  int _navIndex = 0;
  String? _selectedKelasId;
  String? _selectedKelasNama;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identity = ref.read(studentIdentityProvider);
      if (identity.kelasId != null) {
        setState(() {
          _selectedKelasId = identity.kelasId;
          _selectedKelasNama = identity.kelasNama;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kelasAsync = ref.watch(kelasListProvider);
    final identity = ref.watch(studentIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.school, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EduTask', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Tugas & Jadwal Sekolah', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.person_outline, color: Colors.white), onPressed: () => context.push('/siswa/identitas')),
          IconButton(icon: const Icon(Icons.login, color: Colors.white), onPressed: () => context.push('/login')),
        ],
      ),
      body: kelasAsync.when(
        loading: () => const LoadingView(message: 'Memuat data kelas...'),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.refresh(kelasListProvider)),
        data: (kelasList) {
          if (SupabaseConfig.isNotConfigured) {
            return _buildNotConfigured();
          }
          if (kelasList.isEmpty) {
            return const EmptyState(icon: Icons.class_outlined, title: 'Belum Ada Kelas', subtitle: 'Admin belum menambahkan data kelas. Hubungi admin sekolah.');
          }
          // Auto-select first if none
          if (_selectedKelasId == null && kelasList.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedKelasId = kelasList.first.id;
                _selectedKelasNama = kelasList.first.namaKelas;
              });
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal hari ini
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta()), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text(DateFormat('dd MMMM yyyy', 'id_ID').format(AppDateUtils.nowJakarta()), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            if (identity.isIdentified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text('Halo, ${identity.siswaNama}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              )
                            else
                              GestureDetector(
                                onTap: () => context.push('/siswa/identitas'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Verifikasi identitas untuk laporan resmi', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.calendar_today, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pilih kelas
                Row(
                  children: [
                    const Text('Pilih Kelas:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKelasId,
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: kelasList.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) {
                          final k = kelasList.firstWhere((e) => e.id == v);
                          setState(() {
                            _selectedKelasId = v;
                            _selectedKelasNama = k.namaKelas;
                          });
                          ref.read(studentIdentityProvider.notifier).setKelas(k.id, kelasNama: k.namaKelas);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_selectedKelasId != null) ...[
                  _buildJadwalHariIni(_selectedKelasId!),
                  const SizedBox(height: 16),
                  _buildTugasTerbaru(_selectedKelasId!),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 0:
              break;
            case 1:
              context.push('/siswa/jadwal');
              break;
            case 2:
              context.push('/siswa/tugas');
              break;
            case 3:
              context.push('/siswa/tentang');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'Tentang'),
        ],
      ),
    );
  }

  Widget _buildNotConfigured() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.warning)),
            child: const Column(
              children: [
                Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.warning),
                SizedBox(height: 8),
                Text('Supabase Belum Dikonfigurasi', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text(
                  'Aplikasi belum terhubung ke database online. Admin perlu mengatur SUPABASE_URL dan SUPABASE_ANON_KEY melalui --dart-define.\n\nLihat README.md untuk panduan.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preview Fitur Siswa (Mode Offline Demo)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _demoItem('Jadwal Hari Ini', 'Senin — Matematika 07:30-08:30, Bahasa Indonesia 08:30-09:30', Icons.schedule),
                  _demoItem('Tugas Terbaru', 'Tugas Matematika: Latihan Bab 1 — Tenggat 2 hari lagi', Icons.assignment),
                  _demoItem('Status', 'Mendekati tenggat akan berwarna oranye, terlambat merah, selesai hijau', Icons.info_outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoItem(String t, String s, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(s, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
        ],
      ),
    );
  }

  Widget _buildJadwalHariIni(String kelasId) {
    final asyncJadwal = ref.watch(studentJadwalProvider(kelasId));
    return asyncJadwal.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
      error: (e, _) => Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Gagal memuat jadwal: $e'))),
      data: (list) {
        final hariIni = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
        final todayList = list.where((j) => j.hari == hariIni).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Jadwal Hari Ini — $hariIni', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(onPressed: () => context.push('/siswa/jadwal'), child: const Text('Lihat Semua')),
                  ],
                ),
                const Divider(),
                if (todayList.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('Tidak ada jadwal untuk hari ini.', style: TextStyle(color: AppColors.textSecondary))),
                for (final j in todayList)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          child: Text('${AppDateUtils.formatJamFromString(j.jamMulai)}\n${AppDateUtils.formatJamFromString(j.jamSelesai)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(j.mataPelajaranNama ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${j.guruNama ?? "-"} • ${j.ruang ?? "-"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTugasTerbaru(String kelasId) {
    final asyncTugas = ref.watch(studentTugasProvider(kelasId));
    return asyncTugas.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
      error: (e, _) => Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Gagal memuat tugas: $e'))),
      data: (list) {
        if (list.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Tugas Terbaru', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const EmptyState(icon: Icons.assignment_outlined, title: 'Belum Ada Tugas', subtitle: 'Guru belum memberikan tugas untuk kelas ini.'),
                ],
              ),
            ),
          );
        }
        // Categorize
        final identity = ref.read(studentIdentityProvider);
        final localStatuses = ref.watch(localTaskStatusProvider);
        List<Tugas> withStatus(String filter) {
          return list.where((t) {
            final isCompleted = identity.isIdentified ? t.isCompleted : (localStatuses[t.id] == 'selesai');
            final status = DeadlineHelper.getStatus(deadline: t.tenggatWaktu, isCompleted: isCompleted);
            if (filter == 'terlambat') return status == DeadlineStatus.terlambat;
            if (filter == 'mendekati') return status == DeadlineStatus.mendekatiTenggat;
            return true;
          }).toList();
        }

        final terlambat = withStatus('terlambat');
        final mendekati = withStatus('mendekati');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (terlambat.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error)),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${terlambat.length} tugas terlambat — segera selesaikan!', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12))),
                    TextButton(onPressed: () => context.push('/siswa/tugas'), child: const Text('Lihat')),
                  ],
                ),
              ),
            if (mendekati.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${mendekati.length} tugas mendekati tenggat (24 jam)', style: const TextStyle(color: AppColors.warningDark, fontWeight: FontWeight.w600, fontSize: 12))),
                  ],
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Tugas Terbaru', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(onPressed: () => context.push('/siswa/tugas'), child: const Text('Lihat Semua')),
                      ],
                    ),
                    const Divider(),
                    for (final t in list.take(5))
                      _TugasCardCompact(tugas: t, onTap: () => context.push('/siswa/tugas/${t.id}')),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TugasCardCompact extends ConsumerWidget {
  final Tugas tugas;
  final VoidCallback onTap;
  const _TugasCardCompact({required this.tugas, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(studentIdentityProvider);
    final localStatuses = ref.watch(localTaskStatusProvider);
    final isCompleted = identity.isIdentified ? tugas.isCompleted : (localStatuses[tugas.id] == 'selesai');
    final status = DeadlineHelper.getStatus(deadline: tugas.tenggatWaktu, isCompleted: isCompleted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tugas.judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${tugas.mataPelajaranNama ?? "-"} • ${tugas.guruNama ?? "-"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('Tenggat: ${AppDateUtils.formatTanggalJam(tugas.tenggatWaktu)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                const Spacer(),
                Text(AppDateUtils.relativeDeadline(tugas.tenggatWaktu), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DeadlineHelper.colorForStatus(status))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
