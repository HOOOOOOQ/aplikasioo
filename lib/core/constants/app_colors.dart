import 'package:flutter/material.dart';

/// Palet warna EduTask.
///
/// Identitas merek (biru) dipertahankan, tetapi nilai warna dirapikan agar
/// kontras teks memenuhi WCAG AA pada latar terang.
class AppColors {
  AppColors._();

  // --- Merek ---
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF123C9B);
  static const Color primaryContainer = Color(0xFFE3EAFF);
  static const Color onPrimaryContainer = Color(0xFF0D2E7A);

  // --- Permukaan ---
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F4F9);
  static const Color surfaceMuted = Color(0xFFEDF1F8);

  // --- Teks ---
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF5B6B85);
  static const Color textTertiary = Color(0xFF8A99B0);

  // --- Status tugas ---
  static const Color success = Color(0xFF15803D);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF166534);

  static const Color warning = Color(0xFFB45309);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);

  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF991B1B);

  static const Color info = Color(0xFF0369A1);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // --- Netral ---
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF1F7);
  static const Color disabled = Color(0xFFCBD5E1);

  // --- Navigasi ---
  static const Color navSelected = primary;
  static const Color navUnselected = Color(0xFF6B7A93);

  // --- Bayangan ---
  static const Color cardShadow = Color(0x0F0F172A);

  // --- Gradien ---
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A56DB), Color(0xFF2F6FEF)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF163FA8), Color(0xFF1A56DB), Color(0xFF3B82F6)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF15803D), Color(0xFF22C55E)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
  );
}

/// Token spasi & radius agar jarak antar elemen konsisten di seluruh aplikasi.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
}
