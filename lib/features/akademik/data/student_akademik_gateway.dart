import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_error.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/akademik_models.dart';

/// Akses data akademik untuk **siswa**.
///
/// Siswa tidak login, jadi tidak ada JWT. Semua penulisan data siswa melewati
/// Edge Function bertoken (`student-portal`, `student-chat`) yang memverifikasi
/// token HMAC dan memeriksa hak akses di server. Pengumuman & kalender dibaca
/// lewat RLS `anon` (hanya baris yang dipublikasikan).
class StudentAkademikGateway {
  final String? token;
  final String? siswaId;
  final String? siswaNama;

  const StudentAkademikGateway({this.token, this.siswaId, this.siswaNama});

  SupabaseClient? get _c => SupabaseService.tryClient;

  bool get hasIdentity => (token ?? '').isNotEmpty && (siswaId ?? '').isNotEmpty;

  AppError get _needIdentity => const AppError(
        title: 'Identitas belum terhubung',
        message: 'Hubungkan identitas dengan kode akses dari guru untuk memakai fitur ini.',
        hint: 'Buka tab Identitas lalu masukkan kode akses.',
        code: 'identity_required',
      );

  Future<Map<String, dynamic>> _invoke(
    String function,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final c = _c;
    if (c == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        hint: 'Hubungi pengelola aplikasi.',
        code: 'config',
      );
    }
    final t = token;
    if (t == null || t.isEmpty) throw _needIdentity;

