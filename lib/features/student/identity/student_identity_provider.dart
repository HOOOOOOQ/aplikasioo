import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/utils/app_error.dart';
import '../../../shared/services/supabase_service.dart';

/// Identitas siswa yang tersimpan di perangkat.
///
/// [token] adalah token bertanda tangan HMAC dari Edge Function — satu-satunya
/// bukti bahwa identitas pernah diverifikasi server. Tanpa token, status tugas
/// hanya boleh disimpan lokal (tidak resmi).
class StudentIdentity {
  final String? siswaId;
  final String? siswaNama;
  final String? kelasId;
  final String? kelasNama;
  final String? token;
  final DateTime? verifiedAt;

  const StudentIdentity({
    this.siswaId,
    this.siswaNama,
    this.kelasId,
    this.kelasNama,
    this.token,
    this.verifiedAt,
  });

  bool get isIdentified =>
      siswaId != null && siswaId!.isNotEmpty && token != null && token!.isNotEmpty;

  bool get hasKelas => kelasId != null && kelasId!.isNotEmpty;

  StudentIdentity copyWith({
    String? siswaId,
    String? siswaNama,
    String? kelasId,
    String? kelasNama,
    String? token,
    DateTime? verifiedAt,
  }) {
    return StudentIdentity(
      siswaId: siswaId ?? this.siswaId,
      siswaNama: siswaNama ?? this.siswaNama,
      kelasId: kelasId ?? this.kelasId,
      kelasNama: kelasNama ?? this.kelasNama,
      token: token ?? this.token,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

/// Hasil verifikasi kode.
class RedeemResult {
  final bool ok;

  /// True bila kode berlaku untuk satu kelas dan siswa harus memilih namanya.
  final bool needsClassSelection;
  final String? claimToken;
  final String? kelasId;
  final String? kelasNama;
  final String? siswaId;
  final String? siswaNama;
  final AppError? error;

  const RedeemResult.success({
    this.needsClassSelection = false,
    this.claimToken,
    this.kelasId,
    this.kelasNama,
    this.siswaId,
    this.siswaNama,
  })  : ok = true,
        error = null;

  const RedeemResult.failure(AppError this.error)
      : ok = false,
        needsClassSelection = false,
        claimToken = null,
        kelasId = null,
        kelasNama = null,
        siswaId = null,
        siswaNama = null;
}

class StudentIdentityNotifier extends StateNotifier<StudentIdentity> {
  StudentIdentityNotifier() : super(const StudentIdentity()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final siswaId = sp.getString(AppConstants.spStudentIdKey);
      final token = sp.getString(AppConstants.spStudentTokenKey);
      final nama = sp.getString(AppConstants.spStudentNameKey);
      final kelasId = sp.getString(AppConstants.spSelectedKelasId);
      final kelasNama = sp.getString(AppConstants.spStudentKelasNamaKey);
      final verifiedRaw = sp.getString(AppConstants.spStudentVerifiedAtKey);
      final verifiedAt = verifiedRaw == null ? null : DateTime.tryParse(verifiedRaw);

      if (siswaId != null && siswaId.isNotEmpty && token != null && token.isNotEmpty) {
        state = StudentIdentity(
          siswaId: siswaId,
          siswaNama: nama,
          kelasId: kelasId,
          kelasNama: kelasNama,
          token: token,
          verifiedAt: verifiedAt,
        );
        return;
      }

      // Belum terverifikasi — hanya kelas yang dipilih manual.
      state = StudentIdentity(kelasId: kelasId, kelasNama: kelasNama);
    } catch (_) {
      state = const StudentIdentity();
    }
  }

  /// Verifikasi kode ke server. Tidak ada pemeriksaan "valid" di sisi Flutter.
  Future<RedeemResult> verifyCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      return const RedeemResult.failure(
        AppError(
          title: 'Kode kosong',
          message: 'Masukkan kode akses yang diberikan admin atau guru.',
          code: 'empty_code',
        ),
      );
    }

    final client = SupabaseService.tryClient;
    if (client == null) {
      return const RedeemResult.failure(
        AppError(
          title: 'Belum terhubung',
          message: 'Aplikasi belum terhubung ke server pada build ini.',
          hint: 'Hubungi pengelola aplikasi.',
          code: 'config',
        ),
      );
    }

    try {
      final res = await client.functions.invoke('student-access', body: {'kode_akses': code});
      final data = res.data;
      if (data is! Map) {
        return const RedeemResult.failure(
          AppError(title: 'Respons tidak valid', message: 'Server tidak mengembalikan data identitas.', code: 'bad_response'),
        );
      }
      final map = Map<String, dynamic>.from(data);

      if (map['mode'] == 'kelas') {
        final kelas = map['kelas'] is Map ? Map<String, dynamic>.from(map['kelas'] as Map) : <String, dynamic>{};
        return RedeemResult.success(
          needsClassSelection: true,
          claimToken: map['claim_token'] as String?,
          kelasId: kelas['id'] as String?,
          kelasNama: kelas['nama'] as String?,
        );
      }

      final siswa = map['siswa'] is Map ? Map<String, dynamic>.from(map['siswa'] as Map) : <String, dynamic>{};
      final siswaId = siswa['id']?.toString();
      final token = map['token'] as String?;
      if (siswaId == null || siswaId.isEmpty || token == null || token.isEmpty) {
        return const RedeemResult.failure(
          AppError(title: 'Respons tidak lengkap', message: 'Server tidak mengirim identitas siswa.', code: 'bad_response'),
        );
      }

      await _persist(
        siswaId: siswaId,
        siswaNama: siswa['nama']?.toString(),
        kelasId: siswa['kelas_id']?.toString(),
        kelasNama: siswa['kelas_nama']?.toString(),
        token: token,
      );

      return RedeemResult.success(
        siswaId: siswaId,
        siswaNama: siswa['nama']?.toString(),
        kelasId: siswa['kelas_id']?.toString(),
        kelasNama: siswa['kelas_nama']?.toString(),
      );
    } on FunctionException catch (e) {
      return RedeemResult.failure(_functionError(e));
    } catch (e) {
      return RedeemResult.failure(AppError.from(e));
    }
  }

