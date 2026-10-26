import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_error.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/akademik_models.dart';

/// Akses data akademik untuk **admin/guru** (login + RLS).
///
/// Semua query bergantung pada policy RLS migration 006: guru hanya melihat
/// kelas yang diampu, admin melihat semuanya. Tidak ada `service_role` di sini.
class AkademikRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  SupabaseClient _requireClient() {
    final c = _c;
    if (c == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        hint: 'Hubungi pengelola aplikasi.',
        code: 'config',
      );
    }
    return c;
  }

  // ------------------------------------------------ PENGUMUMAN
  Future<List<Pengumuman>> fetchPengumuman({int limit = 50}) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('pengumuman')
          .select('id, judul, isi, target, kelas_id, is_published, publish_at, created_by, profiles(full_name)')
          .order('publish_at', ascending: false)
          .limit(limit);
      return rows.map((row) => Pengumuman.fromJson(Map<String, dynamic>.from(row))).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> createPengumuman({
    required String judul,
    required String isi,
    String target = 'semua',
    String? kelasId,
  }) async {
    final c = _requireClient();
    final user = c.auth.currentUser;
    if (user == null) {
      throw const AppError(
        title: 'Sesi berakhir',
        message: 'Masuk kembali untuk membuat pengumuman.',
        code: 'session_expired',
      );
    }
    try {
      await c.from('pengumuman').insert({
        'judul': judul.trim(),
        'isi': isi.trim(),
        'target': target,
        'kelas_id': kelasId,
        'is_published': true,
        'created_by': user.id,
      });
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ KALENDER
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

  Future<void> createKalender({
    required String judul,
    required DateTime tanggalMulai,
    DateTime? tanggalSelesai,
    String tipe = 'kegiatan',
    String? deskripsi,
    String? kelasId,
  }) async {
    final c = _requireClient();
    try {
      await c.from('kalender_akademik').insert({
        'judul': judul.trim(),
        'deskripsi': deskripsi?.trim(),
        'tipe': tipe,
        'tanggal_mulai': tanggalMulai.toIso8601String().substring(0, 10),
        'tanggal_selesai':
            tanggalSelesai == null ? null : tanggalSelesai.toIso8601String().substring(0, 10),
        'kelas_id': kelasId,
      });
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ STATISTIK & PENCARIAN
  Future<AkademikStats> fetchStats() async {
    final c = _requireClient();
    try {
      final data = await c.rpc('akademik_stats');
      if (data is Map) return AkademikStats.fromJson(Map<String, dynamic>.from(data));
      return AkademikStats.empty;
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<List<SearchHit>> search(String query, {int limit = 20}) async {
    final c = _requireClient();
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final data = await c.rpc('edutask_search', params: {'p_query': q, 'p_limit': limit});
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) => SearchHit.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      }
      return const [];
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ NOTIFIKASI
  Future<List<NotifikasiItem>> fetchNotifikasi({int limit = 100}) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('notifikasi')
          .select('id, tipe, judul, isi, ref_id, is_read, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((row) => NotifikasiItem.fromJson(Map<String, dynamic>.from(row))).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> markNotifikasiRead(String id) async {
    final c = _requireClient();
    try {
      await c.from('notifikasi').update({'is_read': true}).eq('id', id);
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> markAllNotifikasiRead() async {
    final c = _requireClient();
    final user = c.auth.currentUser;
    if (user == null) return;
    try {
      await c.from('notifikasi').update({'is_read': true}).eq('profile_id', user.id).eq('is_read', false);
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  // ------------------------------------------------ CHAT
  Future<List<ChatThread>> fetchThreads() async {
    final c = _c;
    if (c == null) return const [];
    final user = c.auth.currentUser;
    if (user == null) return const [];
    try {
      final memberRows = await c.from('chat_members').select('thread_id').eq('profile_id', user.id);
      final ids = memberRows.map((r) => r['thread_id'] as String).toList();
      if (ids.isEmpty) return const [];

      final threadRows = await c
          .from('chat_threads')
          .select('id, tipe, judul, kelas_id, last_message_at')
          .inFilter('id', ids)
          .order('last_message_at', ascending: false);

      Map<String, int> unread = {};
      try {
        final stats = await c.rpc('chat_unread_counts');
        if (stats is List) {
          for (final row in stats) {
            if (row is Map) {
              unread[row['thread_id']?.toString() ?? ''] = (row['unread'] as num?)?.toInt() ?? 0;
            }
          }
        }
      } on PostgrestException {
        // Badge tidak kritis: daftar tetap ditampilkan walau RPC belum ada.
      }

      return threadRows.map((row) {
        final map = Map<String, dynamic>.from(row);
        map['unread'] = unread[map['id']] ?? 0;
        return ChatThread.fromJson(map);
      }).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<List<ChatMessage>> fetchMessages(
    String threadId, {
    DateTime? before,
    int limit = 30,
  }) async {
    final c = _requireClient();
    try {
      var query = c
          .from('chat_messages')
          .select('id, thread_id, sender_profile_id, sender_siswa_id, sender_nama, body, created_at')
          .eq('thread_id', threadId)
          .order('created_at', ascending: false)
          .limit(limit);
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      final rows = await query;
      return rows.reversed
          .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<ChatMessage> sendMessage(
    String threadId,
    String body, {
    String? clientId,
    required String senderNama,
  }) async {
    final c = _requireClient();
    final user = c.auth.currentUser;
    if (user == null) {
      throw const AppError(
        title: 'Sesi berakhir',
        message: 'Masuk kembali untuk mengirim pesan.',
        code: 'session_expired',
      );
    }
    try {
      final row = await c
          .from('chat_messages')
          .insert({
            'thread_id': threadId,
            'sender_profile_id': user.id,
            'sender_nama': senderNama,
            'body': body.trim(),
            'client_id': clientId,
          })
          .select('id, thread_id, sender_profile_id, sender_siswa_id, sender_nama, body, created_at')
          .single();
      return ChatMessage.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> markThreadRead(String threadId) async {
    final c = _c;
    if (c == null) return;
    final user = c.auth.currentUser;
    if (user == null) return;
    try {
      await c
          .from('chat_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('thread_id', threadId)
          .eq('profile_id', user.id);
    } on PostgrestException {
      // Non-kritis: jangan gagalkan percakapan hanya karena badge gagal.
    }
  }

  /// Stream pesan baru lewat Supabase Realtime. Channel harus di-dispose
  /// pemanggil (lihat `ChatRoomPage.dispose`).
  RealtimeChannel watchMessages(String threadId, void Function(ChatMessage) onInsert) {
    final c = _requireClient();
    return c
        .channel('chat:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final raw = payload.newRecord;
            if (raw.isEmpty) return;
            try {
              onInsert(ChatMessage.fromJson(Map<String, dynamic>.from(raw)));
            } catch (_) {
              // Payload tidak dikenal: abaikan, pesan tetap bisa dimuat ulang.
            }
          },
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.removeChannel(channel);
    } catch (_) {
      // Abaikan kegagalan pelepasan channel saat keluar halaman.
    }
  }

  /// Buat (atau ambil) thread grup kelas untuk guru yang mengampu kelas itu.
  Future<String?> ensureKelasThread({required String kelasId, required String judul}) async {
    final c = _requireClient();
    try {
      final existing = await c
          .from('chat_threads')
          .select('id')
          .eq('tipe', 'kelas')
          .eq('kelas_id', kelasId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String?;

      final user = c.auth.currentUser;
      final created = await c
          .from('chat_threads')
          .insert({
            'tipe': 'kelas',
            'judul': judul,
            'kelas_id': kelasId,
            'created_by': user?.id,
          })
          .select('id')
          .single();
      final threadId = created['id'] as String;
      if (user != null) {
        await c.from('chat_members').insert({
          'thread_id': threadId,
          'profile_id': user.id,
          'peran': 'pengelola',
        });
      }
      return threadId;
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  /// Kirim pengumuman ke seluruh siswa di sebuah kelas lewat notifikasi.
  Future<void> notifyClass({
    required String kelasId,
    required String judul,
    String? isi,
  }) async {
    final c = _c;
    if (c == null) return;
    try {
      final siswaRows = await c.from('siswa').select('id').eq('kelas_id', kelasId).eq('status_aktif', true);
      if (siswaRows.isEmpty) return;
      await c.from('notifikasi').insert([
        for (final row in siswaRows)
          {
            'siswa_id': row['id'],
            'tipe': 'pengumuman',
            'judul': judul,
            'isi': isi,
          },
      ]);
    } on PostgrestException {
      // Notifikasi bersifat pelengkap; pengumuman tetap tersimpan pada tabelnya.
    }
  }
}

/// Komentar diskusi tugas dari sisi guru/admin.
class KomentarRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<Map<String, dynamic>>> fetch({
    required String tugasId,
    int limit = 100,
  }) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('tugas_komentar')
          .select('id, author_role, author_nama, isi, created_at')
          .eq('tugas_id', tugasId)
          .order('created_at', ascending: true)
          .limit(limit);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> add({
    required String tugasId,
    required String isi,
    required String authorNama,
    required String authorRole,
  }) async {
    final c = _c;
    if (c == null) return;
    final user = c.auth.currentUser;
    if (user == null) {
      throw const AppError(
        title: 'Sesi berakhir',
        message: 'Masuk kembali untuk mengirim komentar.',
        code: 'session_expired',
      );
    }
    try {
      await c.from('tugas_komentar').insert({
        'tugas_id': tugasId,
        'author_role': authorRole,
        'author_profile_id': user.id,
        'author_nama': authorNama,
        'isi': isi.trim(),
      });
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }
}

/// Penilaian pengumpulan tugas oleh guru/admin.
class PenilaianRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<Pengumpulan>> fetchPengumpulan(String tugasId) async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('tugas_pengumpulan')
          .select('id, tugas_id, siswa_id, revisi_ke, jawaban_teks, lampiran_path, status, nilai, umpan_balik, submitted_at, reviewed_at')
          .eq('tugas_id', tugasId)
          .order('submitted_at', ascending: false)
          .limit(200);
      return rows.map((r) => Pengumpulan.fromJson(Map<String, dynamic>.from(r))).toList();
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> beriNilai({
    required String pengumpulanId,
    required double nilai,
    String? umpanBalik,
    String status = 'dinilai',
  }) async {
    final c = _c;
    if (c == null) return;
    final user = c.auth.currentUser;
    try {
      await c.from('tugas_pengumpulan').update({
        'nilai': nilai.clamp(0, 100),
        'umpan_balik': umpanBalik?.trim(),
        'status': status,
        'reviewed_by': user?.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', pengumpulanId);
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> tandaiRevisi({required String pengumpulanId, String? umpanBalik}) async {
    final c = _c;
    if (c == null) return;
    final user = c.auth.currentUser;
    try {
      await c.from('tugas_pengumpulan').update({
        'status': 'revisi',
        'umpan_balik': umpanBalik?.trim(),
        'reviewed_by': user?.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', pengumpulanId);
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }
}
