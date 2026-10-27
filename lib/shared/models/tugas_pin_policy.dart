import 'tugas.dart';

/// Aturan **tampilan** untuk tombol pin/unpin.
///
/// Ini hanya penyaring UI supaya tombol tidak muncul bagi peran yang tidak
/// berhak. Keamanan sebenarnya ada di server: policy RLS `tugas`
/// (`Admin manage tugas`, `Guru manage own tugas`) dan pemeriksaan ulang di
/// dalam RPC `set_tugas_pin` (migration 007). Menyembunyikan tombol **bukan**
/// kontrol keamanan.
class TugasPinPolicy {
  TugasPinPolicy._();

  /// `true` bila pengguna boleh mengubah status pin tugas ini.
  ///
  /// [isAdmin] dan [isGuru] berasal dari profil yang diverifikasi server
  /// (`profiles.role`), bukan dari input pengguna.
  static bool canManage({
    required bool isAdmin,
    required bool isGuru,
    required String? userId,
    required Tugas tugas,
  }) {
    if (isAdmin) return true;
    if (!isGuru) return false;
    if (userId == null || userId.isEmpty) return false;
    return tugas.guruId == userId;
  }
}
