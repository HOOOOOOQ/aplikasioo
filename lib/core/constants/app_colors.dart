import 'package:flutter/material.dart';

class AppColors {
  // Primary - Biru EduTask
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryContainer = Color(0xFFE0E7FF);

  // Background
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Status - Tugas
  static const Color success = Color(0xFF16A34A); // hijau - tugas selesai
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF15803D);

  static const Color warning = Color(0xFFF59E0B); // oranye - mendekati tenggat
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFDC2626); // merah - terlambat
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color info = Color(0xFF0EA5E9);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // Neutral
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color disabled = Color(0xFFCBD5E1);

  // Navigation
  static const Color navSelected = primary;
  static const Color navUnselected = Color(0xFF64748B);

  // Card
  static const Color cardShadow = Color(0x0A000000);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
  );
}
