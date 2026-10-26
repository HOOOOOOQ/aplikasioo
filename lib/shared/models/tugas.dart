import 'package:equatable/equatable.dart';

class Tugas extends Equatable {
  final String id;
  final String judul;
  final String deskripsi;
  final String guruId;
  final String? guruNama;
  final String kelasId;
  final String? kelasNama;
  final String mataPelajaranId;
  final String? mataPelajaranNama;
  final DateTime tanggalMulai;
  final DateTime tenggatWaktu;
  final String? lampiranPath;
  final String statusPublikasi; // draft, published, archived
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed for student view
  final String? statusSiswa; // belum_selesai, selesai
  final DateTime? selesaiPada;

  const Tugas({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.guruId,
    this.guruNama,
    required this.kelasId,
    this.kelasNama,
    required this.mataPelajaranId,
    this.mataPelajaranNama,
    required this.tanggalMulai,
    required this.tenggatWaktu,
    this.lampiranPath,
    this.statusPublikasi = 'published',
    required this.createdAt,
    required this.updatedAt,
    this.statusSiswa,
    this.selesaiPada,
  });

  static DateTime _parseDt(dynamic v, {DateTime? fallback}) {
    if (v == null) return fallback ?? DateTime.now();
    try {
      if (v is DateTime) return v;
      return DateTime.parse(v as String);
    } catch (_) {
      return fallback ?? DateTime.now();
    }
  }

  factory Tugas.fromJson(Map<String, dynamic> json) {
    String? guruNama;
    if (json['guru'] != null && json['guru'] is Map) guruNama = (json['guru'] as Map)['full_name'] as String?;
    if (json['profiles'] != null && json['profiles'] is Map) guruNama = (json['profiles'] as Map)['full_name'] as String?;
    String? kelasNama;
    if (json['kelas'] != null && json['kelas'] is Map) kelasNama = (json['kelas'] as Map)['nama_kelas'] as String?;
    String? mapelNama;
    if (json['mata_pelajaran'] != null && json['mata_pelajaran'] is Map) mapelNama = (json['mata_pelajaran'] as Map)['nama_mapel'] as String?;

    // Join for status
    String? statusSiswa;
    DateTime? selesaiPada;
    try {
      if (json['status_tugas_siswa'] != null && json['status_tugas_siswa'] is List && (json['status_tugas_siswa'] as List).isNotEmpty) {
        final s = (json['status_tugas_siswa'] as List).first as Map<String, dynamic>;
        statusSiswa = s['status'] as String?;
        if (s['selesai_pada'] != null) selesaiPada = _parseDt(s['selesai_pada']);
      } else if (json['status'] != null) {
        statusSiswa = json['status'] as String?;
        if (json['selesai_pada'] != null) selesaiPada = _parseDt(json['selesai_pada']);
      }
    } catch (_) {}

    return Tugas(
      id: json['id'] as String? ?? '',
      judul: json['judul'] as String? ?? '-',
      deskripsi: json['deskripsi'] as String? ?? '',
      guruId: json['guru_id'] as String? ?? '',
      guruNama: guruNama,
      kelasId: json['kelas_id'] as String? ?? '',
      kelasNama: kelasNama,
      mataPelajaranId: json['mata_pelajaran_id'] as String? ?? '',
      mataPelajaranNama: mapelNama,
      tanggalMulai: _parseDt(json['tanggal_mulai']),
      tenggatWaktu: _parseDt(json['tenggat_waktu']),
      lampiranPath: json['lampiran_path'] as String?,
      statusPublikasi: json['status_publikasi'] as String? ?? 'published',
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
      statusSiswa: statusSiswa,
      selesaiPada: selesaiPada,
    );
  }

  Map<String, dynamic> toJson() => {
        'judul': judul,
        'deskripsi': deskripsi,
        'guru_id': guruId,
        'kelas_id': kelasId,
        'mata_pelajaran_id': mataPelajaranId,
        'tanggal_mulai': tanggalMulai.toIso8601String(),
        'tenggat_waktu': tenggatWaktu.toIso8601String(),
        'lampiran_path': lampiranPath,
        'status_publikasi': statusPublikasi,
      };

  bool get isCompleted => statusSiswa == 'selesai';

  bool get isPublished => statusPublikasi == 'published';
  bool get hasLampiran => lampiranPath != null && lampiranPath!.trim().isNotEmpty;

  Tugas copyWith({
    String? judul,
    String? deskripsi,
    String? kelasId,
    String? kelasNama,
    String? mataPelajaranId,
    String? mataPelajaranNama,
    DateTime? tanggalMulai,
    DateTime? tenggatWaktu,
    String? lampiranPath,
    String? statusPublikasi,
    String? statusSiswa,
    DateTime? selesaiPada,
  }) {
    return Tugas(
      id: id,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      guruId: guruId,
      guruNama: guruNama,
      kelasId: kelasId ?? this.kelasId,
      kelasNama: kelasNama ?? this.kelasNama,
      mataPelajaranId: mataPelajaranId ?? this.mataPelajaranId,
      mataPelajaranNama: mataPelajaranNama ?? this.mataPelajaranNama,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tenggatWaktu: tenggatWaktu ?? this.tenggatWaktu,
      lampiranPath: lampiranPath ?? this.lampiranPath,
      statusPublikasi: statusPublikasi ?? this.statusPublikasi,
      createdAt: createdAt,
      updatedAt: updatedAt,
      statusSiswa: statusSiswa ?? this.statusSiswa,
      selesaiPada: selesaiPada ?? this.selesaiPada,
    );
  }

  @override
  List<Object?> get props => [id, judul, tenggatWaktu, statusSiswa];
}
