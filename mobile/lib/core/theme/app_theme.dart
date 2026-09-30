import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light(Locale locale) => _build(locale, dark: false);
  static ThemeData dark(Locale locale) => _build(locale, dark: true);

  static ThemeData _build(Locale locale, {required bool dark}) {
    final bg = dark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = dark ? AppColors.darkCard : AppColors.lightCard;
    final text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final text2 = dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final brand = dark ? AppColors.brandOnDark : AppColors.brand;

    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: brand,
      onPrimary: dark ? AppColors.darkBackground : AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      tertiary: AppColors.accent,
      error: AppColors.danger,
      onError: AppColors.white,
      surface: card,
      onSurface: text,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: AppTypography.textTheme(text, text2, locale),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card, side: BorderSide(color: border)),
      ),
      appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: text, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: brand.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: AppTypography.familyFor(locale), fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
    );
  }
}
