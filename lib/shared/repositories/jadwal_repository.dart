import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/jadwal.dart';
import '../services/supabase_service.dart';

class JadwalRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  static const String _joins =
      '*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!jadwal_pelajaran_guru_id_fkey(full_name)';

  Future<List<Jadwal>> fetchAll({
    String? kelasId,
    String? hari,
    String? guruId,
    int? limit,
  }) async {
    final c = _c;
    if (c == null) return const [];

    var query = c.from('jadwal_pelajaran').select(_joins);
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);
    if (hari != null && hari.isNotEmpty) query = query.eq('hari', hari);
    if (guruId != null && guruId.isNotEmpty) query = query.eq('guru_id', guruId);

    var rows = await query;
    var list = rows.map((e) => Jadwal.fromJson(Map<String, dynamic>.from(e))).toList();

    // Urutkan menurut hari (bukan alfabetis seperti order kolom teks) lalu jam.
    const dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    list.sort((a, b) {
      final byDay = dayOrder.indexOf(a.hari).compareTo(dayOrder.indexOf(b.hari));
      if (byDay != 0) return byDay;
      return a.jamMulai.compareTo(b.jamMulai);
    });

    if (limit != null && list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  Future<List<Jadwal>> fetchByKelas(String kelasId) => fetchAll(kelasId: kelasId);
  Future<List<Jadwal>> fetchByGuru(String guruId) => fetchAll(guruId: guruId);

  Future<Jadwal> create(Map<String, dynamic> payload) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    final res = await c.from('jadwal_pelajaran').insert(payload).select(_joins).single();
    return Jadwal.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Jadwal> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    final res = await c.from('jadwal_pelajaran').update(patch).eq('id', id).select(_joins).single();
    return Jadwal.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('jadwal_pelajaran').delete().eq('id', id);
  }
}
