import 'package:equatable/equatable.dart';

class Siswa extends Equatable {
  final String id;
  final String nomorInduk;
  final String nama;
  final String? kelasId;
  final String? kelasNama;
  final String? kodeAkses; // kode identitas untuk siswa tanpa login
  final bool statusAktif;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Siswa({
    required this.id,
    required this.nomorInduk,
    required this.nama,
    this.kelasId,
    this.kelasNama,
    this.kodeAkses,
    this.statusAktif = true,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDt(dynamic v) {
    if (v == null) return DateTime.now();
    try {
      if (v is DateTime) return v;
      return DateTime.parse(v as String);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory Siswa.fromJson(Map<String, dynamic> json) {
    String? kelasNama;
    if (json['kelas'] != null && json['kelas'] is Map) {
      kelasNama = (json['kelas'] as Map)['nama_kelas'] as String?;
    }
    return Siswa(
      id: json['id'] as String? ?? '',
      nomorInduk: json['nomor_induk'] as String? ?? '-',
      nama: json['nama'] as String? ?? '-',
      kelasId: json['kelas_id'] as String?,
      kelasNama: kelasNama,
      kodeAkses: json['kode_akses'] as String?,
      statusAktif: json['status_aktif'] as bool? ?? true,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'nomor_induk': nomorInduk,
        'nama': nama,
        'kelas_id': kelasId,
        'status_aktif': statusAktif,
      };

  Map<String, dynamic> toJsonWithCode() => {
        ...toJson(),
        if (kodeAkses != null) 'kode_akses': kodeAkses,
      };

  @override
  List<Object?> get props => [id, nomorInduk, nama, kelasId, statusAktif];
}
