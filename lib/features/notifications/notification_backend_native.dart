import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Implementasi Android/iOS untuk notifikasi lokal pengingat tenggat.
class NotificationBackend {
  const NotificationBackend();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  bool get supported => true;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      debugPrint('timezone init gagal: $e');
    }
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
      );
    } catch (e) {
      debugPrint('NotificationBackend.init gagal: $e');
    } finally {
      // Tandai tetap true agar tidak ada retry tanpa batas di setiap panggilan.
      _initialized = true;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? true;
      }
    } catch (e) {
      debugPrint('requestPermission gagal: $e');
    }
    return false;
  }

  Future<int> scheduleDeadline({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await init();
    tz.Location location;
    try {
      location = tz.getLocation('Asia/Jakarta');
    } catch (_) {
      // Fallback berlapis: `tz.local` dapat melempar bila basis data zona waktu
      // gagal dimuat, jadi terakhir pakai UTC agar penjadwalan tetap berjalan.
      try {
        location = tz.local;
      } catch (_) {
        location = tz.UTC;
      }
    }
    final tzWhen = tz.TZDateTime.from(when, location);

    const androidDetails = AndroidNotificationDetails(
      'edutask_deadline',
      'Pengingat Tenggat',
      channelDescription: 'Pengingat tenggat tugas EduTask',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzWhen,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return id;
      } catch (e) {
        // Android 14+ dapat menolak exact alarm; coba mode inexact.
        debugPrint('zonedSchedule gagal ($mode): $e');
      }
    }
    return 0;
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('cancel notifikasi gagal: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll notifikasi gagal: $e');
    }
  }
}
