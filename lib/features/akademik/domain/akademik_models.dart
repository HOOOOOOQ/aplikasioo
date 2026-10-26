import 'package:equatable/equatable.dart';

/// Siapa yang sedang melihat modul akademik.
///
/// `siswa` memakai Edge Function bertoken (tanpa login), `staff` memakai
/// client Supabase dengan RLS (admin/guru yang sudah login).
enum AkademikAudience { siswa, staff }

DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _int(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

class Pengumuman extends Equatable {
  final String id;
  final String judul;
  final String isi;
  final String target; // semua | guru | siswa
  final String? kelasId;
  final bool isPublished;
  final DateTime publishAt;
  final String? penulisNama;

  const Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.target,
    this.kelasId,
    required this.isPublished,
    required this.publishAt,
    this.penulisNama,
  });

  bool get isExpired => false;

  factory Pengumuman.fromJson(Map<String, dynamic> json) {
    String? penulis;
    final profile = json['profiles'];
    if (profile is Map) penulis = profile['full_name'] as String?;
    return Pengumuman(
      id: _str(json['id']),
      judul: _str(json['judul'], 'Pengumuman'),
      isi: _str(json['isi']),
      target: _str(json['target'], 'semua'),
      kelasId: json['kelas_id'] as String?,
      isPublished: json['is_published'] as bool? ?? true,
      publishAt: _dt(json['publish_at']) ?? DateTime.now(),
      penulisNama: penulis,
    );
  }

  @override
  List<Object?> get props => [id, judul, isi, target, kelasId, isPublished, publishAt];
}

class KalenderItem extends Equatable {
  final String id;
  final String judul;
  final String? deskripsi;
  final String tipe; // libur | ujian | kegiatan | rapat | lainnya
  final DateTime tanggalMulai;
  final DateTime? tanggalSelesai;
  final String? kelasId;

  const KalenderItem({
    required this.id,
    required this.judul,
    this.deskripsi,
    required this.tipe,
    required this.tanggalMulai,
    this.tanggalSelesai,
    this.kelasId,
  });

  bool get isRange => tanggalSelesai != null && tanggalSelesai!.isAfter(tanggalMulai);

  factory KalenderItem.fromJson(Map<String, dynamic> json) => KalenderItem(
        id: _str(json['id']),
        judul: _str(json['judul'], 'Agenda'),
        deskripsi: json['deskripsi'] as String?,
        tipe: _str(json['tipe'], 'kegiatan'),
        tanggalMulai: _dt(json['tanggal_mulai']) ?? DateTime.now(),
        tanggalSelesai: _dt(json['tanggal_selesai']),
        kelasId: json['kelas_id'] as String?,
      );

  @override
  List<Object?> get props => [id, judul, tipe, tanggalMulai, tanggalSelesai];
}

class NotifikasiItem extends Equatable {
  final String id;
  final String tipe;
  final String judul;
  final String? isi;
  final String? refId;
  final bool isRead;
  final DateTime createdAt;

