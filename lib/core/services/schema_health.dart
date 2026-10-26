import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/supabase_service.dart';
import 'session_guard.dart';
import '../utils/app_error.dart';

/// Ringkasan kesehatan skema yang dilaporkan oleh fungsi database
/// `public.edutask_schema_health()` (dibuat pada migration 005).
///
/// Fungsi itu hanya boleh dipanggil admin; guru/siswa akan menerima error
/// "not authorized" dan itu memang perilaku yang diinginkan.
class SchemaHealth {
  /// Versi skema yang dikenali server, mis. `edutask-schema-005`.
  final String version;

  /// Ringkasan keberadaan tabel inti, mis. `{'kode_akses_siswa': true}`.
  final Map<String, bool> tables;

  /// Fungsi yang tersedia (RPC/trigger) beserta statusnya.
  final Map<String, bool> functions;

  /// Tabel yang RLS-nya menyala.
  final Map<String, bool> rlsEnabled;

  /// Jumlah policy per tabel.
  final Map<String, int> policies;

  /// Kolom wajib yang belum ada (kosong berarti lengkap).
  final List<String> missingColumns;

  /// True bila `anon` masih bisa membaca tabel siswa (roster publik).
  final bool anonCanSelectSiswa;

  /// Raw payload, untuk dialog "detail teknis".
  final Map<String, dynamic> raw;

  const SchemaHealth({
    required this.version,
    required this.tables,
    required this.functions,
    required this.rlsEnabled,
    required this.policies,
    required this.missingColumns,
    required this.anonCanSelectSiswa,
    required this.raw,
  });

  /// Semua tabel inti ada, tidak ada kolom hilang, dan RLS menyala.
  bool get isHealthy =>
      missingColumns.isEmpty && tables.values.every((present) => present) && rlsEnabled.values.every((on) => on);

  int get missingTableCount => tables.values.where((present) => !present).length;

  /// Daftar singkat masalah yang bisa ditampilkan ke admin.
  List<String> get issues {
    final result = <String>[];
    final missingTables = tables.entries.where((e) => !e.value).map((e) => e.key).toList();
    if (missingTables.isNotEmpty) {
      result.add('Tabel belum ada: ${missingTables.join(', ')}');
    }
    if (missingColumns.isNotEmpty) {
      result.add('Kolom belum ada: ${missingColumns.join(', ')}');
    }
    final rlsOff = rlsEnabled.entries.where((e) => !e.value).map((e) => e.key).toList();
    if (rlsOff.isNotEmpty) {
      result.add('RLS belum aktif: ${rlsOff.join(', ')}');
    }
    final missingFunctions = functions.entries.where((e) => !e.value).map((e) => e.key).toList();
    if (missingFunctions.isNotEmpty) {
      result.add('Fungsi belum ada: ${missingFunctions.join(', ')}');
    }
    return result;
  }

  static SchemaHealth fromJson(Map<String, dynamic> json) {
    Map<String, bool> boolMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return value.map((k, v) => MapEntry('$k', v == true));
    }

    Map<String, int> intMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return value.map((k, v) {
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        return MapEntry('$k', n);
      });
    }

    final missing = json['missing_columns'];
    return SchemaHealth(
      version: json['version']?.toString() ?? 'tidak diketahui',
      tables: boolMap('tables'),
      functions: boolMap('functions'),
      rlsEnabled: boolMap('rls_enabled'),
      policies: intMap('policies'),
      missingColumns: missing is List ? missing.map((e) => '$e').toList() : const [],
      anonCanSelectSiswa:
          json['anon_can_select_siswa'] == true || json['anon_can_select'] == true,
      raw: json,
    );
  }
}

/// Pemanggil `edutask_schema_health()` dengan sesi yang sudah dipastikan valid.
class SchemaHealthService {
  const SchemaHealthService();

  Future<SchemaHealth> check() async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        hint: 'Periksa --dart-define SUPABASE_URL dan SUPABASE_ANON_KEY.',
        code: 'config',
      );
    }

    final session = await SessionGuard.ensureValidSession();
    if (!session.isReady) {
      throw session.error ??
          const AppError(
            title: 'Sesi login berakhir',
            message: 'Pemeriksaan skema memerlukan sesi admin yang valid.',
            hint: 'Masuk kembali sebagai admin.',
            code: 'session_expired',
          );
    }

    try {
      // RPC dipanggil tanpa argumen; RLS/otorisasi diperiksa di dalam fungsi.
      final data = await client.rpc('edutask_schema_health');
      if (data is! Map) {
        throw const AppError(
          title: 'Hasil tidak dikenali',
          message: 'Server tidak mengembalikan data kesehatan skema.',
          code: 'bad_response',
        );
      }
      return SchemaHealth.fromJson(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }
}

final schemaHealthServiceProvider = Provider<SchemaHealthService>((ref) => const SchemaHealthService());