  /// Langkah kedua untuk kode kelas: siswa memilih namanya, server memvalidasi
  /// bahwa siswa tersebut memang berada di kelas kode.
  Future<RedeemResult> bindClassIdentity({
    required String claimToken,
    required String siswaId,
    required String siswaNama,
    String? kelasId,
    String? kelasNama,
  }) async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      return const RedeemResult.failure(
        AppError(title: 'Belum terhubung', message: 'Aplikasi belum terhubung ke server.', code: 'config'),
      );
    }

    try {
      final res = await client.functions.invoke('student-access', body: {
        'claim_token': claimToken,
        'siswa_id': siswaId,
      });
      final data = res.data;
      if (data is! Map) {
        return const RedeemResult.failure(
          AppError(title: 'Respons tidak valid', message: 'Server tidak mengembalikan identitas.', code: 'bad_response'),
        );
      }
      final map = Map<String, dynamic>.from(data);
      final siswa = map['siswa'] is Map ? Map<String, dynamic>.from(map['siswa'] as Map) : <String, dynamic>{};
      final token = map['token'] as String?;
      final id = siswa['id']?.toString() ?? siswaId;
      if (token == null || token.isEmpty) {
        return const RedeemResult.failure(
          AppError(title: 'Gagal menautkan identitas', message: 'Token tidak diterima dari server.', code: 'bad_response'),
        );
      }

      await _persist(
        siswaId: id,
        siswaNama: siswa['nama']?.toString() ?? siswaNama,
        kelasId: siswa['kelas_id']?.toString() ?? kelasId,
        kelasNama: siswa['kelas_nama']?.toString() ?? kelasNama,
        token: token,
      );

      return RedeemResult.success(
        siswaId: id,
        siswaNama: siswa['nama']?.toString() ?? siswaNama,
        kelasId: siswa['kelas_id']?.toString() ?? kelasId,
        kelasNama: siswa['kelas_nama']?.toString() ?? kelasNama,
      );
    } on FunctionException catch (e) {
      return RedeemResult.failure(_functionError(e));
    } catch (e) {
      return RedeemResult.failure(AppError.from(e));
    }
  }

  Future<void> _persist({
    required String siswaId,
    String? siswaNama,
    String? kelasId,
    String? kelasNama,
    required String token,
  }) async {
    final now = DateTime.now();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppConstants.spStudentIdKey, siswaId);
    await sp.setString(AppConstants.spStudentTokenKey, token);
    if (siswaNama != null) await sp.setString(AppConstants.spStudentNameKey, siswaNama);
    if (kelasId != null && kelasId.isNotEmpty) {
      await sp.setString(AppConstants.spSelectedKelasId, kelasId);
    }
    if (kelasNama != null) await sp.setString(AppConstants.spStudentKelasNamaKey, kelasNama);
    await sp.setString(AppConstants.spStudentVerifiedAtKey, now.toIso8601String());

    state = StudentIdentity(
      siswaId: siswaId,
      siswaNama: siswaNama,
      kelasId: kelasId,
      kelasNama: kelasNama,
      token: token,
      verifiedAt: now,
    );
  }

  AppError _functionError(FunctionException e) {
    // AppError sudah memetakan 403/404/409/410/429 menjadi pesan yang jelas.
    final mapped = AppError.from(e);
    if (e.status == 409) {
      return AppError(
        title: 'Kode sudah dipakai',
        message: mapped.message,
        hint: 'Minta kode baru kepada admin atau guru.',
        code: mapped.code,
      );
    }
    if (e.status == 410) {
      return AppError(
        title: 'Kode kedaluwarsa',
        message: mapped.message,
        hint: 'Minta kode baru kepada admin atau guru.',
        code: mapped.code,
      );
    }
    return mapped;
  }

  Future<void> setKelas(String kelasId, {String? kelasNama}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppConstants.spSelectedKelasId, kelasId);
    state = state.copyWith(kelasId: kelasId, kelasNama: kelasNama);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(AppConstants.spStudentIdKey);
    await sp.remove(AppConstants.spStudentTokenKey);
    await sp.remove(AppConstants.spStudentNameKey);
    await sp.remove(AppConstants.spStudentKelasNamaKey);
    await sp.remove(AppConstants.spStudentVerifiedAtKey);
    state = StudentIdentity(kelasId: state.kelasId, kelasNama: state.kelasNama);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(AppConstants.spStudentIdKey);
    await sp.remove(AppConstants.spStudentTokenKey);
    await sp.remove(AppConstants.spStudentNameKey);
    await sp.remove(AppConstants.spStudentKelasNamaKey);
    await sp.remove(AppConstants.spStudentVerifiedAtKey);
    await sp.remove(AppConstants.spSelectedKelasId);
    state = const StudentIdentity();
  }
}

