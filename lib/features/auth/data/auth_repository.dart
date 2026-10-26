import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/app_user.dart';

class AuthRepository {
  SupabaseClient? get _client => SupabaseService.tryClient;
  SupabaseClient? get _tryClient => SupabaseService.tryClient;

  Future<AppUser?> getCurrentProfile() async {
    if (SupabaseConfig.isNotConfigured) return null;
    final c = _tryClient;
    if (c == null) return null;
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final data = await c.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return AppUser.fromJson(data);
    } catch (e) {
      // Jika RLS blocked atau belum ada profile
      return null;
    }
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    if (SupabaseConfig.isNotConfigured) throw Exception('Supabase belum dikonfigurasi');
    final c = _tryClient;
    if (c == null) throw Exception('Supabase belum siap');
    final res = await c.auth.signInWithPassword(email: email, password: password);
    return res;
  }

  Future<void> signOut() async {
    await _tryClient?.auth.signOut();
  }

  Future<AppUser?> fetchProfileById(String userId) async {
    final c = _tryClient;
    if (c == null) return null;
    final data = await c.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  Stream<AuthState> authStateChanges() {
    final c = _tryClient;
    if (c == null) return const Stream.empty();
    return c.auth.onAuthStateChange;
  }

  /// Untuk admin: membuat akun guru via Edge Function (aman, service_role di server).
  ///
  /// Perbaikan 401:
  /// - Sesi admin selalu divalidasi/di-refresh sebelum invoke (token expired = 401).
  /// - Access token sesi admin dikirim eksplisit pada header Authorization.
  /// - Error 401/403/404/5xx dipetakan ke pesan yang berbeda dan dapat ditindaklanjuti.
  Future<Map<String, dynamic>> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final gc = _tryClient;
    if (gc == null) {
      throw const TeacherInviteException(
        'config',
        'Supabase belum dikonfigurasi pada build ini. Hubungi admin untuk build ulang dengan SUPABASE_URL & SUPABASE_ANON_KEY.',
      );
    }

    // 1) Pastikan ada sesi admin.
    if (gc.auth.currentSession == null) {
      throw const TeacherInviteException(
        'session_expired',
        'Sesi login admin tidak ditemukan. Silakan login ulang sebagai admin.',
      );
    }

    // 2) Refresh token bila perlu. Ini mencegah 401 karena access token kedaluwarsa.
    //    Kegagalan refresh (mis. jaringan) tidak langsung dianggap fatal: token yang
    //    tersimpan masih dicoba, dan status kedaluwarsanya diperiksa di bawah.
    try {
      await gc.auth.refreshSession();
    } catch (_) {
      // Lanjutkan dengan token yang masih tersimpan.
    }

    final session = gc.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw const TeacherInviteException(
        'session_expired',
        'Access token admin tidak tersedia. Silakan login ulang sebagai admin.',
      );
    }
    var tokenExpired = false;
    try {
      tokenExpired = session.isExpired;
    } catch (_) {
      // Token tidak bisa diparse: biarkan server yang menilai (hasilnya 401).
    }
    if (tokenExpired) {
      throw const TeacherInviteException(
        'session_expired',
        'Access token admin kedaluwarsa. Silakan login ulang sebagai admin.',
      );
    }

    try {
      final res = await gc.functions.invoke(
        'create-teacher',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
        // Kirim token sesi admin yang sudah di-refresh secara eksplisit.
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['success'] == true || map['user_id'] != null) return map;
        // Edge case: function membalas 2xx tetapi berisi {error: ...}
        throw _mapServerError(res.status, map);
      }
      return {'success': true, 'data': data};
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on TeacherInviteException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('clientexception') ||
          lower.contains('network') ||
          lower.contains('timeout')) {
        throw const TeacherInviteException(
          'network',
          'Tidak dapat menghubungi server. Periksa koneksi internet lalu coba lagi.',
        );
      }
      throw TeacherInviteException(
        'unknown',
        'Gagal membuat akun guru: $msg',
      );
    }
  }

  TeacherInviteException _mapFunctionException(FunctionException e) {
    return TeacherInviteException.fromFunctionError(
      status: e.status,
      details: e.details,
      reasonPhrase: e.reasonPhrase,
    );
  }

  TeacherInviteException _mapServerError(int status, Map<String, dynamic> body) {
    return TeacherInviteException.fromFunctionError(
      status: status,
      details: body,
      reasonPhrase: null,
    );
  }
}

