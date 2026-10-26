import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/app_user.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;
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

  /// Untuk admin: membuat akun guru via Edge Function (aman, service_role di server)
  /// Jika Edge Function belum tersedia, fallback akan error dengan pesan jelas.
  Future<Map<String, dynamic>> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final gc = _tryClient;
      if (gc == null) throw Exception('Supabase belum dikonfigurasi');
      final res = await gc.functions.invoke(
        'create-teacher',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return {'success': true, 'data': data};
    } catch (e) {
      throw Exception('Gagal membuat akun guru: ${e.toString()}. Pastikan Edge Function create-teacher sudah dideploy dan service_role key aman di server.');
    }
  }
}
