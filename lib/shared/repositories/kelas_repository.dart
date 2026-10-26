import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kelas.dart';
import '../services/supabase_service.dart';

class KelasRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<Kelas>> fetchAll({int? limit}) async {
    final c = _c;
    if (c == null) return const [];
    var rows = await c
        .from('kelas')
        .select('*, profiles!kelas_wali_kelas_id_fkey(full_name)')
        .order('nama_kelas');
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);
    return rows.map((e) => Kelas.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Kelas?> fetchById(String id) async {
    final c = _c;
    if (c == null) return null;
    final row = await c
        .from('kelas')
        .select('*, profiles!kelas_wali_kelas_id_fkey(full_name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Kelas.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Kelas> create({
    required String namaKelas,
    String? tingkat,
    String? tahunAjaran,
    String? waliKelasId,
  }) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('kelas').insert({
      'nama_kelas': namaKelas,
      'tingkat': tingkat,
      'tahun_ajaran': tahunAjaran,
      'wali_kelas_id': waliKelasId,
    }).select().single();
    return Kelas.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Kelas> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('kelas').update(patch).eq('id', id).select().single();
    return Kelas.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('kelas').delete().eq('id', id);
  }

  Future<Map<String, int>> countSiswaPerKelas() async {
    final c = _c;
    if (c == null) return const {};
    final rows = await c.from('siswa').select('kelas_id').eq('status_aktif', true);
    final result = <String, int>{};
    for (final row in rows) {
      final id = row['kelas_id'] as String?;
      if (id == null) continue;
      result[id] = (result[id] ?? 0) + 1;
    }
    return result;
  }
}
