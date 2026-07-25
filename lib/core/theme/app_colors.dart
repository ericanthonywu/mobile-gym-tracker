import 'package:flutter/material.dart';

/// App-wide color tokens — Fitness dark theme.
/// Tuned for iPhone 16 Pro (iOS 26) dark mode only.
class AppColors {
  AppColors._();

  // --- Backgrounds ---
  static const Color background = Color(0xFF0F0F14);      // deep dark, avoids OLED smear
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF16213E);
  static const Color surfaceHighlight = Color(0xFF1E1E3A);
  static const Color surfaceCard = Color(0xFF1C1C2E);

  // --- Brand (Energy Orange) ---
  static const Color primary = Color(0xFFF97316);         // vibrant orange
  static const Color primaryLight = Color(0xFFFB923C);
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryMuted = Color(0x26F97316);    // 15% opacity

  // --- Accent (Success Green) ---
  static const Color accent = Color(0xFF22C55E);
  static const Color accentMuted = Color(0x2622C55E);

  // --- Semantic ---
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningMuted = Color(0x26FBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color errorMuted = Color(0x26EF4444);
  static const Color info = Color(0xFF38BDF8);

  // --- Text ---
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textDisabled = Color(0xFF4A4A5A);
  static const Color textOnPrimary = Color(0xFF0F172A);

  // --- Borders / Dividers ---
  static const Color border = Color(0xFF2A2A3E);
  static const Color divider = Color(0xFF1E1E2E);

  // --- Chart colors ---
  static const Color chartOrange = Color(0xFFF97316);
  static const Color chartGreen = Color(0xFF22C55E);
  static const Color chartBlue = Color(0xFF38BDF8);
  static const Color chartPurple = Color(0xFFA78BFA);

  // --- Exercise status colors ---
  static const Color statusCompleted = Color(0xFF22C55E);
  static const Color statusActive = Color(0xFFF97316);
  static const Color statusSkipped = Color(0xFFEF4444);
  static const Color statusPending = Color(0xFF4A4A5A);
}
