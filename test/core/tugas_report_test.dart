import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/shared/models/tugas.dart';
import 'package:edutask/shared/repositories/tugas_repository.dart';

Tugas buildTugas({String? statusSiswa}) => Tugas(
      id: 't1',
      judul: 'Tugas',
      deskripsi: 'Deskripsi',
      guruId: 'g1',
      kelasId: 'k1',
      mataPelajaranId: 'm1',
      tanggalMulai: DateTime(2026, 1, 1),
      tenggatWaktu: DateTime(2026, 1, 8),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      statusSiswa: statusSiswa,
    );

void main() {
  group('TugasReportRow', () {
    test('menghitung persentase penyelesaian', () {
      final row = TugasReportRow(tugas: buildTugas(), totalSiswa: 20, selesai: 5, terlambat: 1);
      expect(row.belum, 15);
      expect(row.persen, 25.0);
    });

    test('kelas tanpa siswa tidak membagi nol', () {
      final row = TugasReportRow(tugas: buildTugas(), totalSiswa: 0, selesai: 0, terlambat: 0);
      expect(row.persen, 0);
      expect(row.belum, 0);
    });

    test('tidak pernah negatif walau data tidak konsisten', () {
      final row = TugasReportRow(tugas: buildTugas(), totalSiswa: 3, selesai: 5, terlambat: 0);
      expect(row.belum, 0);
    });
  });

  group('Tugas flags', () {
    test('isPublished hanya untuk status published', () {
      final published = Tugas.fromJson({
        'id': 't2',
        'judul': 'A',
        'guru_id': 'g',
        'kelas_id': 'k',
        'mata_pelajaran_id': 'm',
        'tanggal_mulai': '2026-01-01T00:00:00Z',
        'tenggat_waktu': '2026-01-08T00:00:00Z',
        'status_publikasi': 'published',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(published.isPublished, isTrue);
      expect(published.hasLampiran, isFalse);
    });

    test('draft tidak dianggap terbit', () {
      final draft = Tugas.fromJson({
        'id': 't3',
        'judul': 'B',
        'guru_id': 'g',
        'kelas_id': 'k',
        'mata_pelajaran_id': 'm',
        'tanggal_mulai': '2026-01-01T00:00:00Z',
        'tenggat_waktu': '2026-01-08T00:00:00Z',
        'status_publikasi': 'draft',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(draft.isPublished, isFalse);
    });

    test('hasLampiran true bila path tidak kosong', () {
      final tugas = Tugas.fromJson({
        'id': 't4',
        'judul': 'C',
        'guru_id': 'g',
        'kelas_id': 'k',
        'mata_pelajaran_id': 'm',
        'tanggal_mulai': '2026-01-01T00:00:00Z',
        'tenggat_waktu': '2026-01-08T00:00:00Z',
        'lampiran_path': 'tugas/g/t/x.pdf',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(tugas.hasLampiran, isTrue);
    });
  });
}
