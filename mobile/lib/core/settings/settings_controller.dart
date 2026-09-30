import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive preferences only (theme, language). Secrets go to flutter_secure_storage in Phase 1.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.locale = const Locale('ar')});
  final ThemeMode themeMode;
  final Locale locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) =>
      AppSettings(themeMode: themeMode ?? this.themeMode, locale: locale ?? this.locale);
}

const supportedLocales = [Locale('ar'), Locale('fr'), Locale('en')];

final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main'));

class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'theme_mode';
  static const _kLocale = 'locale';

  @override
  AppSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final theme = ThemeMode.values.firstWhere((m) => m.name == prefs.getString(_kTheme), orElse: () => ThemeMode.system);
    final code = prefs.getString(_kLocale);
    final locale = supportedLocales.firstWhere((l) => l.languageCode == code, orElse: () => const Locale('ar'));
    return AppSettings(themeMode: theme, locale: locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_kTheme, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await ref.read(sharedPreferencesProvider).setString(_kLocale, locale.languageCode);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
