import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/shared/models/tugas.dart';

const _legacyPayload = <String, dynamic>{
  'id': 't1',
  'judul': 'Tugas lama',
  'deskripsi': 'Dibuat sebelum migration 007',
  'guru_id': 'g1',
  'kelas_id': 'k1',
  'mata_pelajaran_id': 'm1',
  'tanggal_mulai': '2026-01-01T00:00:00Z',
  'tenggat_waktu': '2026-01-08T00:00:00Z',
  'status_publikasi': 'published',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

void main() {
  group('Tugas pin — kompatibilitas data lama', () {
    test('payload tanpa kolom pin tetap terbaca', () {
      final tugas = Tugas.fromJson(Map<String, dynamic>.from(_legacyPayload));
      expect(tugas.isPinned, isFalse);
      expect(tugas.position, 0);
      expect(tugas.judul, 'Tugas lama');
    });

    test('is_pinned null / tipe aneh tidak melempar', () {
      for (final value in <dynamic>[null, '', 'bukan-bool', 0, false]) {
        final tugas = Tugas.fromJson({
          ..._legacyPayload,
          'is_pinned': value,
        });
        expect(tugas.isPinned, isFalse, reason: 'nilai: $value');
      }
    });

    test('is_pinned menerima bool, angka, dan teks dari PostgREST', () {
      expect(
        Tugas.fromJson({..._legacyPayload, 'is_pinned': true}).isPinned,
        isTrue,
      );
      expect(
        Tugas.fromJson({..._legacyPayload, 'is_pinned': 'true'}).isPinned,
        isTrue,
      );
      expect(
        Tugas.fromJson({..._legacyPayload, 'is_pinned': 't'}).isPinned,
        isTrue,
      );
      expect(
        Tugas.fromJson({..._legacyPayload, 'is_pinned': 1}).isPinned,
        isTrue,
      );
    });

    test('position menerima int, double, dan teks', () {
      expect(Tugas.fromJson({..._legacyPayload, 'position': 3}).position, 3);
      expect(Tugas.fromJson({..._legacyPayload, 'position': 2.0}).position, 2);
      expect(Tugas.fromJson({..._legacyPayload, 'position': '5'}).position, 5);
    });

    test('position tidak valid menjadi 0, bukan crash', () {
      expect(Tugas.fromJson({..._legacyPayload, 'position': null}).position, 0);
      expect(Tugas.fromJson({..._legacyPayload, 'position': 'abc'}).position, 0);
    });

    test('toJson tidak pernah mengirim pin dari klien', () {
      final tugas = Tugas.fromJson({
        ..._legacyPayload,
        'is_pinned': true,
        'position': 4,
      });
      final payload = tugas.toJson();
      expect(payload.containsKey('is_pinned'), isFalse);
      expect(payload.containsKey('position'), isFalse);
    });

    test('copyWith mempertahankan nilai pin', () {
      final tugas = Tugas.fromJson({
        ..._legacyPayload,
        'is_pinned': true,
        'position': 2,
      });
      final copy = tugas.copyWith(judul: 'Judul baru');
      expect(copy.isPinned, isTrue);
      expect(copy.position, 2);
      expect(copy.judul, 'Judul baru');
    });

    test('equatable membedakan status pin', () {
      final biasa = Tugas.fromJson(Map<String, dynamic>.from(_legacyPayload));
      final pinned = Tugas.fromJson({
        ..._legacyPayload,
        'is_pinned': true,
      });
      expect(biasa == pinned, isFalse);
    });
  });
}
