import 'package:equatable/equatable.dart';

class StatusTugasSiswa extends Equatable {
  final String id;
  final String tugasId;
  final String siswaId;
  final String status; // selesai, belum_selesai
  final DateTime? selesaiPada;
  final DateTime updatedAt;
  final String? siswaNama;
  final String? tugasJudul;

  const StatusTugasSiswa({
    required this.id,
    required this.tugasId,
    required this.siswaId,
    required this.status,
    this.selesaiPada,
    required this.updatedAt,
    this.siswaNama,
    this.tugasJudul,
  });

  factory StatusTugasSiswa.fromJson(Map<String, dynamic> json) {
    String? siswaNama;
    if (json['siswa'] != null && json['siswa'] is Map) siswaNama = (json['siswa'] as Map)['nama'] as String?;
    String? tugasJudul;
    if (json['tugas'] != null && json['tugas'] is Map) tugasJudul = (json['tugas'] as Map)['judul'] as String?;
    return StatusTugasSiswa(
      id: json['id'] as String,
      tugasId: json['tugas_id'] as String,
      siswaId: json['siswa_id'] as String,
      status: json['status'] as String,
      selesaiPada: json['selesai_pada'] != null ? DateTime.parse(json['selesai_pada'] as String) : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      siswaNama: siswaNama,
      tugasJudul: tugasJudul,
    );
  }

  Map<String, dynamic> toJson() => {
        'tugas_id': tugasId,
        'siswa_id': siswaId,
        'status': status,
        'selesai_pada': selesaiPada?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, tugasId, siswaId, status];
}
