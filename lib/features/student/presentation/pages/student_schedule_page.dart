import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/jadwal_repository.dart';
import '../../../../shared/models/jadwal.dart';
import '../../../../core/config/supabase_config.dart';
import '../../identity/student_identity_provider.dart';
import 'student_main_page.dart';

class StudentSchedulePage extends ConsumerStatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  ConsumerState<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends ConsumerState<StudentSchedulePage> {
  String? _kelasId;
  String _selectedHari = 'Semua';
  final List<String> _hariList = ['Semua', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu', 'Hari Ini', 'Besok'];

  @override
  void initState() {
    super.initState();
    final id = ref.read(studentIdentityProvider).kelasId;
    if (id != null) _kelasId = id;
  }

  @override
  Widget build(BuildContext context) {
    final hariIni = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta());
    final besok = AppDateUtils.hariIndonesia(AppDateUtils.nowJakarta().add(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jadwal Pelajaran'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/siswa')),
      ),
      body: Column(
        children: [
          // FIX: kelas dipindah ke Riverpod provider — jangan buat Future baru tiap build + jangan setState di dalam build
          Consumer(
            builder: (ctx, ref, _) {
              final kelasAsync = ref.watch(kelasListProvider);
              return kelasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
                data: (list) {
                  if (list.isEmpty) {
                    if (SupabaseConfig.isNotConfigured) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Mode demo: data kelas akan muncul setelah Supabase dikonfigurasi', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                      );
                    }
                    return const SizedBox();
                  }
                  final effectiveId = _kelasId ?? list.first.id;
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                      value: effectiveId,
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.class_outlined), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas))).toList(),
                      onChanged: (v) => setState(() => _kelasId = v),
                    ),
                  );
                },
              );
            },
          ),

          // Hari filter
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _hariList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final h = _hariList[i];
                final selected = h == _selectedHari;
                return ChoiceChip(
                  label: Text(h),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedHari = h),
                  selectedColor: AppColors.primaryContainer,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Consumer(
              builder: (ctx2, ref2, _) {
                final kelasAsync2 = ref2.watch(kelasListProvider);
                final effectiveForFetch = kelasAsync2.maybeWhen(data: (list) => list.isEmpty ? _kelasId : (_kelasId ?? list.first.id), orElse: () => _kelasId);
                if (effectiveForFetch == null) return const Center(child: Text('Pilih kelas terlebih dahulu'));
                return FutureBuilder<List<Jadwal>>(
                    future: _fetchJadwal(effectiveForFetch, hariIni, besok),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                      if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: () => setState(() {}));
                      final data = snap.data ?? [];
                      if (data.isEmpty) {
                        return const EmptyState(icon: Icons.calendar_month_outlined, title: 'Belum Ada Jadwal', subtitle: 'Belum ada jadwal untuk filter ini. Hubungi admin untuk menambahkan jadwal.');
                      }
                      // Group by hari
                      final grouped = <String, List<Jadwal>>{};
                      for (final j in data) {
                        grouped.putIfAbsent(j.hari, () => []).add(j);
                      }
                      final orderedHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                      final sortedKeys = grouped.keys.toList()..sort((a, b) => orderedHari.indexOf(a).compareTo(orderedHari.indexOf(b)));

                      return ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final hari in sortedKeys) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: hari == hariIni ? AppColors.primary : AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)), child: Text(hari, style: TextStyle(fontWeight: FontWeight.w600, color: hari == hariIni ? Colors.white : AppColors.textPrimary, fontSize: 13))),
                                  if (hari == hariIni) const Padding(padding: EdgeInsets.only(left: 8), child: Text('• Hari ini', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600))),
                                  if (hari == besok) const Padding(padding: EdgeInsets.only(left: 8), child: Text('• Besok', style: TextStyle(color: AppColors.info, fontSize: 12))),
                                ],
                              ),
                            ),
                            for (final j in grouped[hari] ?? const [])
                              Card(
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
                                    child: Text('${AppDateUtils.formatJamFromString(j.jamMulai)}\n${AppDateUtils.formatJamFromString(j.jamSelesai)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary), textAlign: TextAlign.center),
                                  ),
                                  title: Text(j.mataPelajaranNama ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('${j.guruNama ?? "-"} • ${j.kelasNama ?? "-"} • Ruang ${j.ruang ?? "-"}', style: const TextStyle(fontSize: 12)),
                                  trailing: hari == hariIni ? const Icon(Icons.today, color: AppColors.success, size: 18) : null,
                                ),
                              ),
                          ],
                        ],
                      );
                    },
                  );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Jadwal>> _fetchJadwal(String kelasId, String hariIni, String besok) async {
    if (SupabaseConfig.isNotConfigured) return [];
    try {
      String? hariFilter;
      if (_selectedHari != 'Semua' && _selectedHari != 'Hari Ini' && _selectedHari != 'Besok') {
        hariFilter = _selectedHari;
      } else if (_selectedHari == 'Hari Ini') {
        hariFilter = hariIni;
      } else if (_selectedHari == 'Besok') {
        hariFilter = besok;
      }
      final repo = JadwalRepository();
      return await repo.fetchAll(kelasId: kelasId, hari: hariFilter);
    } catch (_) {
      return [];
    }
  }
}
