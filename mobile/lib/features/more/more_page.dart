import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/app_spacing.dart';

/// Phase 0 keeps only the two switches needed to verify RTL/LTR and light/dark (spec §76).
/// The full Settings screen arrives in Phase 1.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Wrap(spacing: AppSpacing.sm, children: [
          for (final loc in supportedLocales)
            ChoiceChip(
              label: Text(_localeName(loc)),
              selected: settings.locale == loc,
              onSelected: (_) => ctl.setLocale(loc),
            ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined)),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => ctl.setThemeMode(s.first),
        ),
      ]),
    );
  }

  // Language names are shown in their own language on purpose (standard practice, not UI copy).
  String _localeName(Locale l) => switch (l.languageCode) { 'ar' => 'العربية', 'fr' => 'Français', _ => 'English' };
}
