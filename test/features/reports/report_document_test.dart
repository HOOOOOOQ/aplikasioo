import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:edutask/core/services/csv_builder.dart';
import 'package:edutask/features/reports/domain/report_document.dart';
import 'package:edutask/shared/models/tugas.dart';
import 'package:edutask/shared/repositories/tugas_repository.dart';

Tugas buildTugas({
  String id = 't1',
  String judul = 'Tugas',
  String? kelasNama = 'X PPLG 1',
  String? mapelNama = 'Pemrograman',
  String? guruNama = 'Bu Ani',
  String kelasId = 'k1',
  String guruId = 'g1',
  String mapelId = 'm1',
  DateTime? tenggat,
}) {
  return Tugas(
    id: id,
    judul: judul,
    deskripsi: '',
    guruId: guruId,
    guruNama: guruNama,
    kelasId: kelasId,
    kelasNama: kelasNama,
    mataPelajaranId: mapelId,
    mataPelajaranNama: mapelNama,
    tanggalMulai: DateTime(2026, 1, 1),
    tenggatWaktu: tenggat ?? DateTime(2026, 1, 8, 10),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TugasReportRow row({
  String id = 't1',
  DateTime? tenggat,
  int total = 10,
  int selesai = 4,
  int terlambat = 1,
  String judul = 'Tugas',
}) {
  return TugasReportRow(
    tugas: buildTugas(id: id, judul: judul, tenggat: tenggat),
    totalSiswa: total,
    selesai: selesai,
    terlambat: terlambat,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ReportDocument', () {
    test('memakai header kolom yang sama untuk CSV dan PDF', () {
      expect(ReportDocument.headers.length, 10);
      expect(ReportDocument.headers.first, 'Judul Tugas');
      expect(ReportDocument.headers.last, 'Persentase Selesai');
    });

    test('baris tabel CSV dan PDF berasal dari sel yang sama', () {
      final doc = ReportDocument.from(
        source: [row(judul: 'Struktur Data')],
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27, 9, 30),
      );
      final table = doc.toTableRows();
      expect(table.first, ReportDocument.headers);
      expect(table.length, 2);
      expect(table[1][0], 'Struktur Data');
      expect(table[1][1], 'X PPLG 1');
      expect(table[1][2], 'Pemrograman');
      expect(table[1][3], 'Bu Ani');
      expect(table[1][5], 10);
      expect(table[1][6], 4);
      expect(table[1][7], 6);
      expect(table[1][8], 1);
      expect(table[1][9], '40.0%');
    });

    test('nilai relasi kosong menjadi tanda hubung, bukan null', () {
      final doc = ReportDocument.from(
        source: [
          TugasReportRow(
            tugas: buildTugas(kelasNama: null, mapelNama: null, guruNama: null),
            totalSiswa: 0,
            selesai: 0,
            terlambat: 0,
          ),
        ],
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27),
      );
      final cells = doc.toTableRows()[1];
      expect(cells[1], '-');
      expect(cells[2], '-');
      expect(cells[3], '-');
      expect(cells[9], '0.0%');
    });

    test('urutan baris deterministik: tenggat lalu id (bukan pin)', () {
      final doc = ReportDocument.from(
        source: [
          row(id: 'c', judul: 'C', tenggat: DateTime(2026, 3, 1)),
          row(id: 'b', judul: 'B', tenggat: DateTime(2026, 1, 1)),
          row(id: 'a', judul: 'A', tenggat: DateTime(2026, 1, 1)),
        ],
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27),
      );
      expect(doc.rows.length, 3);
      // Tenggat sama (1 Jan) → id 'a' sebelum 'b'; 'c' paling akhir.
      expect(doc.rows.map((r) => r.judul).toList(), ['A', 'B', 'C']);
    });

    test('ringkasan statistik dijumlahkan dari seluruh baris', () {
      final doc = ReportDocument.from(
        source: [
          row(id: 'a', total: 10, selesai: 5, terlambat: 1),
          row(id: 'b', total: 30, selesai: 25, terlambat: 2),
        ],
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27),
      );
      expect(doc.totalTugas, 2);
      expect(doc.totalSiswa, 40);
      expect(doc.totalSelesai, 30);
      expect(doc.totalTerlambat, 3);
      expect(doc.overallPercent, closeTo(75.0, 0.001));
    });

    test('laporan kosong tidak membagi nol', () {
      final doc = ReportDocument.from(
        source: const [],
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27),
      );
      expect(doc.rows, isEmpty);
      expect(doc.totalTugas, 0);
      expect(doc.totalSiswa, 0);
      expect(doc.overallPercent, 0);
      expect(doc.truncated, isFalse);
      expect(doc.toTableRows().length, 1);
    });

    test('jumlah baris dibatasi agar dokumen tetap wajar', () {
      final source = [
        for (var i = 0; i < ReportDocument.maxRows + 20; i++)
          row(id: 't$i', tenggat: DateTime(2026, 1, 1).add(Duration(hours: i))),
      ];
      final doc = ReportDocument.from(
        source: source,
        filter: ReportFilter.empty,
        generatedAt: DateTime(2026, 10, 27),
      );
      expect(doc.rows.length, ReportDocument.maxRows);
      expect(doc.truncated, isTrue);
      expect(doc.toTableRows().length, ReportDocument.maxRows + 1);
    });

    test('nama berkas aman dipakai .csv dan .pdf', () {
      final doc = ReportDocument.from(
        source: [row()],
        filter: const ReportFilter(kelasNama: 'X PPLG 1'),
        generatedAt: DateTime(2026, 10, 27, 9, 5),
      );
      // Stempel waktu memakai zona Asia/Jakarta, jadi isi jam tidak diuji di
      // sini (host CI berzona UTC); yang diuji bentuk & keamanan namanya.
      expect(doc.fileNameStem.startsWith('laporan-tugas-x-pplg-1-'), isTrue);
      expect(RegExp(r'-\d{8}-\d{4}$').hasMatch(doc.fileNameStem), isTrue);
      expect(doc.fileNameStem.contains(' '), isFalse);
      expect('${doc.fileNameStem}.csv', endsWith('.csv'));
      expect('${doc.fileNameStem}.pdf', endsWith('.pdf'));
    });
  });

  group('ReportFilter', () {
    test('label cakupan dan periode', () {
      const filter = ReportFilter(
        kelasId: 'k1',
        kelasNama: 'X PPLG 1',
        mapelNama: 'Pemrograman',
        guruNama: 'Bu Ani',
      );
      expect(filter.scopeLabel, contains('Kelas X PPLG 1'));
      expect(filter.scopeLabel, contains('Pemrograman'));
      expect(ReportFilter.empty.scopeLabel, 'Semua kelas');
      expect(ReportFilter.empty.periodLabel, 'Semua periode');
      expect(filter.hasAnyFilter, isTrue);
    });

    test('kesamaan dipakai sebagai kunci family provider', () {
      final a = ReportFilter(kelasId: 'k1', from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 31));
      final b = ReportFilter(kelasId: 'k1', from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 31));
      final c = ReportFilter(kelasId: 'k2', from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 31));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('copyWith bisa menghapus kelas dan periode', () {
      final filter = ReportFilter(
        kelasId: 'k1',
        kelasNama: 'X',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(filter.copyWith(clearKelas: true).kelasId, isNull);
      expect(filter.copyWith(clearPeriod: true).hasPeriod, isFalse);
    });
  });

  group('Konsistensi CSV ↔ PDF', () {
    test('CSV memakai baris tabel yang sama dengan PDF', () {
      final doc = ReportDocument.from(
        source: [
          row(id: 'a', judul: 'Struktur Data', total: 30, selesai: 20, terlambat: 1),
          row(id: 'b', judul: 'Basis Data', total: 30, selesai: 15, terlambat: 2),
        ],
        filter: const ReportFilter(kelasNama: 'X PPLG 1'),
        generatedAt: DateTime(2026, 10, 27, 9, 30),
      );

      final table = doc.toTableRows();
      final csv = CsvBuilder.build(table);
      final csvRows = csv
          .split('\r\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // Jumlah baris dan header harus identik antara CSV dan PDF.
      expect(csvRows.length, table.length);
      expect(csvRows.first, ReportDocument.headers.join(','));
      // Setiap baris data memuat seluruh nilai sel (yang mengandung koma
      // dikutip oleh CsvBuilder, jadi tidak dipecah dengan split(',')).
      for (final cells in table.skip(1)) {
        for (final cell in cells) {
          expect(csv, contains(CsvBuilder.escape(cell)),
              reason: 'sel "$cell" harus muncul di CSV');
        }
      }
      // Nilai statistik yang dipakai ringkasan PDF berasal dari baris yang sama.
      expect(csv, contains('Struktur Data'));
      expect(csv, contains('66.7%')); // 20 dari 30 siswa
      expect(csv, contains('50.0%')); // 15 dari 30 siswa
      expect(csv, contains('"')); // tanggal "08 Jan 2026, 10:00" dikutip
    });

    test('nama berkas CSV dan PDF memakai periode yang dipilih apa adanya', () {
      final filter = ReportFilter(
        kelasNama: 'X PPLG 1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      final doc = ReportDocument.from(
        source: [row()],
        filter: filter,
        generatedAt: DateTime(2026, 10, 27, 9, 5),
      );
      // Tanggal periode tidak boleh bergeser karena konversi zona waktu.
      expect(doc.fileNameStem, contains('20260101'));
      expect(doc.fileNameStem, contains('20260131'));
    });
  });

  group('Label periode', () {
    test('memakai tanggal kalender apa adanya (tanpa geser zona waktu)', () {
      final filter = ReportFilter(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      final fmt = DateFormat('d MMM yyyy', 'id_ID');
      expect(
        filter.periodLabel,
        '${fmt.format(DateTime(2026, 1, 1))} – ${fmt.format(DateTime(2026, 1, 31))}',
      );
      expect(filter.periodLabel.startsWith('1 '), isTrue);
      expect(filter.periodLabel, contains('31 '));
    });
  });

  group('ReportTaskFilter', () {
    test('menyaring kelas, guru, mapel, dan rentang tenggat', () {
      final tugas = buildTugas(tenggat: DateTime(2026, 5, 10, 8));
      expect(
        ReportTaskFilter.matches(tugas, const ReportFilter(kelasId: 'k1')),
        isTrue,
      );
      expect(
        ReportTaskFilter.matches(tugas, const ReportFilter(kelasId: 'lain')),
        isFalse,
      );
      expect(
        ReportTaskFilter.matches(
          tugas,
          ReportFilter(from: DateTime(2026, 5, 1), to: DateTime(2026, 5, 31)),
        ),
        isTrue,
      );
      expect(
        ReportTaskFilter.matches(
          tugas,
          ReportFilter(from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)),
        ),
        isFalse,
      );
    });

    test('batas tanggal inklusif sampai akhir hari', () {
      final tugas = buildTugas(tenggat: DateTime(2026, 5, 31, 23, 30));
      expect(
        ReportTaskFilter.matches(
          tugas,
          ReportFilter(from: DateTime(2026, 5, 1), to: DateTime(2026, 5, 31)),
        ),
        isTrue,
      );
    });
  });
}
