import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/features/access_codes/domain/access_code.dart';

void main() {
  group('AccessCodeStatusX.fromDb', () {
    test('memetakan status database', () {
      expect(AccessCodeStatusX.fromDb('used'), AccessCodeStatus.used);
      expect(AccessCodeStatusX.fromDb('revoked'), AccessCodeStatus.revoked);
      expect(AccessCodeStatusX.fromDb('expired'), AccessCodeStatus.expired);
      expect(AccessCodeStatusX.fromDb('active'), AccessCodeStatus.active);
    });

    test('nilai tak dikenal dianggap aktif (server tetap memutuskan)', () {
      expect(AccessCodeStatusX.fromDb(null), AccessCodeStatus.active);
      expect(AccessCodeStatusX.fromDb('weird'), AccessCodeStatus.active);
    });

    test('label berbahasa Indonesia', () {
      expect(AccessCodeStatus.active.label, 'Aktif');
      expect(AccessCodeStatus.used.label, 'Sudah dipakai');
      expect(AccessCodeStatus.revoked.label, 'Dicabut');
      expect(AccessCodeStatus.expired.label, 'Kedaluwarsa');
    });
  });

  group('AccessCode.status', () {
    AccessCode build({
      AccessCodeStatus dbStatus = AccessCodeStatus.active,
      DateTime? expiresAt,
    }) {
      return AccessCode(
        id: 'k1',
        prefix: 'EDT-AB',
        kelasId: 'kelas-1',
        singleUse: true,
        dbStatus: dbStatus,
        expiresAt: expiresAt,
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('kode aktif tanpa masa berlaku tetap aktif', () {
      expect(build().isActive, isTrue);
    });

    test('kode aktif yang sudah lewat masa berlaku menjadi kedaluwarsa', () {
      final code = build(expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(code.status, AccessCodeStatus.expired);
      expect(code.isActive, isFalse);
    });

    test('kode aktif dengan masa berlaku ke depan tetap aktif', () {
      final code = build(expiresAt: DateTime.now().add(const Duration(days: 1)));
      expect(code.status, AccessCodeStatus.active);
    });

    test('status revoke tidak ditimpa oleh perhitungan masa berlaku', () {
      final code = build(
        dbStatus: AccessCodeStatus.revoked,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(code.status, AccessCodeStatus.revoked);
    });
  });

  group('AccessCode.fromRow', () {
    test('membaca kolom database tanpa pernah menyimpan plaintext kode', () {
      final code = AccessCode.fromRow({
        'id': 'k9',
        'kode_prefix': 'EDT-ZZ',
        'kelas_id': 'kelas-9',
        'single_use': true,
        'status': 'active',
        'created_at': '2026-02-01T10:00:00Z',
        'note': 'Kelas XI',
      }, kelasNama: 'XI PPLG 1');
      expect(code.prefix, 'EDT-ZZ');
      expect(code.targetLabel, 'XI PPLG 1');
      expect(code.createdAt.year, 2026);
    });

    test('targetLabel memakai nama siswa bila ada', () {
      final code = AccessCode.fromRow({
        'id': 'k10',
        'kelas_id': 'kelas-9',
        'status': 'active',
        'created_at': '2026-02-01T10:00:00Z',
      }, siswaNama: 'Rina');
      expect(code.targetLabel, 'Rina');
    });
  });

  group('AccessCodeStats', () {
    AccessCode code(AccessCodeStatus status, {DateTime? expiresAt}) => AccessCode(
          id: 'x',
          prefix: 'EDT-XX',
          kelasId: 'kelas-1',
          singleUse: true,
          dbStatus: status,
          expiresAt: expiresAt,
          createdAt: DateTime(2026, 1, 1),
        );

    test('fromJson membaca angka dari RPC dan tidak menandai perkiraan', () {
      final stats = AccessCodeStats.fromJson({
        'total': 10,
        'active': 4,
        'used': 3,
        'expired': 2,
        'revoked': 1,
      });
      expect(stats.total, 10);
      expect(stats.active, 4);
      expect(stats.used, 3);
      expect(stats.expired, 2);
      expect(stats.revoked, 1);
      expect(stats.approximate, isFalse);
    });

    test('fromJson mengubah angka string/numerik menjadi int', () {
      final stats = AccessCodeStats.fromJson({
        'total': '7',
        'active': 2.0,
        'used': null,
      });
      expect(stats.total, 7);
      expect(stats.active, 2);
      expect(stats.used, 0);
    });

    test('fromList menghitung cadangan dan menandai approximate', () {
      final stats = AccessCodeStats.fromList([
        code(AccessCodeStatus.active),
        code(AccessCodeStatus.active),
        code(AccessCodeStatus.used),
        code(AccessCodeStatus.revoked),
        code(AccessCodeStatus.active, expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      ]);
      expect(stats.total, 5);
      expect(stats.active, 2);
      expect(stats.used, 1);
      expect(stats.revoked, 1);
      // Kode aktif yang lewat masa berlaku dihitung kedaluwarsa oleh model.
      expect(stats.expired, 1);
      expect(stats.approximate, isTrue);
    });
  });
}
