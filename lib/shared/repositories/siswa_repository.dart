import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/supabase_service.dart';
import '../models/siswa.dart';

class SiswaRepository {
  SupabaseClient get _c => SupabaseService.client;

  Future<List<Siswa>> fetchAll({String? kelasId, String? search}) async {
    var query = _c.from('siswa').select('*, kelas(nama_kelas)');
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);
    final data = await query.order('nama');
    var list = (data as List).map((e) => Siswa.fromJson(e as Map<String, dynamic>)).toList();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((e) => e.nama.toLowerCase().contains(s) || e.nomorInduk.toLowerCase().contains(s)).toList();
    }
    return list;
  }

  Future<Siswa> create({required String nomorInduk, required String nama, String? kelasId, String? kodeAkses}) async {
    final payload = {
      'nomor_induk': nomorInduk,
      'nama': nama,
      'kelas_id': kelasId,
      if (kodeAkses != null && kodeAkses.isNotEmpty) 'kode_akses': kodeAkses,
    };
    final res = await _c.from('siswa').insert(payload).select('*, kelas(nama_kelas)').single();
    return Siswa.fromJson(res);
  }

  Future<Siswa> update(String id, Map<String, dynamic> patch) async {
    final res = await _c.from('siswa').update(patch).eq('id', id).select('*, kelas(nama_kelas)').single();
    return Siswa.fromJson(res);
  }

  Future<void> delete(String id) async {
    await _c.from('siswa').delete().eq('id', id);
  }

  Future<Siswa?> findByKode(String kode) async {
    final data = await _c.from('siswa').select('*, kelas(nama_kelas)').eq('kode_akses', kode).maybeSingle();
    if (data == null) return null;
    return Siswa.fromJson(data);
  }
}

extension _SiswaCopy on Siswa {
  Siswa copyWithKelas() => this;
}
