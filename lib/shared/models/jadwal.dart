import 'package:equatable/equatable.dart';

class Jadwal extends Equatable {
  final String id;
  final String kelasId;
  final String? kelasNama;
  final String guruId;
  final String? guruNama;
  final String mataPelajaranId;
  final String? mataPelajaranNama;
  final String hari;
  final String jamMulai; // HH:mm:ss
  final String jamSelesai;
  final String? ruang;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Jadwal({
    required this.id,
    required this.kelasId,
    this.kelasNama,
    required this.guruId,
    this.guruNama,
    required this.mataPelajaranId,
    this.mataPelajaranNama,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    this.ruang,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Jadwal.fromJson(Map<String, dynamic> json) {
    String? kelasNama;
    if (json['kelas'] != null && json['kelas'] is Map) kelasNama = (json['kelas'] as Map)['nama_kelas'] as String?;
    String? guruNama;
    if (json['guru'] != null && json['guru'] is Map) guruNama = (json['guru'] as Map)['full_name'] as String?;
    if (json['profiles'] != null && json['profiles'] is Map) guruNama = (json['profiles'] as Map)['full_name'] as String?;
    String? mapelNama;
    if (json['mata_pelajaran'] != null && json['mata_pelajaran'] is Map) mapelNama = (json['mata_pelajaran'] as Map)['nama_mapel'] as String?;

    return Jadwal(
      id: json['id'] as String,
      kelasId: json['kelas_id'] as String,
      kelasNama: kelasNama,
      guruId: json['guru_id'] as String,
      guruNama: guruNama,
      mataPelajaranId: json['mata_pelajaran_id'] as String,
      mataPelajaranNama: mapelNama,
      hari: json['hari'] as String,
      jamMulai: json['jam_mulai'] as String,
      jamSelesai: json['jam_selesai'] as String,
      ruang: json['ruang'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'kelas_id': kelasId,
        'guru_id': guruId,
        'mata_pelajaran_id': mataPelajaranId,
        'hari': hari,
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
        'ruang': ruang,
      };

  @override
  List<Object?> get props => [id, hari, jamMulai, jamSelesai];
}
