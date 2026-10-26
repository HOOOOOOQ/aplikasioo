import 'package:edutask/features/akademik/domain/akademik_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pengumuman.fromJson', () {
    test('membaca kolom wajib dan join penulis', () {
      final item = Pengumuman.fromJson({
        'id': 'p1',
        'judul': 'Ujian Tengah Semester',
        'isi': 'Ujian dimulai Senin.',
        'target': 'siswa',
        'kelas_id': null,
        'is_published': true,
        'publish_at': '2026-03-01T08:00:00Z',
        'profiles': {'full_name': 'Bu Ani'},
      });

      expect(item.judul, 'Ujian Tengah Semester');
      expect(item.target, 'siswa');
      expect(item.isPublished, isTrue);
      expect(item.penulisNama, 'Bu Ani');
      expect(item.publishAt.year, 2026);
    });

    test('tidak melempar saat field hilang atau bertipe aneh', () {
      final item = Pengumuman.fromJson({'id': 123, 'judul': null, 'publish_at': 'bukan-tanggal'});
      expect(item.id, '123');
      expect(item.judul, 'Pengumuman');
      expect(item.target, 'semua');
    });
  });

  group('KalenderItem.fromJson', () {
    test('mendeteksi rentang tanggal', () {
      final item = KalenderItem.fromJson({
        'id': 'k1',
        'judul': 'Libur Semester',
        'tipe': 'libur',
        'tanggal_mulai': '2026-06-20',
        'tanggal_selesai': '2026-07-05',
      });
      expect(item.tipe, 'libur');
      expect(item.isRange, isTrue);
      expect(kalenderTipeLabel(item.tipe), 'Libur');
    });

    test('tanggal selesai kosong berarti satu hari', () {
      final item = KalenderItem.fromJson({
        'id': 'k2',
        'judul': 'Rapat',
        'tipe': 'rapat',
        'tanggal_mulai': '2026-06-20',
      });
      expect(item.isRange, isFalse);
    });
  });

  group('ChatMessage', () {
    test('membedakan pesan milik sendiri (guru dan siswa)', () {
      final guru = ChatMessage.fromJson({
        'id': 'm1',
        'thread_id': 't1',
        'sender_profile_id': 'profile-1',
        'sender_nama': 'Pak Budi',
        'body': 'Halo',
        'created_at': '2026-03-01T08:00:00Z',
      });
      expect(guru.isMine(profileId: 'profile-1'), isTrue);
      expect(guru.isMine(profileId: 'profile-2'), isFalse);

      final siswa = ChatMessage.fromJson({
        'id': 'm2',
        'thread_id': 't1',
        'sender_siswa_id': 'siswa-1',
        'sender_nama': 'Siti',
        'body': 'Baik pak',
      });
      expect(siswa.isMine(siswaId: 'siswa-1'), isTrue);
      expect(siswa.isMine(profileId: 'profile-1'), isFalse);
    });
  });

  group('Pengumpulan', () {
    test('nilai dan revisi dibaca dengan aman', () {
      final item = Pengumpulan.fromJson({
        'id': 's1',
        'tugas_id': 't1',
        'revisi_ke': 2,
        'status': 'dinilai',
        'nilai': '88.5',
        'umpan_balik': 'Bagus, rapikan penutup.',
        'submitted_at': '2026-03-02T10:00:00Z',
      });
      expect(item.revisiKe, 2);
      expect(item.nilai, 88.5);
      expect(item.sudahDinilai, isTrue);
      expect(item.umpanBalik, contains('rapikan'));
    });

    test('status terkirim tanpa nilai bukan "sudah dinilai"', () {
      final item = Pengumpulan.fromJson({'id': 's2', 'tugas_id': 't1', 'status': 'terkirim'});
      expect(item.sudahDinilai, isFalse);
      expect(item.revisiKe, 1);
    });
  });

  group('AkademikStats', () {
    test('membaca jsonb dari RPC dan memberi default 0', () {
      final stats = AkademikStats.fromJson({
        'pengumpulan': 12,
        'menunggu_nilai': 3,
        'rata_nilai': 81.4,
      });
      expect(stats.pengumpulan, 12);
      expect(stats.menungguNilai, 3);
      expect(stats.rataNilai, 81.4);
      expect(stats.tugasTerbit, 0);
    });
  });

  group('SearchHit', () {
    test('membaca hasil pencarian global', () {
      final hit = SearchHit.fromJson({
        'tipe': 'tugas',
        'id': '1',
        'judul': 'Laporan Praktikum',
        'subjudul': 'Tenggat 10 Mar 2026',
        'route': '/guru/tugas/1',
      });
      expect(hit.tipe, 'tugas');
      expect(hit.route, '/guru/tugas/1');
    });
  });
}
