import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/models/siswa.dart';
import '../../../shared/services/supabase_service.dart';

class StudentIdentity {
  final String? siswaId;
  final String? siswaNama;
  final String? kelasId;
  final String? kelasNama;
  final String? kodeAkses;
  final String? token;

  const StudentIdentity({this.siswaId, this.siswaNama, this.kelasId, this.kelasNama, this.kodeAkses, this.token});

  bool get isIdentified => siswaId != null && token != null;
  bool get hasKelas => kelasId != null;

  StudentIdentity copyWith({String? siswaId, String? siswaNama, String? kelasId, String? kelasNama, String? kodeAkses, String? token}) {
    return StudentIdentity(
      siswaId: siswaId ?? this.siswaId,
      siswaNama: siswaNama ?? this.siswaNama,
      kelasId: kelasId ?? this.kelasId,
      kelasNama: kelasNama ?? this.kelasNama,
      kodeAkses: kodeAkses ?? this.kodeAkses,
      token: token ?? this.token,
    );
  }
}

class StudentIdentityNotifier extends StateNotifier<StudentIdentity> {
  StudentIdentityNotifier() : super(const StudentIdentity()) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final siswaId = sp.getString(AppConstants.spStudentIdKey);
    final kode = sp.getString(AppConstants.spStudentCodeKey);
    final token = sp.getString(AppConstants.spStudentTokenKey);
    final kelasId = sp.getString(AppConstants.spSelectedKelasId);
    if (siswaId != null && kode != null) {
      // Try to fetch siswa data only if Supabase ready
      if (SupabaseService.isReady) {
        try {
          final client = SupabaseService.tryClient;
          if (client == null) throw Exception('Supabase not ready');
          final data = await client.from('siswa').select('*, kelas(nama_kelas)').eq('id', siswaId).maybeSingle();
          if (data != null) {
            final kelasNama = (data['kelas'] is Map) ? (data['kelas'] as Map)['nama_kelas'] as String? : null;
            state = StudentIdentity(siswaId: siswaId, siswaNama: data['nama'] as String?, kelasId: data['kelas_id'] as String? ?? kelasId, kelasNama: kelasNama, kodeAkses: kode, token: token);
            return;
          }
        } catch (_) {}
      }
      state = StudentIdentity(siswaId: siswaId, kodeAkses: kode, token: token, kelasId: kelasId);
    } else if (kelasId != null) {
      state = StudentIdentity(kelasId: kelasId);
    }
  }

  Future<bool> verifyAndSave(String kode) async {
    try {
      if (!SupabaseService.isReady) return false;
      final client = SupabaseService.tryClient;
      if (client == null) return false;
      // Try Edge Function first
      try {
        final res = await client.functions.invoke('student-access', body: {'kode_akses': kode});
        final raw = res.data;
        // Cast aman: jsonDecode bisa menghasilkan Map<dynamic, dynamic>.
        if (raw is Map && raw['success'] == true) {
          final data = Map<String, dynamic>.from(raw);
          final siswa = data['siswa'] is Map ? Map<String, dynamic>.from(data['siswa'] as Map) : <String, dynamic>{};
          if (siswa['id'] == null) return false;
          final token = data['token'] as String? ?? 'local-${DateTime.now().millisecondsSinceEpoch}';
          final sp = await SharedPreferences.getInstance();
          await sp.setString(AppConstants.spStudentIdKey, siswa['id']?.toString() ?? '');
          await sp.setString(AppConstants.spStudentCodeKey, kode);
          await sp.setString(AppConstants.spStudentTokenKey, token);
          if (siswa['kelas_id'] != null) await sp.setString(AppConstants.spSelectedKelasId, siswa['kelas_id'].toString());
          state = StudentIdentity(
            siswaId: siswa['id']?.toString() ?? '',
            siswaNama: siswa['nama']?.toString(),
            kelasId: siswa['kelas_id']?.toString(),
            kelasNama: siswa['kelas_nama'] as String?,
            kodeAkses: kode,
            token: token,
          );
          return true;
        }
      } catch (_) {
        // fallback to direct query (if RLS allows limited read via anon for kode_akses)
      }

      // Fallback: direct query if RLS allows searching by kode_akses via anon with limited columns
      final data = await client.from('siswa').select('id, nama, kelas_id, kode_akses, kelas(nama_kelas)').eq('kode_akses', kode).maybeSingle();
      if (data == null) return false;
      final kelasNama = (data['kelas'] is Map) ? (data['kelas'] as Map)['nama_kelas'] as String? : null;
      final token = 'local-${data['id']}-${DateTime.now().millisecondsSinceEpoch}';
      final sp = await SharedPreferences.getInstance();
      await sp.setString(AppConstants.spStudentIdKey, data['id']?.toString() ?? '');
      await sp.setString(AppConstants.spStudentCodeKey, kode);
      await sp.setString(AppConstants.spStudentTokenKey, token);
      if (data['kelas_id'] != null) await sp.setString(AppConstants.spSelectedKelasId, data['kelas_id'].toString());
      state = StudentIdentity(
        siswaId: data['id']?.toString() ?? '',
        siswaNama: data['nama']?.toString(),
        kelasId: data['kelas_id']?.toString(),
        kelasNama: kelasNama,
        kodeAkses: kode,
        token: token,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> setKelas(String kelasId, {String? kelasNama}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppConstants.spSelectedKelasId, kelasId);
    state = state.copyWith(kelasId: kelasId, kelasNama: kelasNama);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(AppConstants.spStudentIdKey);
    await sp.remove(AppConstants.spStudentCodeKey);
    await sp.remove(AppConstants.spStudentTokenKey);
    // Keep kelas selection
    state = StudentIdentity(kelasId: state.kelasId, kelasNama: state.kelasNama);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(AppConstants.spStudentIdKey);
    await sp.remove(AppConstants.spStudentCodeKey);
    await sp.remove(AppConstants.spStudentTokenKey);
    await sp.remove(AppConstants.spSelectedKelasId);
    state = const StudentIdentity();
  }
}

final studentIdentityProvider = StateNotifierProvider<StudentIdentityNotifier, StudentIdentity>((ref) => StudentIdentityNotifier());

// Local-only status for fallback when no identity (stored locally, not official)
final localTaskStatusProvider = StateNotifierProvider<LocalTaskStatusNotifier, Map<String, String>>((ref) => LocalTaskStatusNotifier());

class LocalTaskStatusNotifier extends StateNotifier<Map<String, String>> {
  LocalTaskStatusNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().where((k) => k.startsWith('local_task_'));
    final map = <String, String>{};
    for (final k in keys) {
      final v = sp.getString(k);
      if (v != null) map[k.replaceFirst('local_task_', '')] = v;
    }
    state = map;
  }

  Future<void> setStatus(String tugasId, String status) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('local_task_$tugasId', status);
    state = {...state, tugasId: status};
  }

  String getStatus(String tugasId) => state[tugasId] ?? 'belum_selesai';
}
