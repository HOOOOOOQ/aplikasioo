import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/status_tugas.dart';
import '../models/tugas.dart';
import '../services/supabase_service.dart';

/// Ringkasan penyelesaian satu tugas untuk laporan.
class TugasReportRow {
  final Tugas tugas;
  final int totalSiswa;
  final int selesai;
  final int terlambat;

  const TugasReportRow({
    required this.tugas,
    required this.totalSiswa,
    required this.selesai,
    required this.terlambat,
  });

  int get belum => (totalSiswa - selesai).clamp(0, totalSiswa);
  double get persen => totalSiswa == 0 ? 0 : (selesai / totalSiswa) * 100;
}

class TugasRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  static const String _joins =
      '*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!tugas_guru_id_fkey(full_name)';

  Future<List<Tugas>> fetchAll({
    String? kelasId,
    String? guruId,
    String? mapelId,
    String? search,
    String? siswaId,
    String statusPublikasi = 'published',
    int? limit,
  }) async {
    final c = _c;
    if (c == null) return const [];

    var query = c.from('tugas').select(_joins);
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);
    if (guruId != null && guruId.isNotEmpty) query = query.eq('guru_id', guruId);
    if (mapelId != null && mapelId.isNotEmpty) query = query.eq('mata_pelajaran_id', mapelId);
    if (statusPublikasi.isNotEmpty) query = query.eq('status_publikasi', statusPublikasi);

    var rows = await query.order('tenggat_waktu', ascending: true);
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);

    var list = rows.map((e) => Tugas.fromJson(Map<String, dynamic>.from(e))).toList();

    if (siswaId != null && siswaId.isNotEmpty && list.isNotEmpty) {
      final ids = list.map((t) => t.id).toList();
      final statusRows = await c
          .from('status_tugas_siswa')
          .select('tugas_id, status, selesai_pada')
          .inFilter('tugas_id', ids)
          .eq('siswa_id', siswaId);

      final byTugas = <String, Map<String, dynamic>>{
        for (final row in statusRows) row['tugas_id'] as String: Map<String, dynamic>.from(row),
      };

      list = list.map((t) {
        final status = byTugas[t.id];
        if (status == null) return t;
        return t.copyWith(
          statusSiswa: status['status'] as String?,
          selesaiPada: status['selesai_pada'] == null
              ? null
              : DateTime.tryParse(status['selesai_pada'] as String),
        );
      }).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      list = list
          .where((t) =>
              t.judul.toLowerCase().contains(needle) ||
              (t.mataPelajaranNama?.toLowerCase().contains(needle) ?? false) ||
              (t.kelasNama?.toLowerCase().contains(needle) ?? false) ||
              (t.guruNama?.toLowerCase().contains(needle) ?? false))
          .toList();
    }

    return list;
  }

  Future<Tugas?> fetchById(String id, {String? siswaId}) async {
    final c = _c;
    if (c == null) return null;
    final data = await c.from('tugas').select(_joins).eq('id', id).maybeSingle();
    if (data == null) return null;

    var tugas = Tugas.fromJson(Map<String, dynamic>.from(data));
    if (siswaId != null && siswaId.isNotEmpty) {
      final status = await c
          .from('status_tugas_siswa')
          .select('status, selesai_pada')
          .eq('tugas_id', id)
          .eq('siswa_id', siswaId)
          .maybeSingle();
      if (status != null) {
        tugas = tugas.copyWith(
          statusSiswa: status['status'] as String?,
          selesaiPada: status['selesai_pada'] == null
              ? null
              : DateTime.tryParse(status['selesai_pada'] as String),
        );
      }
    }
    return tugas;
  }

  Future<Tugas> create(Map<String, dynamic> payload) async {
    final c = SupabaseService.tryClient;
    if (c == null) {
      throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    }
    final res = await c.from('tugas').insert(payload).select(_joins).single();
    return Tugas.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Tugas> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) {
      throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    }
    final res = await c.from('tugas').update(patch).eq('id', id).select(_joins).single();
    return Tugas.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('tugas').delete().eq('id', id);
  }

  Future<List<StatusTugasSiswa>> fetchStatusForTugas(String tugasId) async {
    final c = _c;
    if (c == null) return const [];
    final data = await c
        .from('status_tugas_siswa')
        .select('*, siswa(nama)')
        .eq('tugas_id', tugasId)
        .order('updated_at', ascending: false);
    return data.map((e) => StatusTugasSiswa.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Hitungan total/selesai untuk satu tugas (dipakai halaman status guru).
  Future<Map<String, int>> fetchSummary(String tugasId) async {
    final c = _c;
    if (c == null) return {'total': 0, 'selesai': 0, 'belum': 0};

    final tugas = await c.from('tugas').select('kelas_id').eq('id', tugasId).maybeSingle();
    if (tugas == null) return {'total': 0, 'selesai': 0, 'belum': 0};

    final kelasId = tugas['kelas_id'] as String? ?? '';
    if (kelasId.isEmpty) return {'total': 0, 'selesai': 0, 'belum': 0};

    final siswaRows = await c
        .from('siswa')
        .select('id')
        .eq('kelas_id', kelasId)
        .eq('status_aktif', true);
    final total = siswaRows.length;

    final selesaiRows = await c
        .from('status_tugas_siswa')
        .select('id')
        .eq('tugas_id', tugasId)
        .eq('status', 'selesai');
    final selesai = selesaiRows.length;

    return {'total': total, 'selesai': selesai, 'belum': (total - selesai).clamp(0, total)};
  }

  /// Laporan agregat untuk admin/guru. Mengambil tugas lalu semua status
  /// sekaligus (dua query, bukan N+1).
  Future<List<TugasReportRow>> fetchReport({String? kelasId, String? guruId}) async {
    final c = _c;
    if (c == null) return const [];

    final tugasList = await fetchAll(kelasId: kelasId, guruId: guruId);
    if (tugasList.isEmpty) return const [];

    final tugasIds = tugasList.map((t) => t.id).toList();
    final kelasIds = tugasList.map((t) => t.kelasId).where((id) => id.isNotEmpty).toSet().toList();

    final siswaRows = kelasIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await c.from('siswa').select('id, kelas_id').inFilter('kelas_id', kelasIds).eq('status_aktif', true))
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final siswaCountByKelas = <String, int>{};
    for (final row in siswaRows) {
      final kelas = row['kelas_id'] as String? ?? '';
      siswaCountByKelas[kelas] = (siswaCountByKelas[kelas] ?? 0) + 1;
    }

    final statusRows = await c
        .from('status_tugas_siswa')
        .select('tugas_id, status, selesai_pada')
        .inFilter('tugas_id', tugasIds);

    final selesaiByTugas = <String, int>{};
    final terlambatByTugas = <String, int>{};
    final tenggatByTugas = {for (final t in tugasList) t.id: t.tenggatWaktu};

    for (final row in statusRows) {
      final tugasId = row['tugas_id'] as String? ?? '';
      final status = row['status'] as String? ?? '';
      if (status != 'selesai') continue;
      selesaiByTugas[tugasId] = (selesaiByTugas[tugasId] ?? 0) + 1;

      final selesaiPada = row['selesai_pada'] == null
          ? null
          : DateTime.tryParse(row['selesai_pada'] as String);
      final tenggat = tenggatByTugas[tugasId];
      if (selesaiPada != null && tenggat != null && selesaiPada.isAfter(tenggat)) {
        terlambatByTugas[tugasId] = (terlambatByTugas[tugasId] ?? 0) + 1;
      }
    }

    return tugasList
        .map((t) => TugasReportRow(
              tugas: t,
              totalSiswa: siswaCountByKelas[t.kelasId] ?? 0,
              selesai: selesaiByTugas[t.id] ?? 0,
              terlambat: terlambatByTugas[t.id] ?? 0,
            ))
        .toList();
  }

  /// Status resmi siswa HANYA bisa diubah lewat Edge Function yang memverifikasi
  /// token HMAC. Tidak ada jalur tulis langsung dari client (RLS memblokir),
  /// sehingga kegagalan fungsi TIDAK boleh di-bypass diam-diam.
  Future<void> updateStudentStatusViaFunction({
    required String tugasId,
    required String siswaId,
    required String status,
    required String token,
  }) async {
    final c = SupabaseService.tryClient;
    if (c == null) {
      throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    }
    await c.functions.invoke('update-student-task-status', body: {
      'tugas_id': tugasId,
      'siswa_id': siswaId,
      'status': status,
      'token': token,
    });
  }
}
