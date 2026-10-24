import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../core/utils/date_utils.dart';
import '../../shared/models/tugas.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> scheduleForTugas(Tugas tugas) async {
    await init();
    final deadline = tugas.tenggatWaktu;
    final now = AppDateUtils.nowJakarta();
    if (deadline.isBefore(now)) return;

    // schedule 24h before
    final remindTime = deadline.subtract(const Duration(hours: 24));
    if (remindTime.isAfter(now)) {
      await _schedule(
        id: tugas.id.hashCode & 0x7FFFFFFF,
        title: 'Tenggat Tugas Mendekat',
        body: '${tugas.judul} tenggat dalam 24 jam (${tugas.mataPelajaranNama ?? ""})',
        scheduledDate: remindTime,
      );
    }

    // schedule 1h before
    final remind1h = deadline.subtract(const Duration(hours: 1));
    if (remind1h.isAfter(now)) {
      await _schedule(
        id: (tugas.id.hashCode & 0x7FFFFFFF) + 1,
        title: 'Tugas Segera Berakhir',
        body: '${tugas.judul} tenggat ${AppDateUtils.formatTanggalJam(deadline)}',
        scheduledDate: remind1h,
      );
    }
  }

  static Future<void> _schedule({required int id, required String title, required String body, required DateTime scheduledDate}) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.getLocation('Asia/Jakarta'));
    const androidDetails = AndroidNotificationDetails(
      'edutask_deadline',
      'Pengingat Tenggat',
      channelDescription: 'Pengingat tenggat tugas EduTask',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.zonedSchedule(id, title, body, tzDate, details, androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    } catch (e) {
      debugPrint('Schedule failed: $e');
    }
  }

  static Future<void> cancelForTugas(String tugasId) async {
    await _plugin.cancel(tugasId.hashCode & 0x7FFFFFFF);
    await _plugin.cancel((tugasId.hashCode & 0x7FFFFFFF) + 1);
  }

  /// Untuk notifikasi lokal saat aplikasi dibuka: cek overdue
  static Future<void> showImmediateIfNeeded(Tugas tugas) async {
    await init();
    // Tidak auto-show, hanya contoh
  }
}
