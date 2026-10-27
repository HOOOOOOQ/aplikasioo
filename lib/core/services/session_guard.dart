import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_error.dart';
import '../../shared/services/supabase_service.dart';

/// Hasil pemeriksaan sesi sebelum operasi yang butuh login.
enum SessionState {
  /// Sesi ada dan token masih berlaku (atau berhasil di-refresh).
  ready,

  /// Tidak ada sesi tersimpan — pengguna memang belum login / sudah logout.
  noSession,

  /// Refresh token ditolak server (sesi benar-benar berakhir).
  expired,

  /// Refresh gagal karena jaringan, bukan karena sesi tidak valid.
  networkError,
}

class SessionResult {
  final SessionState state;

  /// Access token yang siap dipakai (null bila [state] bukan ready).
  final String? accessToken;

  /// True bila token lama masih dipakai karena refresh gagal sementara
  /// (mis. offline). Server tetap memutuskan apakah token masih diterima.
  final bool degraded;

  final AppError? error;

  const SessionResult({
    required this.state,
    this.accessToken,
    this.degraded = false,
    this.error,
  });

  bool get isReady => state == SessionState.ready && (accessToken?.isNotEmpty ?? false);

  /// Sesi tidak bisa dipakai lagi → UI harus mengarahkan pengguna ke login.
  bool get requiresRelogin =>
      state == SessionState.noSession || state == SessionState.expired;

  const SessionResult.ready(String token, {this.degraded = false})
      : state = SessionState.ready,
        accessToken = token,
        error = null;

  const SessionResult.failed(
    SessionState failedState,
    AppError failure, {
    this.degraded = false,
  })  : state = failedState,
        accessToken = null,
        error = failure;
}

/// Satu pintu pemeriksaan sesi Supabase sebelum operasi administratif.
///
/// Alur yang ditangani:
///  1. Tidak ada sesi  → [SessionState.noSession] (jangan panggil server).
///  2. Token kedaluwarsa → refresh lewat mekanisme resmi GoTrue.
///  3. Refresh gagal karena jaringan → token lama tetap dipakai bila belum
///     kedaluwarsa; sesi TIDAK dianggap mati.
///  4. Refresh ditolak (refresh token invalid/revoked) → [SessionState.expired].
///
/// Tidak ada password yang disimpan, tidak ada token yang dibuat sendiri, dan
/// validasi JWT di server tetap wajib.
class SessionGuard {
  SessionGuard._();

  static const AppError _noSessionError = AppError(
    title: 'Belum masuk',
    message: 'Sesi login tidak ditemukan di perangkat ini.',
    hint: 'Masuk kembali sebagai admin atau guru.',
    code: 'no_session',
  );

  static const AppError _expiredError = AppError(
    title: 'Sesi login berakhir',
    message: 'Masa berlaku sesi Anda sudah habis.',
    hint: 'Masuk kembali sebagai admin atau guru. Data yang sudah tersimpan tidak hilang.',
    code: 'session_expired',
  );

  static const AppError _networkError = AppError(
    title: 'Tidak ada koneksi',
    message: 'Sesi tidak dapat diperbarui karena perangkat tidak terhubung ke server.',
    hint: 'Periksa internet lalu coba lagi.',
    code: 'network',
  );

  /// Periksa (dan bila perlu perbarui) sesi.
  ///
  /// [forceRefresh] dipakai saat server menolak token (401) padahal pemeriksaan
  /// lokal menganggapnya masih berlaku.
  static Future<SessionResult> ensureValidSession({bool forceRefresh = false}) async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      return const SessionResult.failed(
        SessionState.noSession,
        AppError(
          title: 'Belum terhubung',
          message: 'Aplikasi belum terhubung ke server Supabase pada build ini.',
          hint: 'Hubungi pengelola aplikasi.',
          code: 'config',
        ),
      );
    }

    final session = client.auth.currentSession;
    if (session == null) {
      return const SessionResult.failed(SessionState.noSession, _noSessionError);
    }

    final expired = isExpired(session);
    if (!forceRefresh && !expired) {
      return SessionResult.ready(session.accessToken);
    }

    try {
      final response = await client.auth.refreshSession();
      final refreshed = response.session ?? client.auth.currentSession;
      if (refreshed == null || refreshed.accessToken.isEmpty) {
        return const SessionResult.failed(SessionState.expired, _expiredError);
      }
      return SessionResult.ready(refreshed.accessToken);
    } catch (e) {
      if (isNetworkFailure(e)) {
        // Jaringan bermasalah bukan berarti sesi dicabut. Token lama masih
        // dicoba selama belum kedaluwarsa.
        if (!expired && session.accessToken.isNotEmpty) {
          return SessionResult.ready(session.accessToken, degraded: true);
        }
        return const SessionResult.failed(SessionState.networkError, _networkError);
      }
      return const SessionResult.failed(SessionState.expired, _expiredError);
    }
  }

  /// True bila token sesi sudah lewat masa berlaku.
  static bool isExpired(Session session) {
    try {
      return session.isExpired;
    } catch (_) {
      // Token tidak bisa diparse: biarkan server yang menilai.
      return false;
    }
  }

  /// Heuristik kegagalan jaringan (bukan penolakan kredensial).
  ///
  /// Signature `refreshSession()` di GoTrue melempar `AuthException` untuk
  /// token tidak valid dan exception fetch untuk masalah koneksi; keduanya
  /// dibedakan lewat pesan agar tidak bergantung pada tipe internal SDK.
  static bool isNetworkFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('handshakeexception') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('failed to fetch') ||
        text.contains('xmlhttprequest');
  }

  /// Pesan 401 dari Edge Function yang berarti sesi (bukan input) bermasalah.
  static bool isSessionErrorCode(String? code) => const {
        'session_expired',
        'invalid_token',
        'missing_token',
        'unauthorized',
        'no_session',
      }.contains(code);
}
