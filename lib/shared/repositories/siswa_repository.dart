import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/siswa.dart';
import '../services/supabase_service.dart';

class SiswaRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<Siswa>> fetchAll({
    String? kelasId,
    String? search,
    bool? onlyActive,
    int? limit,
  }) async {
    final c = _c;
    if (c == null) return const [];

    var query = c.from('siswa').select('*, kelas(nama_kelas)');
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);
    if (onlyActive == true) query = query.eq('status_aktif', true);

    var rows = await query.order('nama');
    var list = rows.map((e) => Siswa.fromJson(Map<String, dynamic>.from(e))).toList();

    if (search != null && search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      list = list
          .where((s) =>
              s.nama.toLowerCase().contains(needle) ||
              s.nomorInduk.toLowerCase().contains(needle))
          .toList();
    }

    if (limit != null && list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  /// Daftar siswa satu kelas — dipakai saat siswa memilih namanya setelah
  /// memasukkan kode akses kelas. Anon hanya boleh membaca kolom non-sensitif
  /// (lihat migration 002), dan kode akses tidak termasuk di dalamnya.
  Future<List<Siswa>> fetchByKelas(String kelasId) async {
    final c = _c;
    if (c == null) return const [];
    final rows = await c
        .from('siswa')
        .select('id, nomor_induk, nama, kelas_id, status_aktif, created_at, updated_at')
        .eq('kelas_id', kelasId)
        .eq('status_aktif', true)
        .order('nama');
    return rows.map((e) => Siswa.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Siswa> create({
    required String nomorInduk,
    required String nama,
    String? kelasId,
    bool statusAktif = true,
  }) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final payload = <String, dynamic>{
      'nomor_induk': nomorInduk,
      'nama': nama,
      'kelas_id': kelasId,
      'status_aktif': statusAktif,
    };
    final res = await c.from('siswa').insert(payload).select('*, kelas(nama_kelas)').single();
    return Siswa.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Siswa> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('siswa').update(patch).eq('id', id).select('*, kelas(nama_kelas)').single();
    return Siswa.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('siswa').delete().eq('id', id);
  }

  Future<int> countAll() async {
    final c = _c;
    if (c == null) return 0;
    final rows = await c.from('siswa').select('id').eq('status_aktif', true);
    return rows.length;
  }
}
