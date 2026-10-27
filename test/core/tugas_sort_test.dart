import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/shared/models/tugas.dart';
import 'package:edutask/shared/models/tugas_sort.dart';

Tugas tugas({
  required String id,
  bool pinned = false,
  int position = 0,
  required DateTime tenggat,
  DateTime? created,
}) {
  return Tugas(
    id: id,
    judul: 'Tugas $id',
    deskripsi: '',
    guruId: 'g1',
    kelasId: 'k1',
    mataPelajaranId: 'm1',
    tanggalMulai: DateTime(2026, 1, 1),
    tenggatWaktu: tenggat,
    createdAt: created ?? DateTime(2026, 1, 1),
    updatedAt: created ?? DateTime(2026, 1, 1),
    isPinned: pinned,
    position: position,
  );
}

void main() {
  group('TugasSorting.compare', () {
    test('tugas di-pin selalu di atas tugas biasa', () {
      final pinned = tugas(id: 'a', pinned: true, tenggat: DateTime(2026, 3, 1));
      final biasa = tugas(id: 'b', tenggat: DateTime(2026, 1, 1));
      expect(TugasSorting.compare(pinned, biasa), lessThan(0));
      expect(TugasSorting.compare(biasa, pinned), greaterThan(0));
    });

    test('di antara yang di-pin, position lebih kecil tampil lebih dulu', () {
      final first = tugas(id: 'a', pinned: true, position: 1, tenggat: DateTime(2026, 5, 1));
      final second = tugas(id: 'b', pinned: true, position: 2, tenggat: DateTime(2026, 1, 1));
      expect(TugasSorting.compare(first, second), lessThan(0));
    });

    test('position sama → tenggat lebih awal menang', () {
      final cepat = tugas(id: 'a', pinned: true, position: 1, tenggat: DateTime(2026, 1, 2));
      final lambat = tugas(id: 'b', pinned: true, position: 1, tenggat: DateTime(2026, 1, 9));
      expect(TugasSorting.compare(cepat, lambat), lessThan(0));
    });

    test('tenggat sama → createdAt lalu id sebagai tie-breaker', () {
      final tenggat = DateTime(2026, 2, 2);
      final tua = tugas(id: 'z', tenggat: tenggat, created: DateTime(2026, 1, 1));
      final muda = tugas(id: 'a', tenggat: tenggat, created: DateTime(2026, 1, 2));
      expect(TugasSorting.compare(tua, muda), lessThan(0));

      final idKecil = tugas(id: 'a', tenggat: tenggat, created: DateTime(2026, 1, 1));
      final idBesar = tugas(id: 'b', tenggat: tenggat, created: DateTime(2026, 1, 1));
      expect(TugasSorting.compare(idKecil, idBesar), lessThan(0));
      expect(TugasSorting.compare(idBesar, idKecil), greaterThan(0));
    });

    test('tugas identik dianggap sama (urutan stabil)', () {
      final a = tugas(id: 'a', tenggat: DateTime(2026, 2, 2));
      final b = tugas(id: 'a', tenggat: DateTime(2026, 2, 2));
      expect(TugasSorting.compare(a, b), 0);
    });
  });

  group('TugasSorting.sortForDisplay', () {
    test('data lama (tanpa pin) tetap urut tenggat seperti sebelumnya', () {
      final list = [
        tugas(id: 'c', tenggat: DateTime(2026, 3, 1)),
        tugas(id: 'a', tenggat: DateTime(2026, 1, 1)),
        tugas(id: 'b', tenggat: DateTime(2026, 2, 1)),
      ];
      final sorted = TugasSorting.sortForDisplay(list);
      expect(sorted.map((t) => t.id).toList(), ['a', 'b', 'c']);
    });

    test('hasil akhir: pin → position → tenggat', () {
      final list = [
        tugas(id: 'biasa-awal', tenggat: DateTime(2026, 1, 1)),
        tugas(id: 'pin-2', pinned: true, position: 5, tenggat: DateTime(2026, 6, 1)),
        tugas(id: 'biasa-akhir', tenggat: DateTime(2026, 9, 1)),
        tugas(id: 'pin-1', pinned: true, position: 2, tenggat: DateTime(2026, 7, 1)),
      ];
      final sorted = TugasSorting.sortForDisplay(list);
      expect(sorted.map((t) => t.id).toList(), [
        'pin-1',
        'pin-2',
        'biasa-awal',
        'biasa-akhir',
      ]);
    });

    test('tidak mengubah daftar masukan', () {
      final list = [
        tugas(id: 'b', tenggat: DateTime(2026, 2, 1)),
        tugas(id: 'a', tenggat: DateTime(2026, 1, 1)),
      ];
      TugasSorting.sortForDisplay(list);
      expect(list.map((t) => t.id).toList(), ['b', 'a']);
    });

    test('id unik setelah diurutkan (deterministik)', () {
      final list = [
        for (var i = 0; i < 30; i++)
          tugas(
            id: 't${i % 7}',
            pinned: i % 3 == 0,
            position: i % 4,
            tenggat: DateTime(2026, 1, 1 + (i % 5)),
          ),
      ];
      final a = TugasSorting.sortForDisplay(list).map((t) => t.id).toList();
      final b = TugasSorting.sortForDisplay(list.reversed).map((t) => t.id).toList();
      expect(a, b);
    });
  });

  group('TugasSorting.pinnedCount', () {
    test('menghitung hanya tugas yang di-pin', () {
      final list = [
        tugas(id: 'a', pinned: true, tenggat: DateTime(2026, 1, 1)),
        tugas(id: 'b', tenggat: DateTime(2026, 1, 2)),
        tugas(id: 'c', pinned: true, tenggat: DateTime(2026, 1, 3)),
      ];
      expect(TugasSorting.pinnedCount(list), 2);
      expect(TugasSorting.pinnedCount(const <Tugas>[]), 0);
    });
  });
}