/// Error terstruktur untuk proses undang guru, agar UI bisa membedakan
/// sesi kedaluwarsa, akses ditolak, function belum dideploy, dan gangguan server.
class TeacherInviteException implements Exception {
  /// Kode: config, session_expired, unauthorized, forbidden, not_deployed,
  /// network, invalid_input, server, unknown.
  final String code;
  final String message;
  final int? status;

  const TeacherInviteException(this.code, this.message, {this.status});

  /// Sesi benar-benar tidak bisa dipakai lagi → arahkan login ulang.
  bool get requiresRelogin => code == 'session_expired';

  /// Petakan respons error Edge Function menjadi pesan yang bisa ditindaklanjuti.
  /// Dipisah sebagai factory agar mudah diuji tanpa jaringan.
  factory TeacherInviteException.fromFunctionError({
    required int status,
    dynamic details,
    String? reasonPhrase,
  }) {
    String detail = '';
    if (details is Map) {
      detail = (details['error'] ?? details['message'] ?? '').toString();
    } else if (details != null) {
      detail = details.toString();
    }
    final note = detail.isEmpty ? (reasonPhrase ?? '') : detail;

    if (status == 401) {
      // 401 dari gateway = JWT tidak valid; 401 dari function = token ditolak GoTrue.
      return TeacherInviteException(
        'unauthorized',
        'HTTP 401 — server menolak kredensial admin. '
            '${note.isEmpty ? '' : 'Detail: $note. '}'
            'Kemungkinan: (a) sesi sudah kedaluwarsa, '
            '(b) APK dibuild dengan SUPABASE_URL/ANON_KEY dari project berbeda, atau '
            '(c) function create-teacher tidak berada di project yang sama. '
            'Login ulang lalu coba lagi; jika tetap gagal, samakan konfigurasi project.',
        status: 401,
      );
    }
    if (status == 403) {
      return TeacherInviteException(
        'forbidden',
        'HTTP 403 — akun ini bukan admin aktif. '
            '${note.isEmpty ? '' : 'Detail: $note. '}'
            'Pastikan baris di tabel profiles memiliki role = admin dan is_active = true.',
        status: 403,
      );
    }
    if (status == 404) {
      return const TeacherInviteException(
        'not_deployed',
        'HTTP 404 — Edge Function create-teacher tidak ditemukan pada project ini. '
            'Deploy dengan: supabase link --project-ref <ref> lalu '
            'supabase functions deploy create-teacher.',
        status: 404,
      );
    }
    if (status == 400 || status == 409 || status == 422) {
      return TeacherInviteException(
        'invalid_input',
        'Permintaan ditolak: ${note.isEmpty ? 'data guru tidak valid atau email sudah terdaftar.' : note}',
        status: status,
      );
    }
    if (status == 0) {
      return const TeacherInviteException(
        'network',
        'Tidak dapat menghubungi server Edge Function. Periksa koneksi internet.',
        status: 0,
      );
    }
    if (status == 500 || status == 503) {
      return TeacherInviteException(
        'server',
        'Server gagal memproses pembuatan akun guru (HTTP $status). '
            '${note.isEmpty ? '' : 'Detail: $note. '}'
            'Pastikan secret SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY tersedia di Edge Function.',
        status: status,
      );
    }
    return TeacherInviteException(
      'server',
      'Gagal membuat akun guru (HTTP $status ${reasonPhrase ?? ''}). '
          '${note.isEmpty ? '' : 'Detail: $note'}',
      status: status,
    );
  }

  @override
  String toString() => message;
}
