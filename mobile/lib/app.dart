import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';

class MidadApp extends ConsumerWidget {
  const MidadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      locale: settings.locale, // Directionality (RTL for ar) follows the locale automatically
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: AppTheme.light(settings.locale),
      darkTheme: AppTheme.dark(settings.locale),
      themeMode: settings.themeMode,
      debugShowCheckedModeBanner: false,
    );
  }
}
