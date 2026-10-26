import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/session_guard.dart';
import '../../../core/utils/app_error.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/access_code.dart';

final accessCodeRepositoryProvider = Provider<AccessCodeRepository>((ref) => AccessCodeRepository());

/// Hasil pemeriksaan idempotensi penerbitan kode.
class AccessCodeIssueStatus {
  final bool found;
  final String? id;
  final String? prefix;
  final String? status;
  final DateTime? expiresAt;

  const AccessCodeIssueStatus({
    required this.found,
    this.id,
    this.prefix,
    this.status,
    this.expiresAt,
  });

  static const AccessCodeIssueStatus notFound = AccessCodeIssueStatus(found: false);
}

class AccessCodeRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  /// Ambil daftar kode. RLS membatasi guru ke kelas yang ditanganinya.
  Future<List<AccessCode>> fetchCodes({
    String? kelasId,
    AccessCodeStatus? status,
    String? search,
    int limit = 200,
  }) async {
    final c = _c;
    if (c == null) return const [];

    // Hanya kolom yang benar-benar dipakai UI. `kode_hash` TIDAK pernah
    // diminta ke server, apalagi ditampilkan.
    var query = c.from('kode_akses_siswa').select(
      'id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, used_at, used_by_siswa_id, revoked_at, created_by, created_at, note',
    );
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);

    final List<dynamic> rows;
    try {
      rows = await query.order('created_at', ascending: false).limit(limit);
    } on PostgrestException catch (e) {
      // Termasuk PGRST205 "Could not find the table ... in the schema cache".
      throw AppError.from(e);
    }
    if (rows.isEmpty) return const [];

    final kelasIds = <String>{};
    final siswaIds = <String>{};
    final profileIds = <String>{};
    for (final row in rows) {
      final k = row['kelas_id'] as String?;
      if (k != null) kelasIds.add(k);
      final s = row['siswa_id'] as String?;
      if (s != null) siswaIds.add(s);
      final u = row['used_by_siswa_id'] as String?;
      if (u != null) siswaIds.add(u);
      final p = row['created_by'] as String?;
      if (p != null) profileIds.add(p);
    }

    final kelasMap = <String, String>{};
    if (kelasIds.isNotEmpty) {
      final kelasRows = await c.from('kelas').select('id, nama_kelas').inFilter('id', kelasIds.toList());
      for (final row in kelasRows) {
        kelasMap[row['id'] as String] = row['nama_kelas'] as String? ?? '-';
      }
    }

    final siswaMap = <String, String>{};
    if (siswaIds.isNotEmpty) {
      final siswaRows = await c.from('siswa').select('id, nama').inFilter('id', siswaIds.toList());
      for (final row in siswaRows) {
        siswaMap[row['id'] as String] = row['nama'] as String? ?? '-';
      }
    }

    final profileMap = <String, String>{};
    if (profileIds.isNotEmpty) {
      try {
        final profileRows =
            await c.from('profiles').select('id, full_name').inFilter('id', profileIds.toList());
        for (final row in profileRows) {
          profileMap[row['id'] as String] = row['full_name'] as String? ?? '-';
        }
      } catch (_) {
        // profil pembuat kode bersifat informasi tambahan; jangan gagalkan halaman
      }
    }

    var codes = rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final siswaId = map['siswa_id'] as String?;
      final usedById = map['used_by_siswa_id'] as String?;
      final createdBy = map['created_by'] as String?;
      return AccessCode.fromRow(
        map,
        kelasNama: kelasMap[map['kelas_id'] as String?],
        siswaNama: siswaId == null ? null : siswaMap[siswaId],
        usedByNama: usedById == null ? null : siswaMap[usedById],
        createdByNama: createdBy == null ? null : profileMap[createdBy],
      );
    }).toList();

    if (status != null) {
      codes = codes.where((code) => code.status == status).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      codes = codes
          .where((code) =>
              code.prefix.toLowerCase().contains(needle) ||
              (code.kelasNama?.toLowerCase().contains(needle) ?? false) ||
              (code.siswaNama?.toLowerCase().contains(needle) ?? false) ||
              (code.usedByNama?.toLowerCase().contains(needle) ?? false))
          .toList();
    }

    return codes;
  }

  /// Terbitkan kode baru. Pembuatan kode dilakukan server (CSPRNG).
  ///
  /// Sebelum memanggil Edge Function, sesi dipastikan masih berlaku dan
  /// access token dikirim eksplisit (lihat [SessionGuard]). Bila server tetap
  /// menolak dengan 401, sesi di-refresh sekali lalu permintaan diulang.
  Future<IssuedAccessCode> issue({
    required String kelasId,
    String? siswaId,
    bool singleUse = true,
    int? expiresInDays,
    String? note,
    String? idempotencyKey,
  }) async {
    final payload = <String, dynamic>{
      'kelas_id': kelasId,
      'siswa_id': siswaId,
      'single_use': singleUse,
      'expires_in_days': expiresInDays,
      'note': note,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
    };

    final data = await _invoke('issue', payload, allowRetry: true);
    final code = data['kode'] as String?;
    final row = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    if (code == null || code.isEmpty) {
      // idempotency_key sudah pernah dipakai: kode sebelumnya TIDAK dapat
      // ditampilkan lagi (plaintext tidak disimpan). Jangan pernah mengklaim
      // sukses tanpa kode.
      if (data['duplicate'] == true) {
        throw const AppError(
          title: 'Permintaan sudah pernah diproses',
          message: 'Kode untuk permintaan ini sudah dibuat, tetapi kodenya tidak dapat '
              'ditampilkan ulang karena hanya disimpan dalam bentuk hash.',
          hint: 'Gunakan "Cek status" untuk melihat kode tersebut, atau terbitkan kode baru.',
          code: 'duplicate_request',
        );
      }
      throw const AppError(
        title: 'Kode tidak terbentuk',
        message: 'Server tidak mengembalikan kode akses.',
        hint: 'Coba lagi. Bila tetap gagal, periksa log Edge Function student-codes.',
        code: 'bad_response',
      );
    }
    return IssuedAccessCode(
      code: code,
      id: row['id'] as String? ?? '',
      expiresAt: row['expires_at'] == null ? null : DateTime.tryParse(row['expires_at'].toString()),
    );
  }

  Future<void> revoke(String id) async {
    await _invoke('revoke', {'id': id}, allowRetry: true);
  }

  /// Cek apakah permintaan dengan [idempotencyKey] benar-benar membuat kode.
  ///
  /// Dipakai setelah timeout/jaringan putus agar pengguna tidak menerbitkan
  /// kode ganda. Kode plaintext memang tidak dapat dikirim ulang.
  Future<AccessCodeIssueStatus> status(String idempotencyKey) async {
    final data = await _invoke('status', {'idempotency_key': idempotencyKey}, allowRetry: true);
    if (data['found'] != true) return AccessCodeIssueStatus.notFound;
    final row = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    return AccessCodeIssueStatus(
      found: true,
      id: row['id'] as String?,
      prefix: row['kode_prefix'] as String?,
      status: row['status'] as String?,
      expiresAt: row['expires_at'] == null ? null : DateTime.tryParse(row['expires_at'].toString()),
    );
  }

  /// Panggil Edge Function `student-codes` dengan sesi yang sudah divalidasi.
  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload, {
    required bool allowRetry,
  }) async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        hint: 'Hubungi pengelola aplikasi.',
        code: 'config',
      );
    }

    final session = await SessionGuard.ensureValidSession();
    if (!session.isReady) {
      throw session.error ??
          const AppError(
            title: 'Sesi login berakhir',
            message: 'Sesi login tidak dapat dipakai.',
            hint: 'Masuk kembali sebagai admin atau guru.',
            code: 'session_expired',
          );
    }

    try {
      final res = await client.functions.invoke(
        'student-codes',
        body: {'action': action, ...payload},
        // Token dikirim eksplisit: jangan bergantung pada perilaku default SDK.
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      // Beberapa versi SDK mengembalikan respons error tanpa melempar
      // exception; tetap perlakukan status >= 400 sebagai kegagalan agar
      // aplikasi tidak pernah menampilkan "berhasil" palsu.
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
      final mapped = AppError.from(e);

      // 401 pada percobaan pertama bisa berarti token baru saja kedaluwarsa di
      // sisi server (gateway verify_jwt atau function). Refresh sekali lewat
      // mekanisme resmi GoTrue, lalu ulangi satu kali.
      if (allowRetry && e.status == 401) {
        final refreshed = await SessionGuard.ensureValidSession(forceRefresh: true);
        if (refreshed.isReady) {
          return _invoke(action, payload, allowRetry: false);
        }
        throw refreshed.error ?? mapped;
      }

      throw mapped;
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    }
  }

  /// Statistik kode langsung dari database (RPC `kode_akses_stats`).
  ///
  /// RLS tetap berlaku: admin melihat semua kode, guru hanya kelas yang diampu.
  /// Bila RPC belum ada (migration 005 belum dijalankan), error diteruskan
  /// sebagai [AppError] `schema_not_ready` — halaman akan menghitung cadangan
  /// dari daftar yang berhasil dimuat dan menandainya.
  Future<AccessCodeStats> fetchStats() async {
    final c = _c;
    if (c == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        code: 'config',
      );
    }
    try {
      final data = await c.rpc('kode_akses_stats');
      if (data is Map) {
        return AccessCodeStats.fromJson(Map<String, dynamic>.from(data));
      }
      throw const AppError(
        title: 'Statistik tidak tersedia',
        message: 'Server tidak mengembalikan data statistik kode.',
        code: 'bad_response',
      );
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }
}
