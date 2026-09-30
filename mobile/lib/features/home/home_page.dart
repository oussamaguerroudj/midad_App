import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../auth/auth_state.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final teacher = ref.watch(currentTeacherProvider);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/brand/midad_mark.png', width: 28, height: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => ref.read(authStatusProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(classesRepositoryProvider).syncFromRemote();
          await ref.read(studentsRepositoryProvider).syncFromRemote();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Teacher Greeting Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brand, AppColors.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.greetingTeacher(teacher?.fullName ?? 'أستاذ'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (teacher?.schoolName.isNotEmpty ?? false) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: AppColors.brandSoft),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          teacher!.schoolName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Stats Row
            classesAsync.when(
              data: (classes) {
                final totalClasses = classes.length;
                final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.studentCount);

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.class_outlined,
                        label: l10n.classesTitle,
                        value: totalClasses.toString(),
                        color: AppColors.brand,
                        onTap: () => context.go(Routes.classes),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_outline,
                        label: l10n.studentsTitle,
                        value: totalStudents.toString(),
                        color: AppColors.accent,
                        onTap: () => context.go(Routes.classes),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              )),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Today's classes / Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.classesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go(Routes.classes),
                  child: Text(l10n.navClasses),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          Icon(Icons.school_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.noClassesYet, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: classes.map((c) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.brandSoft,
                          child: Icon(Icons.school, color: AppColors.brand),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${c.subjectName} · ${c.level ?? ""}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lightBorder,
                            borderRadius: AppRadius.control,
                          ),
                          child: Text(
                            l10n.studentsCount(c.studentCount),
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        onTap: () => context.push('/classes/${c.id}'),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, _) => Text(err.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
