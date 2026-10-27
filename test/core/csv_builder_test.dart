import 'package:edutask/core/services/csv_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvBuilder.escape', () {
    test('nilai biasa dibiarkan apa adanya', () {
      expect(CsvBuilder.escape('Tugas Matematika'), 'Tugas Matematika');
      expect(CsvBuilder.escape(42), '42');
    });

    test('nilai null menjadi string kosong', () {
      expect(CsvBuilder.escape(null), '');
    });

    test('koma dan tanda kutip dibungkus serta digandakan', () {
      expect(CsvBuilder.escape('A, B'), '"A, B"');
      expect(CsvBuilder.escape('Rumus "x"'), '"Rumus ""x"""');
    });

    test('baris baru tetap di dalam satu field', () {
      expect(CsvBuilder.escape('baris1\nbaris2'), '"baris1\nbaris2"');
    });

    test('titik koma dikutip agar aman untuk Excel regional', () {
      expect(CsvBuilder.escape('Senin;07:00'), '"Senin;07:00"');
    });

    test('formula spreadsheet dinetralkan dengan apostrof', () {
      expect(CsvBuilder.escape('=SUM(A1:A2)'), "'=SUM(A1:A2)");
      expect(CsvBuilder.escape('+62 812'), "'+62 812");
      expect(CsvBuilder.escape('-1'), "'-1");
      expect(CsvBuilder.escape('@user'), "'@user");
    });
  });

  group('CsvBuilder.build', () {
    test('menggabungkan baris dengan CRLF dan melewati baris kosong', () {
      final csv = CsvBuilder.build([
        ['Nama', 'Kelas'],
        ['Ani', 'X PPLG 1'],
        <Object?>[],
        ['Budi', 'XI PPLG 2'],
      ]);
      expect(csv, 'Nama,Kelas\r\nAni,X PPLG 1\r\nBudi,XI PPLG 2\r\n');
    });

    test('header saja tetap menghasilkan satu baris valid', () {
      expect(CsvBuilder.build([['A']]), 'A\r\n');
    });

    test('data kosong menghasilkan string kosong, bukan crash', () {
      expect(CsvBuilder.build(const []), '');
    });
  });

  group('CsvBuilder.fileName', () {
    test('prefix disanitasi dan diberi cap waktu', () {
      final name = CsvBuilder.fileName('Laporan Tugas / Semua Kelas', DateTime(2026, 10, 27, 9, 5));
      expect(name, 'laporan-tugas-semua-kelas-2026-10-27-0905.csv');
    });

    test('prefix kosong memakai nama default edutask', () {
      expect(CsvBuilder.fileName('  ', DateTime(2026, 1, 2, 3, 4)), 'edutask-2026-01-02-0304.csv');
    });
  });
}
