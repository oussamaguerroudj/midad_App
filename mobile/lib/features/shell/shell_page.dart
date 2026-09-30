import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_shadows.dart';

/// Bottom navigation: Home / Classes / Planner / Analytics / More (no AI tab, spec §10).
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.fab),
        child: FloatingActionButton(
          tooltip: l.quickAdd,
          // Quick-action sheet is built in Phase 2; the button is present but intentionally inert until then.
          onPressed: null,
          child: const Icon(AppIcons.add),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(AppIcons.home), selectedIcon: const Icon(AppIcons.homeActive), label: l.navHome),
          NavigationDestination(icon: const Icon(AppIcons.classes), selectedIcon: const Icon(AppIcons.classesActive), label: l.navClasses),
          NavigationDestination(icon: const Icon(AppIcons.planner), selectedIcon: const Icon(AppIcons.plannerActive), label: l.navPlanner),
          NavigationDestination(icon: const Icon(AppIcons.analytics), selectedIcon: const Icon(AppIcons.analyticsActive), label: l.navAnalytics),
          NavigationDestination(icon: const Icon(AppIcons.more), selectedIcon: const Icon(AppIcons.moreActive), label: l.navMore),
        ],
      ),
    );
  }
}
