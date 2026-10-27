import '../../../core/utils/date_utils.dart';
import '../../../shared/models/tugas.dart';
import '../../../shared/repositories/tugas_repository.dart';

/// Filter laporan yang dipakai bersama oleh ekspor **CSV** dan **PDF**.
///
/// Satu objek filter dipakai untuk mengambil data (`fetchReport`) sekaligus
/// untuk menulis judul/berkas, sehingga isi kedua format tidak bisa berbeda.
class ReportFilter {
  final String? kelasId;
  final String? kelasNama;
  final String? guruId;
  final String? guruNama;
  final String? mapelId;
  final String? mapelNama;

  /// Rentang tanggal (inklusif) berdasarkan **tenggat** tugas.
  final DateTime? from;
  final DateTime? to;

  const ReportFilter({
    this.kelasId,
    this.kelasNama,
    this.guruId,
    this.guruNama,
    this.mapelId,
    this.mapelNama,
    this.from,
    this.to,
  });

  static const ReportFilter empty = ReportFilter();

  bool get hasPeriod => from != null || to != null;
  bool get hasAnyFilter =>
      kelasId != null || guruId != null || mapelId != null || hasPeriod;

  ReportFilter copyWith({
    String? kelasId,
    String? kelasNama,
    String? guruId,
    String? guruNama,
    String? mapelId,
    String? mapelNama,
    DateTime? from,
    DateTime? to,
    bool clearKelas = false,
    bool clearGuru = false,
    bool clearMapel = false,
    bool clearPeriod = false,
  }) {
    return ReportFilter(
      kelasId: clearKelas ? null : (kelasId ?? this.kelasId),
      kelasNama: clearKelas ? null : (kelasNama ?? this.kelasNama),
      guruId: clearGuru ? null : (guruId ?? this.guruId),
      guruNama: clearGuru ? null : (guruNama ?? this.guruNama),
      mapelId: clearMapel ? null : (mapelId ?? this.mapelId),
      mapelNama: clearMapel ? null : (mapelNama ?? this.mapelNama),
      from: clearPeriod ? null : (from ?? this.from),
      to: clearPeriod ? null : (to ?? this.to),
    );
  }

  /// Label ringkas untuk subjudul UI/PDF, mis. "Kelas X · Guru: Ani".
  String get scopeLabel {
    final parts = <String>[
      if (kelasNama != null && kelasNama!.trim().isNotEmpty) 'Kelas $kelasNama',
      if (mapelNama != null && mapelNama!.trim().isNotEmpty) 'Mapel $mapelNama',
      if (guruNama != null && guruNama!.trim().isNotEmpty) 'Guru: $guruNama',
    ];
    return parts.isEmpty ? 'Semua kelas' : parts.join(' • ');
  }

  /// Label periode, mis. "1 Sep 2026 – 30 Sep 2026".
  String get periodLabel {
    if (!hasPeriod) return 'Semua periode';
    final start = from == null ? 'awal' : AppDateUtils.formatTanggal(from, pattern: 'd MMM yyyy');
    final end = to == null ? 'sekarang' : AppDateUtils.formatTanggal(to, pattern: 'd MMM yyyy');
    return '$start – $end';
  }

  /// Kesamaan berdasarkan parameter kueri saja (nama label tidak berpengaruh
  /// ke data), supaya bisa dipakai sebagai kunci `family` provider.
  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.kelasId == kelasId &&
      other.guruId == guruId &&
      other.mapelId == mapelId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kelasId, guruId, mapelId, from, to);

  /// Bagian nama berkas yang aman (tanpa spasi/simbol).
  String get fileStem {
    final bits = <String>[
      'laporan-tugas',
      if (kelasNama != null && kelasNama!.trim().isNotEmpty) kelasNama!,
      if (mapelNama != null && mapelNama!.trim().isNotEmpty) mapelNama!,
      if (from != null) AppDateUtils.formatTanggal(from, pattern: 'yyyyMMdd'),
      if (to != null) AppDateUtils.formatTanggal(to, pattern: 'yyyyMMdd'),
    ];
    final safe = bits
        .join('-')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return safe.isEmpty ? 'laporan-tugas' : safe;
  }
}

/// Satu baris laporan yang sudah diformat (dipakai CSV & PDF).
class ReportRowData {
  final String judul;
  final String kelas;
  final String mapel;
  final String guru;
  final String tenggat;
  final int totalSiswa;
  final int selesai;
  final int belum;
  final int terlambat;
  final double persen;

  const ReportRowData({
    required this.judul,
    required this.kelas,
    required this.mapel,
    required this.guru,
    required this.tenggat,
    required this.totalSiswa,
    required this.selesai,
    required this.belum,
    required this.terlambat,
    required this.persen,
  });

  /// Sel CSV/PDF dengan urutan kolom yang sama persis.
  List<Object?> toCells() => [
        judul,
        kelas,
        mapel,
        guru,
        tenggat,
        totalSiswa,
        selesai,
        belum,
        terlambat,
        '${persen.toStringAsFixed(1)}%',
      ];
}

