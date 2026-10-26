import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/tugas.dart';
import '../models/status_tugas.dart';

class TugasRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<Tugas>> fetchAll({String? kelasId, String? guruId, String? mapelId, String? search, String? siswaId}) async {
    final c = _c;
    if (c == null) return [];
    try {
      var q = c.from('tugas').select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!tugas_guru_id_fkey(full_name)');
      if (kelasId != null) q = q.eq('kelas_id', kelasId);
      if (guruId != null) q = q.eq('guru_id', guruId);
      if (mapelId != null) q = q.eq('mata_pelajaran_id', mapelId);
      q = q.eq('status_publikasi', 'published');
      final data = await q.order('tenggat_waktu', ascending: true);
      var list = (data as List).map((e) => Tugas.fromJson(e as Map<String, dynamic>)).toList();

      if (siswaId != null && list.isNotEmpty) {
        final ids = list.map((e) => e.id).toList();
        final statusData = await c.from('status_tugas_siswa').select().inFilter('tugas_id', ids).eq('siswa_id', siswaId);
        final map = {for (var s in statusData as List) (s as Map<String, dynamic>)['tugas_id']: s};
        list = list.map((t) {
          final st = map[t.id];
          if (st != null) {
            return Tugas(
              id: t.id,
              judul: t.judul,
              deskripsi: t.deskripsi,
              guruId: t.guruId,
              guruNama: t.guruNama,
              kelasId: t.kelasId,
              kelasNama: t.kelasNama,
              mataPelajaranId: t.mataPelajaranId,
              mataPelajaranNama: t.mataPelajaranNama,
              tanggalMulai: t.tanggalMulai,
              tenggatWaktu: t.tenggatWaktu,
              lampiranPath: t.lampiranPath,
              statusPublikasi: t.statusPublikasi,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
              statusSiswa: (st as Map)['status'] as String?,
              selesaiPada: st['selesai_pada'] != null ? DateTime.tryParse(st['selesai_pada'] as String) : null,
            );
          }
          return t;
        }).toList();
      }

      if (search != null && search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        list = list.where((t) => t.judul.toLowerCase().contains(s) || (t.mataPelajaranNama?.toLowerCase().contains(s) ?? false)).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<Tugas?> fetchById(String id, {String? siswaId}) async {
    final c = _c;
    if (c == null) return null;
    try {
      final data = await c.from('tugas').select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!tugas_guru_id_fkey(full_name)').eq('id', id).maybeSingle();
      if (data == null) return null;
      var tugas = Tugas.fromJson(data);
      if (siswaId != null) {
        final st = await c.from('status_tugas_siswa').select().eq('tugas_id', id).eq('siswa_id', siswaId).maybeSingle();
        if (st != null) {
          tugas = Tugas(
            id: tugas.id,
            judul: tugas.judul,
            deskripsi: tugas.deskripsi,
            guruId: tugas.guruId,
            guruNama: tugas.guruNama,
            kelasId: tugas.kelasId,
            kelasNama: tugas.kelasNama,
            mataPelajaranId: tugas.mataPelajaranId,
            mataPelajaranNama: tugas.mataPelajaranNama,
            tanggalMulai: tugas.tanggalMulai,
            tenggatWaktu: tugas.tenggatWaktu,
            lampiranPath: tugas.lampiranPath,
            statusPublikasi: tugas.statusPublikasi,
            createdAt: tugas.createdAt,
            updatedAt: tugas.updatedAt,
            statusSiswa: (st as Map)['status'] as String?,
            selesaiPada: st['selesai_pada'] != null ? DateTime.tryParse(st['selesai_pada'] as String) : null,
          );
        }
      }
      return tugas;
    } catch (_) {
      return null;
    }
  }

  Future<Tugas> create(Map<String, dynamic> payload) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('tugas').insert(payload).select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!tugas_guru_id_fkey(full_name)').single();
    return Tugas.fromJson(res);
  }

  Future<Tugas> update(String id, Map<String, dynamic> patch) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final res = await c.from('tugas').update(patch).eq('id', id).select('*, kelas(nama_kelas), mata_pelajaran(nama_mapel), profiles!tugas_guru_id_fkey(full_name)').single();
    return Tugas.fromJson(res);
  }

  Future<void> delete(String id) async {
    final _guard = SupabaseService.tryClient;
    if (_guard == null) throw Exception('Supabase belum dikonfigurasi');
    await _guard.from('tugas').delete().eq('id', id);
  }

  Future<List<StatusTugasSiswa>> fetchStatusForTugas(String tugasId) async {
    final c = _c;
    if (c == null) return [];
    try {
      final data = await c.from('status_tugas_siswa').select('*, siswa(nama)').eq('tugas_id', tugasId);
      return (data as List).map((e) => StatusTugasSiswa.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> fetchSummary(String tugasId) async {
    final c = _c;
    if (c == null) return {'total': 0, 'selesai': 0, 'belum': 0};
    try {
      final totalSiswaData = await c.from('tugas').select('kelas_id').eq('id', tugasId).maybeSingle();
      if (totalSiswaData == null) return {'total': 0, 'selesai': 0, 'belum': 0};
      final kelasId = (totalSiswaData as Map)['kelas_id'] as String? ?? '';
      if (kelasId.isEmpty) return {'total': 0, 'selesai': 0, 'belum': 0};
      final totalRes = await c.from('siswa').select('id').eq('kelas_id', kelasId).eq('status_aktif', true);
      final total = (totalRes as List).length;
      final selesaiRes = await c.from('status_tugas_siswa').select('id').eq('tugas_id', tugasId).eq('status', 'selesai');
      final selesai = (selesaiRes as List).length;
      return {'total': total, 'selesai': selesai, 'belum': total - selesai};
    } catch (_) {
      return {'total': 0, 'selesai': 0, 'belum': 0};
    }
  }

  Future<void> updateStudentStatusViaFunction({required String tugasId, required String siswaId, required String status, required String token}) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    try {
      await c.functions.invoke('update-student-task-status', body: {
        'tugas_id': tugasId,
        'siswa_id': siswaId,
        'status': status,
        'token': token,
      });
    } catch (e) {
      await c.from('status_tugas_siswa').upsert({
        'tugas_id': tugasId,
        'siswa_id': siswaId,
        'status': status,
        'selesai_pada': status == 'selesai' ? DateTime.now().toIso8601String() : null,
      }, onConflict: 'tugas_id,siswa_id');
    }
  }

  Future<void> updateStatusDirect({required String tugasId, required String siswaId, required String status}) async {
    final _guard = SupabaseService.tryClient;
    if (_guard == null) throw Exception('Supabase belum dikonfigurasi');
    await _guard.from('status_tugas_siswa').upsert({
      'tugas_id': tugasId,
      'siswa_id': siswaId,
      'status': status,
      'selesai_pada': status == 'selesai' ? DateTime.now().toIso8601String() : null,
    }, onConflict: 'tugas_id,siswa_id');
  }

  Future<String?> uploadLampiran({required String fileName, required List<int> bytes}) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi — atur SUPABASE_URL/ANON_KEY');
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await c.storage.from('lampiran-tugas').uploadBinary(path, Uint8List.fromList(bytes));
    return path;
  }

  String getPublicUrl(String path) {
    final c = SupabaseService.tryClient;
    if (c == null) return '';
    try {
      return c.storage.from('lampiran-tugas').getPublicUrl(path);
    } catch (_) {
      return '';
    }
  }
}
