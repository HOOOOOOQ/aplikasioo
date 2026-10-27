/// Tipe hasil ekspor PDF yang dipakai bersama lapisan native dan web.
enum PdfExportStatus {
  /// Berkas PDF berhasil diunduh lewat browser.
  downloaded,

  /// Dialog pratinjau/cetak sistem berhasil menyimpan atau mencetak.
  printed,

  /// Berkas dibagikan lewat lembar berbagi sistem.
  shared,

  /// Pengguna menutup dialog tanpa menyimpan/mencetak.
  cancelled,

  /// Gagal membuat atau mengirim berkas.
  failed,
}

/// Hasil satu percobaan ekspor PDF, termasuk pesan yang aman ditampilkan.
class PdfExportResult {
  final PdfExportStatus status;
  final String? message;

  const PdfExportResult(this.status, [this.message]);

  const PdfExportResult.downloaded() : this(PdfExportStatus.downloaded);
  const PdfExportResult.printed() : this(PdfExportStatus.printed);
  const PdfExportResult.shared() : this(PdfExportStatus.shared);
  const PdfExportResult.cancelled() : this(PdfExportStatus.cancelled);
  const PdfExportResult.failed(String reason) : this(PdfExportStatus.failed, reason);

  bool get isFailure => status == PdfExportStatus.failed;
  bool get isCancelled => status == PdfExportStatus.cancelled;
  bool get isSuccess => !isFailure && !isCancelled;

  String get successMessage {
    switch (status) {
      case PdfExportStatus.downloaded:
        return 'PDF diunduh. Buka berkasnya untuk mencetak (Ctrl/Cmd+P).';
      case PdfExportStatus.printed:
        return 'PDF siap disimpan atau dicetak.';
      case PdfExportStatus.shared:
        return 'PDF dibagikan.';
      case PdfExportStatus.cancelled:
        return 'Ekspor PDF dibatalkan.';
      case PdfExportStatus.failed:
        return message ?? 'Gagal membuat PDF.';
    }
  }
}
