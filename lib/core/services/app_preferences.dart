import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan & suara yang tersimpan lokal di perangkat.
///
/// Semua nilai punya default yang aman; kegagalan penyimpanan tidak boleh
/// membuat aplikasi crash atau mengubah sesi login.
class AppPreferences {
  /// Mode tema. Saat ini hanya mode terang yang siap dipakai seluruh halaman
  /// (lihat catatan di `docs/round5-edutask.md`), tetapi nilainya disimpan agar
  /// tema gelap dapat diaktifkan tanpa migrasi preferensi.
  final ThemeMode themeMode;

  final bool welcomeSound;

  /// Pengingat tenggat lokal (Android/iOS).
  final bool deadlineReminders;

  /// Notifikasi in-app untuk pesan chat baru.
  final bool chatNotifications;

  /// Skala teks aplikasi (aksesibilitas), 0.9 – 1.4.
  final double textScale;

  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.welcomeSound = true,
    this.deadlineReminders = true,
    this.chatNotifications = true,
    this.textScale = 1.0,
  });

  static const double minTextScale = 0.9;
  static const double maxTextScale = 1.4;

  /// Batas aman: nilai dari penyimpanan selalu dijepit.
  static double clampTextScale(double value) {
    if (!value.isFinite) return 1.0;
    return value.clamp(minTextScale, maxTextScale);
  }

  static const String _kTheme = 'pref_theme_mode';
  static const String _kWelcomeSound = 'pref_welcome_sound';
  static const String _kReminders = 'pref_deadline_reminders';
  static const String _kChatNotif = 'pref_chat_notifications';
  static const String _kTextScale = 'pref_text_scale';

  static const AppPreferences defaults = AppPreferences();

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? welcomeSound,
    bool? deadlineReminders,
    bool? chatNotifications,
    double? textScale,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      welcomeSound: welcomeSound ?? this.welcomeSound,
      deadlineReminders: deadlineReminders ?? this.deadlineReminders,
      chatNotifications: chatNotifications ?? this.chatNotifications,
      textScale: clampTextScale(textScale ?? this.textScale),
    );
  }

  static String themeModeKey(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  static ThemeMode parseThemeMode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<AppPreferences> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return AppPreferences(
        themeMode: parseThemeMode(sp.getString(_kTheme)),
        welcomeSound: sp.getBool(_kWelcomeSound) ?? true,
        deadlineReminders: sp.getBool(_kReminders) ?? true,
        chatNotifications: sp.getBool(_kChatNotif) ?? true,
        textScale: clampTextScale(sp.getDouble(_kTextScale) ?? 1.0),
      );
    } catch (_) {
      // Penyimpanan tidak tersedia → pakai default, jangan gagalkan startup.
      return defaults;
    }
  }

  static Future<AppPreferences> read() => defaults.load();

  static Future<void> write({
    ThemeMode? themeMode,
    bool? welcomeSound,
    bool? deadlineReminders,
    bool? chatNotifications,
    double? textScale,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (themeMode != null) await sp.setString(_kTheme, themeModeKey(themeMode));
      if (welcomeSound != null) await sp.setBool(_kWelcomeSound, welcomeSound);
      if (deadlineReminders != null) await sp.setBool(_kReminders, deadlineReminders);
      if (chatNotifications != null) await sp.setBool(_kChatNotif, chatNotifications);
      if (textScale != null) await sp.setDouble(_kTextScale, clampTextScale(textScale));
    } catch (_) {
      // abaikan: preferensi tidak kritis
    }
  }
}

/// Dimuat sekali saat aplikasi dibuka; perubahan langsung dipakai UI.
class AppPreferencesNotifier extends StateNotifier<AppPreferences> {
  AppPreferencesNotifier() : super(AppPreferences.defaults) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await AppPreferences.read();
    if (mounted) state = loaded;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await AppPreferences.write(themeMode: mode);
  }

  Future<void> setWelcomeSound(bool enabled) async {
    state = state.copyWith(welcomeSound: enabled);
    await AppPreferences.write(welcomeSound: enabled);
  }

  Future<void> setDeadlineReminders(bool enabled) async {
    state = state.copyWith(deadlineReminders: enabled);
    await AppPreferences.write(deadlineReminders: enabled);
  }

  Future<void> setChatNotifications(bool enabled) async {
    state = state.copyWith(chatNotifications: enabled);
    await AppPreferences.write(chatNotifications: enabled);
  }

  Future<void> setTextScale(double scale) async {
    final safe = AppPreferences.clampTextScale(scale);
    state = state.copyWith(textScale: safe);
    await AppPreferences.write(textScale: safe);
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferences>(
  (ref) => AppPreferencesNotifier(),
);
