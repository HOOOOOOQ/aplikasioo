import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/shared/models/tugas.dart';
import 'package:edutask/shared/models/tugas_pin_policy.dart';

Tugas tugasMilik(String guruId) => Tugas(
      id: 't1',
      judul: 'Tugas',
      deskripsi: '',
      guruId: guruId,
      kelasId: 'k1',
      mataPelajaranId: 'm1',
      tanggalMulai: DateTime(2026, 1, 1),
      tenggatWaktu: DateTime(2026, 1, 8),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('TugasPinPolicy.canManage', () {
    test('admin boleh mengatur pin semua tugas', () {
      expect(
        TugasPinPolicy.canManage(
          isAdmin: true,
          isGuru: false,
          userId: 'admin-1',
          tugas: tugasMilik('guru-1'),
        ),
        isTrue,
      );
    });

    test('guru pemilik tugas boleh mengatur pin', () {
      expect(
        TugasPinPolicy.canManage(
          isAdmin: false,
          isGuru: true,
          userId: 'guru-1',
          tugas: tugasMilik('guru-1'),
        ),
        isTrue,
      );
    });

    test('guru lain tidak boleh mengatur pin tugas orang lain', () {
      expect(
        TugasPinPolicy.canManage(
          isAdmin: false,
          isGuru: true,
          userId: 'guru-2',
          tugas: tugasMilik('guru-1'),
        ),
        isFalse,
      );
    });

    test('siswa / peran tidak dikenal tidak boleh mengatur pin', () {
      expect(
        TugasPinPolicy.canManage(
          isAdmin: false,
          isGuru: false,
          userId: 'siswa-1',
          tugas: tugasMilik('guru-1'),
        ),
        isFalse,
      );
    });

    test('sesi tanpa user id ditolak', () {
      expect(
        TugasPinPolicy.canManage(
          isAdmin: false,
          isGuru: true,
          userId: null,
          tugas: tugasMilik('guru-1'),
        ),
        isFalse,
      );
      expect(
        TugasPinPolicy.canManage(
          isAdmin: false,
          isGuru: true,
          userId: '',
          tugas: tugasMilik('guru-1'),
        ),
        isFalse,
      );
    });

    test('policy ini hanya penyaring UI (server tetap memeriksa)', () {
      // Dokumentasi perilaku: admin selalu boleh, terlepas dari guruId.
      expect(
        TugasPinPolicy.canManage(
          isAdmin: true,
          isGuru: true,
          userId: null,
          tugas: tugasMilik(''),
        ),
        isTrue,
      );
    });
  });
}
