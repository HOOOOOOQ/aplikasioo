import 'tugas.dart';

/// Aturan urutan daftar tugas yang deterministik.
///
/// Urutan yang dipakai (dan diuji):
/// 1. tugas **di-pin** selalu di atas tugas biasa;
/// 2. di antara yang di-pin: `position` menaik;
/// 3. tie-breaker: tenggat lebih awal, lalu `id` (ascending) agar hasil sama
///    di setiap perangkat dan pada setiap pemuatan ulang;
/// 4. tugas biasa memakai urutan lama aplikasi (tenggat menaik), dengan
///    tie-breaker `id` yang juga deterministik.
///
/// Tugas yang belum punya kolom pin (data lama / migration belum dijalankan)
/// otomatis bernilai `isPinned = false, position = 0`, sehingga urutannya sama
/// dengan sebelum fitur pin ada.
class TugasSorting {
  TugasSorting._();

  /// Bandingkan dua tugas sesuai aturan di atas.
  static int compare(Tugas a, Tugas b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

    if (a.isPinned && b.isPinned && a.position != b.position) {
      return a.position.compareTo(b.position);
    }

    final byDeadline = a.tenggatWaktu.compareTo(b.tenggatWaktu);
    if (byDeadline != 0) return byDeadline;

    final byCreated = a.createdAt.compareTo(b.createdAt);
    if (byCreated != 0) return byCreated;

    return a.id.compareTo(b.id);
  }

  /// Salinan daftar yang sudah diurutkan (tidak mengubah daftar masukan).
  static List<Tugas> sortForDisplay(Iterable<Tugas> tugas) {
    final list = tugas.toList();
    list.sort(compare);
    return list;
  }

  /// Jumlah tugas yang di-pin (dipakai untuk label ringkas di UI).
  static int pinnedCount(Iterable<Tugas> tugas) => tugas.where((t) => t.isPinned).length;
}
