import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/supabase_service.dart';
import '../models/kelas.dart';

class KelasRepository {
  SupabaseClient get _c => SupabaseService.client;

  Future<List<Kelas>> fetchAll() async {
    final data = await _c.from('kelas').select('*, profiles!kelas_wali_kelas_id_fkey(full_name)').order('nama_kelas');
    return (data as List).map((e) => Kelas.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Kelas> create({required String namaKelas, String? tingkat, String? tahunAjaran, String? waliKelasId}) async {
    final res = await _c.from('kelas').insert({
      'nama_kelas': namaKelas,
      'tingkat': tingkat,
      'tahun_ajaran': tahunAjaran,
      'wali_kelas_id': waliKelasId,
    }).select().single();
    return Kelas.fromJson(res);
  }

  Future<Kelas> update(String id, Map<String, dynamic> patch) async {
    final res = await _c.from('kelas').update(patch).eq('id', id).select().single();
    return Kelas.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _c.from('kelas').delete().eq('id', id);
  }

  Future<int> countSiswa(String kelasId) async {
    final res = await _c.from('siswa').select('id').eq('kelas_id', kelasId).eq('status_aktif', true);
    return (res as List).length;
  }
}
