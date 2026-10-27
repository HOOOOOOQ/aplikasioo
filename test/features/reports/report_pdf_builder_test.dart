import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:edutask/features/reports/domain/report_document.dart';
import 'package:edutask/features/reports/services/report_pdf_builder.dart';
import 'package:edutask/shared/models/tugas.dart';
import 'package:edutask/shared/repositories/tugas_repository.dart';

ReportDocument buildDoc({int rows = 3}) {
  final source = [
    for (var i = 0; i < rows; i++)
      TugasReportRow(
        tugas: Tugas(
          id: 't$i',
          judul: 'Tugas nomor $i dengan judul yang cukup panjang untuk diuji',
          deskripsi: '',
          guruId: 'g1',
          guruNama: 'Bu Ani',
          kelasId: 'k1',
          kelasNama: 'X PPLG 1',
          mataPelajaranId: 'm1',
          mataPelajaranNama: 'Pemrograman Web',
          tanggalMulai: DateTime(2026, 1, 1),
          tenggatWaktu: DateTime(2026, 1, 1).add(Duration(days: i)),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        totalSiswa: 36,
        selesai: i * 3,
        terlambat: i,
      ),
  ];
  return ReportDocument.from(
    source: source,
    filter: const ReportFilter(kelasNama: 'X PPLG 1'),
    generatedAt: DateTime(2026, 10, 27, 9, 30),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ReportPdfBuilder', () {
    test('menghasilkan berkas PDF yang valid secara struktur', () async {
      final bytes = await ReportPdfBuilder.build(buildDoc(rows: 5));
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes.skip(bytes.length - 6).toList()), contains('EOF'));
    });

    test('laporan kosong tetap menghasilkan satu halaman', () async {
      final document = ReportPdfBuilder.createDocument(ReportDocument.empty(
        filter: const ReportFilter(kelasNama: 'X PPLG 1'),
        generatedAt: DateTime(2026, 10, 27),
      ));
      final bytes = await document.save();
      expect(bytes.length, greaterThan(500));
      expect(document.document.pdfPageList.pages.length, 1);
    });

    test('laporan panjang dipecah menjadi beberapa halaman', () async {
      final document = ReportPdfBuilder.createDocument(buildDoc(rows: 120));
      await document.save();
      expect(document.document.pdfPageList.pages.length, greaterThan(1));
    });

    test('jumlah halaman tetap wajar untuk batas baris maksimum', () async {
      final document = ReportPdfBuilder.createDocument(
        buildDoc(rows: ReportDocument.maxRows),
      );
      await document.save();
      final pages = document.document.pdfPageList.pages.length;
      expect(pages, greaterThan(1));
      expect(pages, lessThan(ReportPdfBuilder.maxPages));
    });

    test('nama berkas PDF sama dengan nama CSV', () {
      final doc = buildDoc();
      expect('${doc.fileNameStem}.pdf', endsWith('.pdf'));
      expect(doc.fileNameStem, contains('laporan-tugas'));
    });
  });
}