  const NotifikasiItem({
    required this.id,
    required this.tipe,
    required this.judul,
    this.isi,
    this.refId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotifikasiItem.fromJson(Map<String, dynamic> json) => NotifikasiItem(
        id: _str(json['id']),
        tipe: _str(json['tipe'], 'umum'),
        judul: _str(json['judul'], 'Notifikasi'),
        isi: json['isi'] as String?,
        refId: json['ref_id'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: _dt(json['created_at']) ?? DateTime.now(),
      );

  NotifikasiItem copyWith({bool? isRead}) => NotifikasiItem(
        id: id,
        tipe: tipe,
        judul: judul,
        isi: isi,
        refId: refId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, judul, isRead, createdAt];
}

class ChatThread extends Equatable {
  final String id;
  final String tipe; // direct | kelas | tugas
  final String judul;
  final String? kelasId;
  final DateTime? lastMessageAt;
  final int unread;

  const ChatThread({
    required this.id,
    required this.tipe,
    required this.judul,
    this.kelasId,
    this.lastMessageAt,
    this.unread = 0,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
        id: _str(json['id']),
        tipe: _str(json['tipe'], 'direct'),
        judul: _str(json['judul'], 'Percakapan'),
        kelasId: json['kelas_id'] as String?,
        lastMessageAt: _dt(json['last_message_at']),
        unread: _int(json['unread']),
      );

  ChatThread copyWith({String? judul, int? unread, DateTime? lastMessageAt}) => ChatThread(
        id: id,
        tipe: tipe,
        judul: judul ?? this.judul,
        kelasId: kelasId,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unread: unread ?? this.unread,
      );

  @override
  List<Object?> get props => [id, tipe, judul, unread, lastMessageAt];
}

class ChatMessage extends Equatable {
  final String id;
  final String threadId;
  final String? senderProfileId;
  final String? senderSiswaId;
  final String senderNama;
  final String body;
  final DateTime createdAt;
  final bool pending;

  const ChatMessage({
    required this.id,
    required this.threadId,
    this.senderProfileId,
    this.senderSiswaId,
    required this.senderNama,
    required this.body,
    required this.createdAt,
    this.pending = false,
  });

  /// Pesan milik pengguna saat ini.
  bool isMine({String? profileId, String? siswaId}) {
    if (profileId != null && senderProfileId == profileId) return true;
    if (siswaId != null && senderSiswaId == siswaId) return true;
    return false;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _str(json['id']),
        threadId: _str(json['thread_id']),
        senderProfileId: json['sender_profile_id'] as String?,
        senderSiswaId: json['sender_siswa_id'] as String?,
        senderNama: _str(json['sender_nama'], 'Pengguna'),
        body: _str(json['body']),
        createdAt: _dt(json['created_at']) ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, body, createdAt, pending];
}

class Pengumpulan extends Equatable {
  final String id;
  final String tugasId;
  final int revisiKe;
  final String? jawabanTeks;
  final String? lampiranPath;
  final String status; // draft | terkirim | dinilai | revisi
  final double? nilai;
  final String? umpanBalik;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const Pengumpulan({
    required this.id,
    required this.tugasId,
    required this.revisiKe,
    this.jawabanTeks,
    this.lampiranPath,
    required this.status,
    this.nilai,
    this.umpanBalik,
    required this.submittedAt,
    this.reviewedAt,
  });

  bool get sudahDinilai => status == 'dinilai' && nilai != null;

  factory Pengumpulan.fromJson(Map<String, dynamic> json) => Pengumpulan(
        id: _str(json['id']),
        tugasId: _str(json['tugas_id']),
        revisiKe: _int(json['revisi_ke'], 1),
        jawabanTeks: json['jawaban_teks'] as String?,
        lampiranPath: json['lampiran_path'] as String?,
        status: _str(json['status'], 'terkirim'),
        nilai: _num(json['nilai']),
        umpanBalik: json['umpan_balik'] as String?,
        submittedAt: _dt(json['submitted_at']) ?? DateTime.now(),
        reviewedAt: _dt(json['reviewed_at']),
      );

  @override
  List<Object?> get props => [id, revisiKe, status, nilai, submittedAt];
}

class AkademikStats extends Equatable {
  final int tugasTerbit;
  final int pengumpulan;
  final int dinilai;
  final int menungguNilai;
  final double rataNilai;
  final int pengumumanTerbit;
  final int siswaAktif;
  final int guruAktif;

  const AkademikStats({
    this.tugasTerbit = 0,
    this.pengumpulan = 0,
    this.dinilai = 0,
    this.menungguNilai = 0,
    this.rataNilai = 0,
    this.pengumumanTerbit = 0,
    this.siswaAktif = 0,
    this.guruAktif = 0,
  });

  static const AkademikStats empty = AkademikStats();

  factory AkademikStats.fromJson(Map<String, dynamic> json) => AkademikStats(
        tugasTerbit: _int(json['tugas_terbit']),
        pengumpulan: _int(json['pengumpulan']),
        dinilai: _int(json['dinilai']),
        menungguNilai: _int(json['menunggu_nilai']),
        rataNilai: _num(json['rata_nilai']) ?? 0,
        pengumumanTerbit: _int(json['pengumuman_terbit']),
        siswaAktif: _int(json['siswa_aktif']),
        guruAktif: _int(json['guru_aktif']),
      );

  @override
  List<Object?> get props =>
      [tugasTerbit, pengumpulan, dinilai, menungguNilai, rataNilai, pengumumanTerbit, siswaAktif, guruAktif];
}

class SearchHit extends Equatable {
  final String tipe;
  final String id;
  final String judul;
  final String subjudul;
  final String route;

  const SearchHit({
    required this.tipe,
    required this.id,
    required this.judul,
    required this.subjudul,
    required this.route,
  });

  factory SearchHit.fromJson(Map<String, dynamic> json) => SearchHit(
        tipe: _str(json['tipe'], 'lainnya'),
        id: _str(json['id']),
        judul: _str(json['judul'], '-'),
        subjudul: _str(json['subjudul']),
        route: _str(json['route']),
      );

  @override
  List<Object?> get props => [tipe, id, judul, route];
}

/// Label & warna untuk tipe kalender (dipakai UI).
String kalenderTipeLabel(String tipe) => switch (tipe) {
      'libur' => 'Libur',
      'ujian' => 'Ujian',
      'kegiatan' => 'Kegiatan',
      'rapat' => 'Rapat',
      _ => 'Lainnya',
    };

String chatThreadTipeLabel(String tipe) => switch (tipe) {
      'kelas' => 'Grup Kelas',
      'tugas' => 'Diskusi Tugas',
      _ => 'Pesan Pribadi',
    };
