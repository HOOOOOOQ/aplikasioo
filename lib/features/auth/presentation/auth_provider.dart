import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<AuthState>((ref) {
  if (SupabaseConfig.isNotConfigured) return const Stream.empty();
  final repo = ref.watch(authRepositoryProvider);
  try {
    return repo.authStateChanges();
  } catch (_) {
    return const Stream.empty();
  }
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  if (SupabaseConfig.isNotConfigured) return null;
  final repo = ref.watch(authRepositoryProvider);
  // depend on auth state to auto-refresh — guard agar tidak crash
  try {
    ref.watch(authStateProvider);
  } catch (_) {}
  // Error dibiarkan naik: splash menampilkan kartu "gagal memuat sesi" dengan
  // tombol coba lagi, bukan berpura-pura pengguna belum login.
  return repo.getCurrentProfile();
});

// Sync provider for quick access
final appUserProvider = StateProvider<AppUser?>((ref) => null);

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _repo;
  final Ref _ref;
  AuthController(this._repo, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.getCurrentProfile();
      _ref.read(appUserProvider.notifier).state = user;
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signIn(email: email, password: password);
      final user = await _repo.getCurrentProfile();
      _ref.read(appUserProvider.notifier).state = user;
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _ref.read(appUserProvider.notifier).state = null;
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo, ref);
});
