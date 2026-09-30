import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/students_repository.dart';

class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({required this.studentId, super.key});

  final String studentId;

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  final List<String> _localNotes = [];

  void _showAddNoteDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.addNote),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.noteHint,
              border: OutlineInputBorder(borderRadius: AppRadius.control),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  setState(() => _localNotes.insert(0, text));
                }
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final studentFuture = ref.watch(studentsRepositoryProvider).getStudentById(widget.studentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studentsTitle),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addNote,
        onPressed: () => _showAddNoteDialog(context),
        child: const Icon(Icons.note_add),
      ),
      body: FutureBuilder<StudentItem?>(
        future: studentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final student = snapshot.data;
          if (student == null) {
            return const Center(child: Text('Student not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Profile Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.brandSoft,
                        child: Text(
                          student.firstName.isNotEmpty ? student.firstName[0] : 'ط',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.brand),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (student.externalRef != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBorder,
                                  borderRadius: AppRadius.control,
                                ),
                                child: Text(
                                  student.externalRef!,
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Enrolled Classes
              if (student.enrolledClasses.isNotEmpty) ...[
                Text(
                  l10n.classesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: student.enrolledClasses.map((clsName) {
                    return Chip(
                      avatar: const Icon(Icons.school, size: 16, color: AppColors.brand),
                      label: Text(clsName),
                      backgroundColor: AppColors.brandSoft,
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Notes Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.notes,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addNote),
                    onPressed: () => _showAddNoteDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (_localNotes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(
                        l10n.noteHint,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                ..._localNotes.map((note) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note_outlined, size: 20, color: AppColors.brand),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(note, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
