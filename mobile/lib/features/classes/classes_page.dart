import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';

class ClassesPage extends ConsumerWidget {
  const ClassesPage({super.key});

  void _showAddClassDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.addClass,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.className,
                    hintText: 'مثال: 1 ج م ع 1',
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errValidation : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: levelCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.classLevel,
                    hintText: 'مثال: الأولى ثانوي',
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.subjectName,
                    hintText: 'مثال: الرياضيات',
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errValidation : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await ref.read(classesRepositoryProvider).createClass(
                          name: nameCtrl.text,
                          level: levelCtrl.text.isNotEmpty ? levelCtrl.text : null,
                          subjectName: subjectCtrl.text,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.classesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            onPressed: () => ref.read(classesRepositoryProvider).syncFromRemote(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addClass,
        onPressed: () => _showAddClassDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.noClassesYet, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addClass),
                    onPressed: () => _showAddClassDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final c = classes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brandSoft,
                    child: Icon(Icons.class_, color: AppColors.brand),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${c.subjectName} · ${c.level ?? ""}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
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
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/classes/${c.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
      ),
    );
  }
}
