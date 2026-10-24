import 'package:equatable/equatable.dart';

class Kelas extends Equatable {
  final String id;
  final String namaKelas;
  final String? tingkat;
  final String? tahunAjaran;
  final String? waliKelasId;
  final String? waliKelasNama;
  final int jumlahSiswa;
  final DateTime createdAt;

  const Kelas({
    required this.id,
    required this.namaKelas,
    this.tingkat,
    this.tahunAjaran,
    this.waliKelasId,
    this.waliKelasNama,
    this.jumlahSiswa = 0,
    required this.createdAt,
  });

  factory Kelas.fromJson(Map<String, dynamic> json) {
    return Kelas(
      id: json['id'] as String,
      namaKelas: json['nama_kelas'] as String,
      tingkat: json['tingkat'] as String?,
      tahunAjaran: json['tahun_ajaran'] as String?,
      waliKelasId: json['wali_kelas_id'] as String?,
      waliKelasNama: json['wali_kelas_nama'] as String? ?? (json['profiles'] != null ? (json['profiles'] as Map)['full_name'] as String? : null),
      jumlahSiswa: json['jumlah_siswa'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'nama_kelas': namaKelas,
        'tingkat': tingkat,
        'tahun_ajaran': tahunAjaran,
        'wali_kelas_id': waliKelasId,
      };

  Kelas copyWith({String? namaKelas, String? tingkat, String? tahunAjaran, String? waliKelasId}) {
    return Kelas(
      id: id,
      namaKelas: namaKelas ?? this.namaKelas,
      tingkat: tingkat ?? this.tingkat,
      tahunAjaran: tahunAjaran ?? this.tahunAjaran,
      waliKelasId: waliKelasId ?? this.waliKelasId,
      waliKelasNama: waliKelasNama,
      jumlahSiswa: jumlahSiswa,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, namaKelas, tingkat, tahunAjaran, waliKelasId];
}
