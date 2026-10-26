import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan & suara yang tersimpan lokal di perangkat.
///
/// Semua nilai punya default yang aman; kegagalan penyimpanan tidak boleh
/// membuat aplikasi crash atau mengubah sesi login.
class AppPreferences {
  final ThemeMode themeMode;
  final bool welcomeSound;
  final bool deadlineReminders;

  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.welcomeSound = true,
    this.deadlineReminders = true,
  });

  static const String _kTheme = 'pref_theme_mode';
  static const String _kWelcomeSound = 'pref_welcome_sound';
  static const String _kReminders = 'pref_deadline_reminders';

  static const AppPreferences defaults = AppPreferences();

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? welcomeSound,
    bool? deadlineReminders,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      welcomeSound: welcomeSound ?? this.welcomeSound,
      deadlineReminders: deadlineReminders ?? this.deadlineReminders,
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
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (themeMode != null) await sp.setString(_kTheme, themeModeKey(themeMode));
      if (welcomeSound != null) await sp.setBool(_kWelcomeSound, welcomeSound);
      if (deadlineReminders != null) await sp.setBool(_kReminders, deadlineReminders);
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
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferences>(
  (ref) => AppPreferencesNotifier(),
);
