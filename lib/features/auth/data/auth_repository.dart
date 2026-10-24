import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/app_user.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<AppUser?> getCurrentProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return AppUser.fromJson(data);
    } catch (e) {
      // Jika RLS blocked atau belum ada profile
      return null;
    }
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    return res;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AppUser?> fetchProfileById(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  /// Untuk admin: membuat akun guru via Edge Function (aman, service_role di server)
  /// Jika Edge Function belum tersedia, fallback akan error dengan pesan jelas.
  Future<Map<String, dynamic>> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final res = await _client.functions.invoke(
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
