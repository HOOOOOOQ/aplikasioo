import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mata_pelajaran.dart';
import '../services/supabase_service.dart';

class MapelRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<MataPelajaran>> fetchAll({int? limit}) async {
    final c = _c;
    if (c == null) return const [];
    var rows = await c.from('mata_pelajaran').select().order('nama_mapel');
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);
    return rows.map((e) => MataPelajaran.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<MataPelajaran> create({required String nama, String? deskripsi}) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c
        .from('mata_pelajaran')
        .insert({'nama_mapel': nama, 'deskripsi': deskripsi})
        .select()
        .single();
    return MataPelajaran.fromJson(Map<String, dynamic>.from(res));
  }

  Future<MataPelajaran> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('mata_pelajaran').update(patch).eq('id', id).select().single();
    return MataPelajaran.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('mata_pelajaran').delete().eq('id', id);
  }
}
