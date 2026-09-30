import 'dart:ui';

/// Single source of truth for colour. No `Color(0x...)` anywhere else (spec §8).
abstract final class AppColors {
  // Brand (sampled from the MIDAD logo)
  static const brand = Color(0xFF7B1737);
  static const brandDeep = Color(0xFF4E0A22);
  static const brandSoft = Color(0xFFF6D5DC);
  static const brandOnDark = Color(0xFFE58AA3); // readable brand tint on dark surfaces

  // Spec tokens
  static const primary = Color(0xFF101828);
  static const secondary = Color(0xFF2563EB);
  static const accent = Color(0xFF7C3AED);
  static const lightBackground = Color(0xFFF7F8FC);
  static const darkBackground = Color(0xFF080B14);
  static const lightCard = Color(0xFFFFFFFF);
  static const darkCard = Color(0xFF111827);
  static const textPrimary = Color(0xFF101828);
  static const textSecondary = Color(0xFF667085);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  // Derived neutrals
  static const lightBorder = Color(0xFFE4E7EC);
  static const darkBorder = Color(0xFF1F2937);
  static const darkTextPrimary = Color(0xFFF2F4F7);
  static const darkTextSecondary = Color(0xFF98A2B3);
  static const white = Color(0xFFFFFFFF);
}
