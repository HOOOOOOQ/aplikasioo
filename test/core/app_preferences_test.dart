import 'package:edutask/core/services/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPreferences.clampTextScale', () {
    test('nilai wajar dipertahankan', () {
      expect(AppPreferences.clampTextScale(1.0), 1.0);
      expect(AppPreferences.clampTextScale(1.2), 1.2);
    });

    test('nilai terlalu kecil / besar dijepit ke batas', () {
      expect(AppPreferences.clampTextScale(0.1), AppPreferences.minTextScale);
      expect(AppPreferences.clampTextScale(9.9), AppPreferences.maxTextScale);
    });

    test('NaN dan Infinity tidak merusak render teks', () {
      expect(AppPreferences.clampTextScale(double.nan), 1.0);
      expect(AppPreferences.clampTextScale(double.infinity), 1.0);
    });
  });

  group('AppPreferences.copyWith', () {
    test('default aman', () {
      const prefs = AppPreferences.defaults;
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.welcomeSound, isTrue);
      expect(prefs.deadlineReminders, isTrue);
      expect(prefs.chatNotifications, isTrue);
      expect(prefs.textScale, 1.0);
    });

    test('copyWith menjepit skala teks dan tidak mengubah nilai lain', () {
      final prefs = AppPreferences.defaults.copyWith(textScale: 5);
      expect(prefs.textScale, AppPreferences.maxTextScale);
      expect(prefs.welcomeSound, isTrue);
      expect(prefs.chatNotifications, isTrue);
    });

    test('copyWith hanya mengubah field yang diminta', () {
      final prefs = AppPreferences.defaults.copyWith(chatNotifications: false);
      expect(prefs.chatNotifications, isFalse);
      expect(prefs.deadlineReminders, isTrue);
    });
  });
}
