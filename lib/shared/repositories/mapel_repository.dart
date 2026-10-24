import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/mata_pelajaran.dart';

class MapelRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<MataPelajaran>> fetchAll() async {
    final c = _c;
    if (c == null) return [];
    try {
      final data = await c.from('mata_pelajaran').select().order('nama_mapel');
      return (data as List).map((e) => MataPelajaran.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<MataPelajaran> create({required String nama, String? deskripsi}) async {
    final c = SupabaseService.client;
    final res = await c.from('mata_pelajaran').insert({'nama_mapel': nama, 'deskripsi': deskripsi}).select().single();
    return MataPelajaran.fromJson(res);
  }

  Future<MataPelajaran> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.client;
    final res = await c.from('mata_pelajaran').update(patch).eq('id', id).select().single();
    return MataPelajaran.fromJson(res);
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('mata_pelajaran').delete().eq('id', id);
  }
}
