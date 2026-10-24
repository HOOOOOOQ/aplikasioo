import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/mata_pelajaran.dart';

class MapelRepository {
  SupabaseClient get _c => SupabaseService.client;

  Future<List<MataPelajaran>> fetchAll() async {
    final data = await _c.from('mata_pelajaran').select().order('nama_mapel');
    return (data as List).map((e) => MataPelajaran.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MataPelajaran> create({required String nama, String? deskripsi}) async {
    final res = await _c.from('mata_pelajaran').insert({'nama_mapel': nama, 'deskripsi': deskripsi}).select().single();
    return MataPelajaran.fromJson(res);
  }

  Future<MataPelajaran> update(String id, Map<String, dynamic> patch) async {
    final res = await _c.from('mata_pelajaran').update(patch).eq('id', id).select().single();
    return MataPelajaran.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _c.from('mata_pelajaran').delete().eq('id', id);
  }
}