/// Dokumen laporan siap ekspor (satu sumber data untuk CSV dan PDF).
class ReportDocument {
  final String title;
  final ReportFilter filter;
  final DateTime generatedAt;
  final List<ReportRowData> rows;

  /// `true` bila jumlah baris dipotong karena melebihi [maxRows].
  final bool truncated;

  /// Batas aman jumlah baris agar dokumen tidak menghabiskan memori.
  static const int maxRows = 500;

  ReportDocument({
    required this.title,
    required this.filter,
    required this.generatedAt,
    required List<ReportRowData> rows,
    this.truncated = false,
  }) : rows = List.unmodifiable(rows);

  /// Judul kolom — dipakai CSV (header) dan PDF (header tabel).
  static const List<String> headers = [
    'Judul Tugas',
    'Kelas',
    'Mata Pelajaran',
    'Guru',
    'Tenggat',
    'Total Siswa',
    'Selesai',
    'Belum',
    'Terlambat',
    'Persentase Selesai',
  ];

  int get totalTugas => rows.length;
  int get totalSiswa => rows.fold<int>(0, (sum, row) => sum + row.totalSiswa);
  int get totalSelesai => rows.fold<int>(0, (sum, row) => sum + row.selesai);
  int get totalTerlambat => rows.fold<int>(0, (sum, row) => sum + row.terlambat);

  double get overallPercent =>
      totalSiswa == 0 ? 0 : (totalSelesai / totalSiswa) * 100;

  String get generatedAtLabel => AppDateUtils.formatTanggalJam(generatedAt);

  /// Nama berkas tanpa ekstensi (dipakai `.csv` dan `.pdf`).
  String get fileNameStem {
    final stamp = AppDateUtils.formatTanggal(
      generatedAt,
      pattern: 'yyyyMMdd-HHmm',
    );
    return '${filter.fileStem}-$stamp';
  }

  /// Tabel lengkap (header + baris) yang dipakai kedua format.
  List<List<Object?>> toTableRows() => [
        List<Object?>.from(headers),
        ...rows.map((row) => row.toCells()),
      ];

  /// Membentuk dokumen dari data repository.
  ///
  /// Urutan baris laporan **selalu** berdasarkan tenggat lalu `id` (bukan pin),
  /// agar isi laporan tidak berubah ketika admin mem-pin tugas di dashboard.
  factory ReportDocument.from({
    required List<TugasReportRow> source,
    required ReportFilter filter,
    required DateTime generatedAt,
    String title = 'Laporan Penyelesaian Tugas',
  }) {
    final sorted = source.toList()
      ..sort((a, b) {
        final byDeadline = a.tugas.tenggatWaktu.compareTo(b.tugas.tenggatWaktu);
        if (byDeadline != 0) return byDeadline;
        return a.tugas.id.compareTo(b.tugas.id);
      });

    final truncated = sorted.length > maxRows;
    final picked = truncated ? sorted.take(maxRows) : sorted;

    return ReportDocument(
      title: title,
      filter: filter,
      generatedAt: generatedAt,
      truncated: truncated,
      rows: picked
          .map((row) => ReportRowData(
                judul: row.tugas.judul,
                kelas: row.tugas.kelasNama ?? '-',
                mapel: row.tugas.mataPelajaranNama ?? '-',
                guru: row.tugas.guruNama ?? '-',
                tenggat: AppDateUtils.formatTanggalJam(row.tugas.tenggatWaktu),
                totalSiswa: row.totalSiswa,
                selesai: row.selesai,
                belum: row.belum,
                terlambat: row.terlambat,
                persen: row.persen,
              ))
          .toList(),
    );
  }

  /// Dokumen contoh untuk pengujian/empty-state (tanpa data).
  factory ReportDocument.empty({
    ReportFilter filter = ReportFilter.empty,
    DateTime? generatedAt,
  }) {
    return ReportDocument(
      title: 'Laporan Penyelesaian Tugas',
      filter: filter,
      generatedAt: generatedAt ?? DateTime.now(),
      rows: const <ReportRowData>[],
    );
  }
}

/// Penyaring tambahan di sisi klien untuk tugas yang sudah dimuat.
///
/// Dipakai ketika data laporan sudah ada di memori (mis. setelah filter kelas)
/// dan pengguna mengubah periode tanpa memuat ulang seluruh data.
class ReportTaskFilter {
  ReportTaskFilter._();

  static bool matches(Tugas tugas, ReportFilter filter) {
    if (filter.kelasId != null && tugas.kelasId != filter.kelasId) return false;
    if (filter.guruId != null && tugas.guruId != filter.guruId) return false;
    if (filter.mapelId != null && tugas.mataPelajaranId != filter.mapelId) {
      return false;
    }
    if (filter.from != null) {
      final start = DateTime(filter.from!.year, filter.from!.month, filter.from!.day);
      if (tugas.tenggatWaktu.isBefore(start)) return false;
    }
    if (filter.to != null) {
      final end = DateTime(filter.to!.year, filter.to!.month, filter.to!.day, 23, 59, 59, 999);
      if (tugas.tenggatWaktu.isAfter(end)) return false;
    }
    return true;
  }
}
