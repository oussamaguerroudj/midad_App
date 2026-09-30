import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

/// Bottom navigation: Home / Classes / Planner / Analytics / More (no AI tab, spec §10).
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _showQuickActionSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.quickAction,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.brandSoft, child: Icon(Icons.menu_book, color: AppColors.brand)),
                title: Text(l.newLesson, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('تخطيط وتحضير درس جديد'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/lessons/new');
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.brandSoft, child: Icon(Icons.school, color: AppColors.brand)),
                title: Text(l.addClass, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('إضافة قسم أو فوج تربوي جديد'),
                onTap: () {
                  Navigator.pop(ctx);
                  shell.goBranch(1);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.brandSoft, child: Icon(Icons.folder_shared, color: AppColors.brand)),
                title: Text(l.documentsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('إدارة الملفات والوثائق والمذكرات'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/documents');
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.brandSoft, child: Icon(Icons.search, color: AppColors.brand)),
                title: Text(l.globalSearch, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('البحث الفوري في كافة عناصر التطبيق'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/search');
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
          onPressed: () => _showQuickActionSheet(context),
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