final studentIdentityProvider =
    StateNotifierProvider<StudentIdentityNotifier, StudentIdentity>((ref) => StudentIdentityNotifier());

/// Status penyelesaian yang HANYA tersimpan di perangkat (tidak resmi).
final localTaskStatusProvider =
    StateNotifierProvider<LocalTaskStatusNotifier, Map<String, String>>((ref) => LocalTaskStatusNotifier());

class LocalTaskStatusNotifier extends StateNotifier<Map<String, String>> {
  LocalTaskStatusNotifier() : super({}) {
    _load();
  }

  static const String _prefix = 'local_task_';

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final keys = sp.getKeys().where((k) => k.startsWith(_prefix));
      final map = <String, String>{};
      for (final key in keys) {
        final value = sp.getString(key);
        if (value != null) map[key.replaceFirst(_prefix, '')] = value;
      }
      state = map;
    } catch (_) {
      state = {};
    }
  }

  Future<void> setStatus(String tugasId, String status) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_prefix$tugasId', status);
    state = {...state, tugasId: status};
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    for (final key in sp.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await sp.remove(key);
    }
    state = {};
  }

  String getStatus(String tugasId) => state[tugasId] ?? 'belum_selesai';
}

/// Helper kecil dipakai halaman untuk membaca isi token tanpa verifikasi
/// (hanya untuk menampilkan "sesi berakhir" — keputusan tetap di server).
DateTime? accessTokenExpiry(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length < 2) return null;
  final exp = int.tryParse(parts[1]);
  if (exp == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
}

/// Utilitas untuk mem-parse pesan error dari body JSON Edge Function.
String describeFunctionDetails(dynamic details) {
  if (details is Map) {
    return (details['error'] ?? details['message'] ?? '').toString();
  }
  if (details is String) {
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map) return (decoded['error'] ?? decoded['message'] ?? '').toString();
    } catch (_) {}
    return details;
  }
  return '';
}
