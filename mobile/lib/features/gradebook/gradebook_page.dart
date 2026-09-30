import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';

class GradebookPage extends ConsumerWidget {
  const GradebookPage({required this.classId, super.key});

  final String classId;

  void _showAddAssessmentDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final maxScoreCtrl = TextEditingController(text: '20');
    final coeffCtrl = TextEditingController(text: '1');
    String selectedKind = 'test';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                      l10n.addAssessment,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.assessmentTitle,
                        hintText: 'مثال: الفرض الأول للفصل الأول',
                        border: OutlineInputBorder(borderRadius: AppRadius.control),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errValidation : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: maxScoreCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.maxScore,
                              border: OutlineInputBorder(borderRadius: AppRadius.control),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              return (d == null || d <= 0) ? l10n.errValidation : null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: coeffCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.coefficient,
                              border: OutlineInputBorder(borderRadius: AppRadius.control),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              return (d == null || d <= 0) ? l10n.errValidation : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final max = double.parse(maxScoreCtrl.text);
                        final coeff = double.parse(coeffCtrl.text);

                        await ref.read(gradebookRepositoryProvider).createAssessment(
                              classId: classId,
                              title: titleCtrl.text,
                              kind: selectedKind,
                              assessedOn: DateTime.now(),
                              maxScore: max,
                              coefficient: coeff,
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
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final assessmentsAsync = ref.watch(assessmentsStreamProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gradebook),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addAssessment,
        onPressed: () => _showAddAssessmentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: assessmentsAsync.when(
        data: (assessments) {
          if (assessments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.addAssessment, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAssessment),
                    onPressed: () => _showAddAssessmentDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: assessments.length,
            itemBuilder: (context, index) {
              final a = assessments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brandSoft,
                    child: Icon(Icons.grade, color: AppColors.brand),
                  ),
                  title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${l10n.maxScore}: ${a.maxScore} · ${l10n.coefficient}: ${a.coefficient}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/classes/$classId/assessments/${a.id}'),
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
