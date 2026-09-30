import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/classes_repository.dart';

class ClassDetailPage extends ConsumerWidget {
  const ClassDetailPage({required this.classId, super.key});

  final String classId;

  void _showAddStudentDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final refCtrl = TextEditingController();

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
                  l10n.addStudent,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.firstName,
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errValidation : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.lastName,
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.errValidation : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.studentNumber,
                    hintText: 'مثال: 2026-042',
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await ref.read(studentsRepositoryProvider).createStudent(
                          firstName: firstNameCtrl.text,
                          lastName: lastNameCtrl.text,
                          externalRef: refCtrl.text.isNotEmpty ? refCtrl.text : null,
                          classId: classId,
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
    final classFuture = ref.watch(classesRepositoryProvider).getClassById(classId);
    final studentsAsync = ref.watch(studentsStreamProvider((classId: classId, search: null)));

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<ClassWithSubject?>(
          future: classFuture,
          builder: (context, snapshot) {
            return Text(snapshot.data?.name ?? l10n.classesTitle);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'المفضلة',
            icon: const Icon(Icons.star_border),
            onPressed: () async {
              await ref.read(organizationRepositoryProvider).toggleFavorite('class', classId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث حالة المفضلة لهذا القسم')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addStudent,
        onPressed: () => _showAddStudentDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<ClassWithSubject?>(
        future: classFuture,
        builder: (context, classSnapshot) {
          final cls = classSnapshot.data;

          return Column(
            children: [
              // Class summary header
              if (cls != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: AppColors.brandSoft.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.brand,
                        child: Icon(Icons.school, color: AppColors.white),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cls.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${cls.subjectName} · ${cls.level ?? ""}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons row 1 (Attendance, Gradebook, Assignments)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: Text(l10n.attendance),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/attendance'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.grade_outlined, size: 16),
                        label: Text(l10n.gradebook),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/gradebook'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assignment_outlined, size: 16),
                        label: Text(l10n.assignments),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/assignments'),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons row 2 (Seating Plan, Groups, Activity/Participation)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_restaurant_outlined, size: 16),
                        label: Text(l10n.seatingPlan),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/seating'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.groups_outlined, size: 16),
                        label: Text(l10n.studentGroups),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/groups'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: Text(l10n.activityLogs),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/classes/$classId/activity'),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons row 3 (Reports & Bulletins, Import/Export CSV)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('كشوف النقاط والتقارير'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/reports'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.swap_vert, size: 16),
                        label: const Text('استيراد وتصدير CSV'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/import-export/$classId'),
                      ),
                    ),
                  ],
                ),
              ),


              // Enrolled students header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.studentsTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addStudent),
                      onPressed: () => _showAddStudentDialog(context, ref),
                    ),
                  ],
                ),
              ),

              // Students list
              Expanded(
                child: studentsAsync.when(
                  data: (students) {
                    if (students.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(l10n.noStudentsYet, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: students.length,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final s = students[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightBorder,
                              child: Text(
                                s.firstName.isNotEmpty ? s.firstName[0] : 'ط',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                              ),
                            ),
                            title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: s.externalRef != null ? Text(s.externalRef!) : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/students/${s.id}'),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text(err.toString())),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
