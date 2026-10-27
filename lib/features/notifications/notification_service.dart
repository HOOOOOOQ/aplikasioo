import '../../core/utils/date_utils.dart';
import '../../shared/models/tugas.dart';
import 'notification_backend_stub.dart'
    if (dart.library.io) 'notification_backend_native.dart';

/// Notifikasi lokal EduTask (pengingat tenggat tugas).
///
/// Pada Web, pengingat lokal **tidak** dijadwalkan karena browser tidak
/// memiliki penjadwal notifikasi lokal yang setara. Pusat notifikasi in-app
/// (tabel `notifikasi`) tetap berfungsi di semua platform.
///
/// Semua kegagalan plugin ditelan dengan log debug saja: notifikasi adalah
/// fitur pelengkap dan tidak boleh menggagalkan alur utama.
class NotificationService {
  NotificationService._();

  static final NotificationBackend _backend = const NotificationBackend();
  static bool _permissionAsked = false;
  static bool _permissionGranted = false;

  /// Apakah pengingat lokal didukung pada platform ini.
  static bool get isSupported => _backend.supported;

  static Future<void> init() async {
    if (!isSupported) return;
    await _backend.init();
  }

  /// Minta izin sekali per proses. Mengembalikan true bila diizinkan.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (_permissionAsked) return _permissionGranted;
    _permissionAsked = true;
    _permissionGranted = await _backend.requestPermission();
    return _permissionGranted;
  }

  /// Jadwalkan pengingat 24 jam dan 1 jam sebelum tenggat untuk tugas yang
  /// belum selesai. Tugas yang sudah selesai akan dibatalkan pengingatnya.
  static Future<int> scheduleUpcoming(
    List<Tugas> tugasList, {
    bool enabled = true,
  }) async {
    if (!isSupported) return 0;
    await init();
    if (!enabled) {
      await _backend.cancelAll();
      return 0;
    }
    await requestPermission();

    var scheduled = 0;
    for (final tugas in tugasList.take(25)) {
      if (tugas.isCompleted) {
        await cancelForTugas(tugas.id);
        continue;
      }
      scheduled += await scheduleForTugas(tugas);
    }
    return scheduled;
  }

  static int _baseId(String tugasId) => tugasId.hashCode & 0x7FFFFFFF;

  /// Menjadwalkan dua pengingat (24 jam & 1 jam sebelum tenggat).
  /// Mengembalikan jumlah pengingat yang benar-benar terjadwal.
  static Future<int> scheduleForTugas(Tugas tugas) async {
    if (!isSupported) return 0;
    await init();
    final now = AppDateUtils.nowJakarta();
    final deadline = tugas.tenggatWaktu;
    if (deadline.isBefore(now)) return 0;

    var count = 0;
    final remind24 = deadline.subtract(const Duration(hours: 24));
    if (remind24.isAfter(now)) {
      final id = await _backend.scheduleDeadline(
        id: _baseId(tugas.id),
        title: 'Tenggat tugas mendekat',
        body: '${tugas.judul} — kurang dari 24 jam.',
        when: remind24,
      );
      if (id != 0) count++;
    }

    final remind1 = deadline.subtract(const Duration(hours: 1));
    if (remind1.isAfter(now)) {
      final id = await _backend.scheduleDeadline(
        id: _baseId(tugas.id) + 1,
        title: 'Tugas segera berakhir',
        body: '${tugas.judul} — tenggat ${AppDateUtils.formatTanggalJam(deadline)}.',
        when: remind1,
      );
      if (id != 0) count++;
    }
    return count;
  }

  static Future<void> cancelForTugas(String tugasId) async {
    if (!isSupported) return;
    await _backend.cancel(_baseId(tugasId));
    await _backend.cancel(_baseId(tugasId) + 1);
  }

  static Future<void> cancelAll() async {
    if (!isSupported) return;
    await _backend.cancelAll();
  }

  /// Keterangan singkat untuk ditampilkan di UI.
  static String get availabilityNote => isSupported
      ? 'Pengingat dijadwalkan di perangkat ini (24 jam & 1 jam sebelum tenggat).'
      : 'Pengingat lokal hanya tersedia di aplikasi Android. Di Web, gunakan pusat '
          'notifikasi in-app.';
}
