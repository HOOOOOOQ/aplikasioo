import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deadline_helper.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../shared/models/kelas.dart';
import '../../../../shared/models/tugas.dart';
import '../../../../shared/repositories/kelas_repository.dart';
import '../../../../shared/repositories/mapel_repository.dart';
import '../../../../shared/repositories/tugas_repository.dart';
import '../../../../shared/models/mata_pelajaran.dart';
import '../../../../core/config/supabase_config.dart';
import '../../identity/student_identity_provider.dart';
import '../../../notifications/notification_service.dart';
import 'student_main_page.dart';

class StudentTaskListPage extends ConsumerStatefulWidget {
  const StudentTaskListPage({super.key});

  @override
  ConsumerState<StudentTaskListPage> createState() => _StudentTaskListPageState();
}

class _StudentTaskListPageState extends ConsumerState<StudentTaskListPage> {
  String? _kelasId;
  // Future di-cache per kelas: sebelumnya future dibuat ulang setiap build,
  // sehingga setiap ketikan di kolom cari memicu query ulang ke Supabase.
  Future<List<Tugas>>? _tugasFuture;
  String? _tugasFutureKey;
  String _search = '';
  String _filterStatus = 'Semua';
  String? _filterMapelId;
  final _searchC = TextEditingController();

  final List<String> _statusFilters = ['Semua', 'Belum selesai', 'Selesai', 'Mendekati tenggat', 'Terlambat'];

