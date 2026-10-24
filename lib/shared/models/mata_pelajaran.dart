import 'package:equatable/equatable.dart';

class MataPelajaran extends Equatable {
  final String id;
  final String namaMapel;
  final String? deskripsi;
  final DateTime createdAt;

  const MataPelajaran({
    required this.id,
    required this.namaMapel,
    this.deskripsi,
    required this.createdAt,
  });

  factory MataPelajaran.fromJson(Map<String, dynamic> json) {
    return MataPelajaran(
      id: json['id'] as String,
      namaMapel: json['nama_mapel'] as String,
      deskripsi: json['deskripsi'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'nama_mapel': namaMapel,
        'deskripsi': deskripsi,
      };

  @override
  List<Object?> get props => [id, namaMapel];
}
