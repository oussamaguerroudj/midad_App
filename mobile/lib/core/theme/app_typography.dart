import 'package:flutter/material.dart';

/// Fonts: Tajawal (Arabic) and Inter (Latin). Font files must be bundled (offline-first);
/// until then the platform fallback is used (see docs/PHASE_REPORT_0.md).
abstract final class AppTypography {
  static const latinFamily = 'Inter';
  static const arabicFamily = 'Tajawal';

  static String familyFor(Locale locale) => locale.languageCode == 'ar' ? arabicFamily : latinFamily;

  static TextTheme textTheme(Color primary, Color secondary, Locale locale) {
    final f = familyFor(locale);
    TextStyle s(double size, FontWeight w, Color c, {double h = 1.35}) =>
        TextStyle(fontFamily: f, fontSize: size, fontWeight: w, color: c, height: h);
    return TextTheme(
      headlineMedium: s(24, FontWeight.w700, primary),
      titleLarge: s(20, FontWeight.w700, primary),
      titleMedium: s(16, FontWeight.w600, primary),
      bodyLarge: s(16, FontWeight.w400, primary, h: 1.5),
      bodyMedium: s(14, FontWeight.w400, primary, h: 1.5),
      bodySmall: s(12, FontWeight.w400, secondary),
      labelLarge: s(14, FontWeight.w600, primary),
      labelSmall: s(11, FontWeight.w500, secondary),
    );
  }
}