    try {
      final res = await c.functions.invoke(
        function,
        body: {'action': action, 'token': t, ...payload},
      );
      if (res.status >= 400) {
        throw FunctionException(status: res.status, details: res.data);
      }
      final data = res.data;
      if (data is! Map) {
        throw const AppError(
          title: 'Respons tidak dikenali',
          message: 'Server tidak mengembalikan data yang diharapkan.',
          code: 'bad_response',
        );
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (e) {
      throw AppError.from(e);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ PENGUMUMAN & KALENDER
  Future<List<Pengumuman>> fetchPengumuman({int limit = 50}) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('pengumuman')
          .select('id, judul, isi, target, kelas_id, is_published, publish_at')
          .order('publish_at', ascending: false)
          .limit(limit);
      return rows.map((row) => Pengumuman.fromJson(Map<String, dynamic>.from(row))).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<List<KalenderItem>> fetchKalender({int limit = 100}) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('kalender_akademik')
          .select('id, judul, deskripsi, tipe, tanggal_mulai, tanggal_selesai, kelas_id')
          .order('tanggal_mulai', ascending: true)
          .limit(limit);
      return rows.map((row) => KalenderItem.fromJson(Map<String, dynamic>.from(row))).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ PENGUMPULAN & NILAI
  Future<void> submitTask({
    required String tugasId,
    required String jawabanTeks,
  }) async {
    await _invoke('student-portal', 'submit_task', {
      'tugas_id': tugasId,
      'jawaban_teks': jawabanTeks,
    });
  }

  Future<List<Pengumpulan>> mySubmissions({String? tugasId}) async {
    final data = await _invoke('student-portal', 'my_submissions', {
      if (tugasId != null) 'tugas_id': tugasId,
    });
    return _asList(data['data']).map(Pengumpulan.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> listComments(String tugasId) async {
    final data = await _invoke('student-portal', 'list_comments', {'tugas_id': tugasId});
    return _asList(data['data']);
  }

  Future<void> addComment({required String tugasId, required String isi}) async {
    await _invoke('student-portal', 'add_comment', {'tugas_id': tugasId, 'isi': isi});
  }

  // ------------------------------------------------ NOTIFIKASI
  Future<List<NotifikasiItem>> fetchNotifikasi({int limit = 100}) async {
    final data = await _invoke('student-portal', 'notifications', {'limit': limit});
    return _asList(data['data']).map(NotifikasiItem.fromJson).toList();
  }

  Future<void> markNotifikasiRead(String id) async {
    await _invoke('student-portal', 'read_notification', {'id': id});
  }

  Future<void> markAllNotifikasiRead() async {
    await _invoke('student-portal', 'read_all_notifications', {});
  }

  // ------------------------------------------------ CHAT
  Future<List<ChatThread>> fetchThreads() async {
    final data = await _invoke('student-chat', 'threads', {});
    return _asList(data['data']).map(ChatThread.fromJson).toList();
  }

  Future<List<ChatMessage>> fetchMessages(
    String threadId, {
    DateTime? before,
    int limit = 30,
  }) async {
    final data = await _invoke('student-chat', 'messages', {
      'thread_id': threadId,
      'limit': limit,
      if (before != null) 'before': before.toUtc().toIso8601String(),
    });
    return _asList(data['data']).map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage?> sendMessage(
    String threadId,
    String body, {
    required String clientId,
  }) async {
    final data = await _invoke('student-chat', 'send', {
      'thread_id': threadId,
      'body': body,
      'client_id': clientId,
    });
    final row = data['data'];
    if (row is Map) return ChatMessage.fromJson(Map<String, dynamic>.from(row));
    return null;
  }

  Future<void> markThreadRead(String threadId) async {
    await _invoke('student-chat', 'mark_read', {'thread_id': threadId});
  }

  /// Buka percakapan privat dengan guru atau grup kelas siswa.
  Future<ChatThread?> openThread({required String tipe, String? guruId}) async {
    final data = await _invoke('student-chat', 'open_thread', {
      'tipe': tipe,
      if (guruId != null) 'guru_id': guruId,
    });
    final row = data['data'];
    if (row is Map) return ChatThread.fromJson(Map<String, dynamic>.from(row));
    return null;
  }


  // ------------------------------------------------ PENCARIAN
  /// Pencarian lokal untuk siswa: pengumuman, kalender, dan tugas kelas.
  /// Tidak memakai RPC `edutask_search` karena function itu hanya untuk
  /// `authenticated`; siswa memakai RLS `anon` yang hanya membaca data publik.
  Future<List<SearchHit>> search(String query, {String? kelasId}) async {
    final c = _c;
    final q = query.trim();
    if (c == null || q.length < 2) return const [];
    // Buang karakter yang punya arti khusus di PostgREST.
    final safe = q.replaceAll(RegExp(r'[%,()]'), ' ').trim();
    if (safe.isEmpty) return const [];

    final hits = <SearchHit>[];
    try {
      final pengumuman = await c
          .from('pengumuman')
          .select('id, judul, isi, publish_at')
          .or('judul.ilike.%$safe%,isi.ilike.%$safe%')
          .limit(10);
      for (final row in pengumuman) {
        hits.add(SearchHit(
          tipe: 'pengumuman',
          id: row['id'].toString(),
          judul: row['judul']?.toString() ?? 'Pengumuman',
          subjudul: 'Pengumuman sekolah',
          route: '/siswa/pengumuman',
        ));
      }
    } on PostgrestException {
      // Lanjut ke sumber lain; satu kegagalan tidak boleh mengosongkan hasil.
    }

    try {
      final kalender = await c
          .from('kalender_akademik')
          .select('id, judul, tipe, tanggal_mulai')
          .ilike('judul', '%$safe%')
          .limit(10);
      for (final row in kalender) {
        hits.add(SearchHit(
          tipe: 'kalender',
          id: row['id'].toString(),
          judul: row['judul']?.toString() ?? 'Agenda',
          subjudul: kalenderTipeLabel(row['tipe']?.toString() ?? 'kegiatan'),
          route: '/siswa/kalender',
        ));
      }
    } on PostgrestException {
      // abaikan
    }

    if (kelasId != null && kelasId.isNotEmpty) {
      try {
        final tugas = await c
            .from('tugas')
            .select('id, judul, tenggat_waktu')
            .eq('kelas_id', kelasId)
            .eq('status_publikasi', 'published')
            .ilike('judul', '%$safe%')
            .limit(10);
        for (final row in tugas) {
          hits.add(SearchHit(
            tipe: 'tugas',
            id: row['id'].toString(),
            judul: row['judul']?.toString() ?? 'Tugas',
            subjudul: 'Tugas kelas',
            route: '/siswa/tugas/${row['id']}',
          ));
        }
      } on PostgrestException {
        // abaikan
      }
    }

    return hits;
  }

  /// Daftar guru yang mengajar di kelas siswa (server-side, butuh token).
  Future<List<Map<String, dynamic>>> fetchGuruKelas() async {
    final data = await _invoke('student-chat', 'guru_list', {});
    return _asList(data['data']);
  }
}

/// Mengubah payload JSON dinamis menjadi daftar map yang aman.
List<Map<String, dynamic>> _asList(Object? data) {
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}