  @override
  void initState() {
    super.initState();
    final id = ref.read(studentIdentityProvider).kelasId;
    if (id != null) _kelasId = id;
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daftar Tugas'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/siswa')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search + kelas
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchC,
                        decoration: InputDecoration(
                          hintText: 'Cari judul tugas atau mata pelajaran...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _search = ''; _searchC.clear(); })) : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // FIX: provider — tanpa FutureBuilder yang recreate future tiap build + tanpa addPostFrameCallback di build
                Consumer(
                  builder: (ctx, ref, _) {
                    final kelasAsync = ref.watch(kelasListProvider);
                    return kelasAsync.when(
                      loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                      data: (list) {
                        if (list.isEmpty) {
                          if (SupabaseConfig.isNotConfigured) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Mode demo — pilih kelas akan aktif setelah Supabase dikonfigurasi', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            );
                          }
                          return const SizedBox();
                        }
                        final effectiveId = _kelasId ?? list.first.id;
                        return DropdownButtonFormField<String>(
                          value: effectiveId,
                          decoration: InputDecoration(prefixIcon: const Icon(Icons.class_outlined, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: list.map((k) => DropdownMenuItem(value: k.id, child: Text(k.namaKelas, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _kelasId = v),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Status filter
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final f = _statusFilters[i];
                      final sel = f == _filterStatus;
                      return ChoiceChip(label: Text(f, style: const TextStyle(fontSize: 12)), selected: sel, onSelected: (_) => setState(() => _filterStatus = f), selectedColor: AppColors.primaryContainer);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Mapel filter — guarded
                FutureBuilder<List<MataPelajaran>>(
                  future: _safeMapel(),
                  builder: (ctx, snap) {
                    if (!snap.hasData || snap.data == null) return const SizedBox();
                    final mapels = snap.data!;
                    if (mapels.isEmpty && SupabaseConfig.isNotConfigured) return const SizedBox();
                    return SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua Mapel', style: TextStyle(fontSize: 12)),
                            selected: _filterMapelId == null,
                            onSelected: (_) => setState(() => _filterMapelId = null),
                          ),
                          const SizedBox(width: 8),
                          for (final m in mapels)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(label: Text(m.namaMapel, style: const TextStyle(fontSize: 12)), selected: _filterMapelId == m.id, onSelected: (_) => setState(() => _filterMapelId = _filterMapelId == m.id ? null : m.id)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (ctx2, ref2, _) {
                final kelasAsync2 = ref2.watch(kelasListProvider);
                final eff = kelasAsync2.maybeWhen(data: (list) => list.isEmpty ? _kelasId : (_kelasId ?? list.first.id), orElse: () => _kelasId);
                if (eff == null) return const Center(child: Text('Pilih kelas'));
                return FutureBuilder<List<Tugas>>(
                    future: _futureFor(eff),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                      if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _refreshTugas);
                      var data = snap.data ?? [];
                      // Apply local filter status
                      data = _applyStatusFilter(data);
                      if (data.isEmpty) {
                        return EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'Tidak Ada Tugas',
                          subtitle: _search.isNotEmpty || _filterStatus != 'Semua' ? 'Tidak ada tugas yang sesuai filter. Coba ubah pencarian.' : 'Belum ada tugas untuk kelas ini.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: data.length,
                        itemBuilder: (ctx, i) => _TugasCard(tugas: data[i], onTap: () => context.push('/siswa/tugas/${data[i].id}')),
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

  Future<List<MataPelajaran>> _safeMapel() async {
    if (SupabaseConfig.isNotConfigured) return [];
    try {
      return await MapelRepository().fetchAll();
    } catch (_) {
      return [];
    }
  }

  Future<List<Tugas>> _futureFor(String effKelasId) {
    // Key ikut menyertakan filter mapel & search supaya hasil tetap benar,
    // tetapi future TIDAK dibuat ulang bila key sama (mis. rebuild karena setState lain).
    final key = '$effKelasId|$_filterMapelId';
    if (_tugasFutureKey == key && _tugasFuture != null) return _tugasFuture!;
    _tugasFutureKey = key;
    _tugasFuture = _fetchTugas(effKelasId);
    return _tugasFuture!;
  }

  void _refreshTugas() {
    setState(() {
      _tugasFutureKey = null;
      _tugasFuture = null;
    });
  }

  Future<List<Tugas>> _fetchTugas(String effKelasId) async {
    if (SupabaseConfig.isNotConfigured) return [];
    try {
      final identity = ref.read(studentIdentityProvider);
      final repo = TugasRepository();
      // Pencarian dilakukan lokal (instan, tanpa query per ketikan).
      final list = await repo.fetchAll(kelasId: effKelasId, search: null, mapelId: _filterMapelId, siswaId: identity.siswaId);
      // Jadwalkan pengingat tenggat (permission diminta di sini, bukan saat startup).
      unawaited(NotificationService.scheduleUpcoming(list));
      return list;
    } catch (_) {
      return [];
    }
  }

  List<Tugas> _applyStatusFilter(List<Tugas> list) {
    final q = _search.trim().toLowerCase();
    var filtered = list;
    if (q.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.judul.toLowerCase().contains(q) ||
            (t.mataPelajaranNama ?? '').toLowerCase().contains(q) ||
            (t.kelasNama ?? '').toLowerCase().contains(q);
      }).toList();
    }
    if (_filterStatus == 'Semua') return filtered;
    final identity = ref.read(studentIdentityProvider);
    final locals = ref.read(localTaskStatusProvider);
    return filtered.where((t) {
      final isCompleted = identity.isIdentified ? t.isCompleted : (locals[t.id] == 'selesai');
      final status = DeadlineHelper.getStatus(deadline: t.tenggatWaktu, isCompleted: isCompleted);
      switch (_filterStatus) {
        case 'Belum selesai':
          return !isCompleted;
        case 'Selesai':
          return isCompleted;
        case 'Mendekati tenggat':
          return status == DeadlineStatus.mendekatiTenggat;
        case 'Terlambat':
          return status == DeadlineStatus.terlambat;
        default:
          return true;
      }
    }).toList();
  }
}

class _TugasCard extends ConsumerWidget {
  final Tugas tugas;
  final VoidCallback onTap;
  const _TugasCard({required this.tugas, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(studentIdentityProvider);
    final locals = ref.watch(localTaskStatusProvider);
    final isCompleted = identity.isIdentified ? tugas.isCompleted : (locals[tugas.id] == 'selesai');
    final status = DeadlineHelper.getStatus(deadline: tugas.tenggatWaktu, isCompleted: isCompleted);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(6)), child: Text(tugas.mataPelajaranNama ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Kelas ${tugas.kelasNama ?? "-"}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(tugas.judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(tugas.deskripsi.length > 100 ? '${tugas.deskripsi.substring(0, 100)}...' : tugas.deskripsi, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(tugas.guruNama ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  const Icon(Icons.event, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(AppDateUtils.formatTanggalJam(tugas.tenggatWaktu), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(DeadlineHelper.iconForStatus(status), size: 12, color: DeadlineHelper.colorForStatus(status)),
                  const SizedBox(width: 4),
                  Text(AppDateUtils.relativeDeadline(tugas.tenggatWaktu), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DeadlineHelper.colorForStatus(status))),
                  const Spacer(),
                  TextButton(onPressed: onTap, child: const Text('Detail', style: TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
