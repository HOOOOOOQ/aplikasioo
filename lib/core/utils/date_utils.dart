import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Helper tanggal dengan zona waktu Asia/Jakarta.
class AppDateUtils {
  static bool _tzInitialized = false;

  static void initTimezone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  static tz.Location get jakarta => tz.getLocation('Asia/Jakarta');

  static DateTime nowJakarta() {
    try {
      initTimezone();
      return tz.TZDateTime.now(jakarta);
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime toJakarta(DateTime dt) {
    try {
      initTimezone();
      // Simpan di DB sebagai UTC; tampilkan sebagai Jakarta
      final utc = dt.isUtc ? dt : dt.toUtc();
      return tz.TZDateTime.from(utc, jakarta);
    } catch (_) {
      // Fallback kalau tz belum siap
      return dt.toLocal();
    }
  }

  static String formatTanggal(DateTime? dt, {String pattern = 'dd MMMM yyyy'}) {
    if (dt == null) return '-';
    final jkt = toJakarta(dt);
    return DateFormat(pattern, 'id_ID').format(jkt);
  }

  static String formatTanggalJam(DateTime? dt) {
    if (dt == null) return '-';
    final jkt = toJakarta(dt);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(jkt);
  }

  static String formatJam(DateTime? dt) {
    if (dt == null) return '-';
    final jkt = toJakarta(dt);
    return DateFormat('HH:mm', 'id_ID').format(jkt);
  }

  static String? tryFormatJamFromString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  static String formatJamFromString(String? timeStr) {
    return tryFormatJamFromString(timeStr) ?? '-';
  }

  static String relativeDeadline(DateTime? deadline) {
    if (deadline == null) return '-';
    final now = nowJakarta();
    final jktDeadline = toJakarta(deadline);
    final diff = jktDeadline.difference(now);
    if (diff.isNegative) {
      final overdue = now.difference(jktDeadline);
      if (overdue.inDays > 0) return 'Terlambat ${overdue.inDays} hari';
      if (overdue.inHours > 0) return 'Terlambat ${overdue.inHours} jam';
      return 'Terlambat ${overdue.inMinutes} menit';
    }
    if (diff.inDays > 0) return 'Sisa ${diff.inDays} hari';
    if (diff.inHours > 0) return 'Sisa ${diff.inHours} jam';
    if (diff.inMinutes > 0) return 'Sisa ${diff.inMinutes} menit';
    return 'Segera berakhir';
  }

  static String hariIndonesia(DateTime dt) {
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    // DateTime weekday 1=Mon ... 7=Sun
    return hari[dt.weekday - 1];
  }

  static String hariIndonesiaShort(DateTime dt) {
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return hari[dt.weekday - 1];
  }

  static List<String> get daftarHari => const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  static bool isToday(DateTime dt) {
    final now = nowJakarta();
    final jkt = toJakarta(dt);
    return now.year == jkt.year && now.month == jkt.month && now.day == jkt.day;
  }

  static bool isTomorrow(DateTime dt) {
    final now = nowJakarta();
    final tomorrow = now.add(const Duration(days: 1));
    final jkt = toJakarta(dt);
    return tomorrow.year == jkt.year && tomorrow.month == jkt.month && tomorrow.day == jkt.day;
  }

  static DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static DateTime endOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
}
