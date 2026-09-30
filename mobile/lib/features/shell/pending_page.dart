import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';

enum PendingTitle { signIn, home, classes, planner, analytics }

/// Honest placeholder (spec §77): clearly states the section is not built, showing which phase delivers it.
class PendingPage extends StatelessWidget {
  const PendingPage({super.key, required this.phase, required this.titleKey});
  final int phase;
  final PendingTitle titleKey;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final title = switch (titleKey) {
      PendingTitle.signIn => l.appName,
      PendingTitle.home => l.navHome,
      PendingTitle.classes => l.navClasses,
      PendingTitle.planner => l.navPlanner,
      PendingTitle.analytics => l.navAnalytics,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.pending, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(l.pendingTitle(phase), style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(l.pendingBody, style: t.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
