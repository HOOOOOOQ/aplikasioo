import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/jadwal.dart';

class JadwalRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<List<Jadwal>> fetchAll({String? kelasId, String? hari, String? guruId}) async {
    var q = _c.from('jadwal_pelajaran').select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!jadwal_pelajaran_guru_id_fkey(full_name)');
    if (kelasId != null) q = q.eq('kelas_id', kelasId);
    if (hari != null) q = q.eq('hari', hari);
    if (guruId != null) q = q.eq('guru_id', guruId);
    final data = await q.order('hari').order('jam_mulai');
    return (data as List).map((e) => Jadwal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Jadwal>> fetchByKelas(String kelasId) => fetchAll(kelasId: kelasId);
  Future<List<Jadwal>> fetchByGuru(String guruId) => fetchAll(guruId: guruId);

  Future<Jadwal> create(Map<String, dynamic> payload) async {
    final res = await _c.from('jadwal_pelajaran').insert(payload).select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!jadwal_pelajaran_guru_id_fkey(full_name)').single();
    return Jadwal.fromJson(res);
  }

  Future<Jadwal> update(String id, Map<String, dynamic> patch) async {
    final res = await _c.from('jadwal_pelajaran').update(patch).eq('id', id).select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!jadwal_pelajaran_guru_id_fkey(full_name)').single();
    return Jadwal.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _c.from('jadwal_pelajaran').delete().eq('id', id);
  }
}
