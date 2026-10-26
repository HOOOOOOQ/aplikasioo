import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/session_guard.dart';
import '../../core/utils/app_error.dart';
import '../services/supabase_service.dart';

final akunRepositoryProvider = Provider<AkunRepository>((ref) => AkunRepository());

/// Baris `public.profiles` yang dipakai halaman Manajemen Akun.
class ProfileRow {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const ProfileRow({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  factory ProfileRow.fromRow(Map<String, dynamic> row) {
    return ProfileRow(
      id: row['id'] as String? ?? '',
      fullName: row['full_name'] as String? ?? '-',
      email: row['email'] as String? ?? '-',
      role: row['role'] as String? ?? 'guru',
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] == null ? null : DateTime.tryParse(row['created_at'].toString()),
    );
  }

  String get roleLabel => role == 'admin' ? 'Admin' : 'Guru';
}

class AuditEntry {
  final int id;
  final String actorId;
  final String? actorName;
  final String actorRole;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, dynamic> detail;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.actorId,
    this.actorName,
    required this.actorRole,
    required this.action,
    required this.entity,
    this.entityId,
    required this.detail,
    required this.createdAt,
  });

  String get entityLabel {
    switch (entity) {
      case 'tugas':
        return 'Tugas';
      case 'siswa':
        return 'Siswa';
      case 'kelas':
        return 'Kelas';
      case 'mata_pelajaran':
        return 'Mata Pelajaran';
      case 'jadwal_pelajaran':
        return 'Jadwal';
      case 'profiles':
        return 'Akun';
      case 'kode_akses_siswa':
        return 'Kode Akses';
      default:
        return entity;
    }
  }

  String get actionLabel {
    switch (action) {
      case 'insert':
        return 'Menambahkan';
      case 'update':
        return 'Mengubah';
      case 'delete':
        return 'Menghapus';
      case 'issue':
        return 'Menerbitkan';
      case 'revoke':
        return 'Mencabut';
      default:
        return action;
    }
  }

  factory AuditEntry.fromRow(Map<String, dynamic> row, {String? actorName}) {
    return AuditEntry(
      id: (row['id'] as num?)?.toInt() ?? 0,
      actorId: row['actor_id'] as String? ?? '',
      actorName: actorName,
      actorRole: row['actor_role'] as String? ?? 'system',
      action: row['action'] as String? ?? '-',
      entity: row['entity'] as String? ?? '-',
      entityId: row['entity_id'] as String?,
      detail: row['detail'] is Map ? Map<String, dynamic>.from(row['detail'] as Map) : const {},
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class AkunRepository {
  SupabaseClient? get _c => SupabaseService.tryClient;

  Future<List<ProfileRow>> fetchProfiles({String? search, String? role}) async {
    final c = _c;
    if (c == null) return const [];

    var query = c.from('profiles').select();
    if (role != null && role.isNotEmpty) query = query.eq('role', role);

    final rows = await query.order('full_name');
    var list = rows.map((row) => ProfileRow.fromRow(Map<String, dynamic>.from(row))).toList();

    if (search != null && search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      list = list
          .where((p) =>
              p.fullName.toLowerCase().contains(needle) ||
              p.email.toLowerCase().contains(needle))
          .toList();
    }
    return list;
  }

  Future<void> setActive(String id, bool active) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('profiles').update({'is_active': active}).eq('id', id);
  }

  /// Perubahan role hanya untuk admin. Server tetap memverifikasi lewat RLS
  /// (`is_admin()`), jadi menyembunyikan tombol di UI bukan satu-satunya proteksi.
  Future<void> setRole(String id, String role) async {
    final c = SupabaseService.tryClient;
    if (c == null) throw Exception('Supabase belum dikonfigurasi');
    await c.from('profiles').update({'role': role}).eq('id', id);
  }

  Future<List<AuditEntry>> fetchAudit({int limit = 100}) async {
    final c = _c;
    if (c == null) return const [];

    final rows = await c.from('audit_log').select().order('created_at', ascending: false).limit(limit);
    if (rows.isEmpty) return const [];

    final actorIds = <String>{};
    for (final row in rows) {
      final id = row['actor_id'] as String?;
      if (id != null && id.isNotEmpty) actorIds.add(id);
    }

    final names = <String, String>{};
    if (actorIds.isNotEmpty) {
      try {
        final profiles =
            await c.from('profiles').select('id, full_name').inFilter('id', actorIds.toList());
        for (final row in profiles) {
          names[row['id'] as String] = row['full_name'] as String? ?? '-';
        }
      } catch (_) {
        // nama aktor hanya pelengkap
      }
    }

    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      return AuditEntry.fromRow(map, actorName: names[map['actor_id'] as String?]);
    }).toList();
  }

  /// Hitung ringkasan dashboard.
  ///
  /// Setiap angka dihitung terpisah: satu tabel/fungsi yang belum siap (mis.
  /// `kode_akses_siswa` belum ada karena migration 004/005 belum dijalankan)
  /// tidak boleh menggagalkan seluruh dashboard. Kegagalan dikumpulkan di
  /// [DashboardCounts.issues] agar UI bisa menampilkan peringatan yang jujur
  /// alih-alih angka nol yang menyesatkan.
  Future<DashboardCounts> fetchDashboardCounts() async {
    final c = _c;
    if (c == null) {
      return const DashboardCounts(
        values: {'guru': 0, 'kelas': 0, 'mapel': 0, 'jadwal': 0, 'tugas': 0, 'kode_aktif': 0},
        issues: {},
      );
    }

    Future<int> count(String table, {Map<String, dynamic>? eq}) async {
      var query = c.from(table).select('id');
      if (eq != null) {
        for (final entry in eq.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      final rows = await query;
      return rows.length;
    }

    final values = <String, int>{};
    final issues = <String, AppError>{};

    Future<void> safe(String key, Future<int> Function() run) async {
      try {
        values[key] = await run();
      } catch (e) {
        final error = AppError.from(e);
        // Masalah sesi/jaringan bukan soal data: hentikan agar UI meminta
        // login ulang atau mencoba lagi, bukan menampilkan 0.
        if (SessionGuard.isSessionErrorCode(error.code) ||
            error.code == 'network' ||
            error.code == 'timeout') {
          rethrow;
        }
        issues[key] = error;
      }
    }

    await Future.wait([
      safe('guru', () => count('profiles', eq: {'role': 'guru', 'is_active': true})),
      safe('kelas', () => count('kelas')),
      safe('mapel', () => count('mata_pelajaran')),
      safe('jadwal', () => count('jadwal_pelajaran')),
      safe('tugas', () => count('tugas', eq: {'status_publikasi': 'published'})),
      safe('kode_aktif', () => count('kode_akses_siswa', eq: {'status': 'active'})),
    ]);

    return DashboardCounts(values: values, issues: issues);
  }
}

/// Hasil [AkunRepository.fetchDashboardCounts].
class DashboardCounts {
  /// Nilai per metrik. Kunci yang gagal dihitung tidak ada di sini.
  final Map<String, int> values;

  /// Metrik yang gagal dimuat beserta penyebabnya.
  final Map<String, AppError> issues;

  const DashboardCounts({required this.values, required this.issues});

  int operator [](String key) => values[key] ?? 0;

  /// True bila ada metrik yang tidak bisa dihitung.
  bool get hasIssues => issues.isNotEmpty;

  /// True bila penyebabnya skema database yang belum lengkap.
  bool get schemaNotReady => issues.values.any((e) => e.code == 'schema_not_ready');

  /// True bila metrik tertentu berhasil dimuat.
  bool has(String key) => values.containsKey(key);
}
