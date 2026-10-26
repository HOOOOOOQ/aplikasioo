import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_error.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/access_code.dart';

final accessCodeRepositoryProvider = Provider<AccessCodeRepository>((ref) => AccessCodeRepository());

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

    var query = c.from('kode_akses_siswa').select(
      'id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, used_at, used_by_siswa_id, revoked_at, created_by, created_at, note',
    );
    if (kelasId != null && kelasId.isNotEmpty) query = query.eq('kelas_id', kelasId);

    final rows = await query.order('created_at', ascending: false).limit(limit);
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
  Future<IssuedAccessCode> issue({
    required String kelasId,
    String? siswaId,
    bool singleUse = true,
    int? expiresInDays,
    String? note,
  }) async {
    final c = SupabaseService.tryClient;
    if (c == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        code: 'config',
      );
    }

    try {
      final res = await c.functions.invoke('student-codes', body: {
        'action': 'issue',
        'kelas_id': kelasId,
        'siswa_id': siswaId,
        'single_use': singleUse,
        'expires_in_days': expiresInDays,
        'note': note,
      });

      final data = res.data;
      if (data is! Map) {
        throw const AppError(
          title: 'Respons tidak dikenali',
          message: 'Server tidak mengembalikan data kode.',
          code: 'bad_response',
        );
      }
      final map = Map<String, dynamic>.from(data);
      final code = map['kode'] as String?;
      final row = map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : <String, dynamic>{};
      if (code == null || code.isEmpty) {
        throw const AppError(
          title: 'Kode tidak terbentuk',
          message: 'Server tidak mengembalikan kode akses.',
          code: 'bad_response',
        );
      }
      return IssuedAccessCode(
        code: code,
        id: row['id'] as String? ?? '',
        expiresAt: row['expires_at'] == null ? null : DateTime.tryParse(row['expires_at'].toString()),
      );
    } on FunctionException catch (e) {
      throw AppError.from(e);
    } catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> revoke(String id) async {
    final c = SupabaseService.tryClient;
    if (c == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        code: 'config',
      );
    }
    try {
      await c.functions.invoke('student-codes', body: {'action': 'revoke', 'id': id});
    } on FunctionException catch (e) {
      throw AppError.from(e);
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
