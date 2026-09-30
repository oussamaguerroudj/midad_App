import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/assignments_repository.dart';

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends ConsumerState<AssignmentsPage> {
  void _showAddAssignmentDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
            title: Text(l10n.newAssignment),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: '${l10n.assignments} *',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'الوصف أو رقم الصفحة والتمارين',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('${l10n.dueOn}: ${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isNotEmpty) {
                    await ref.read(assignmentsRepositoryProvider).createAssignment(
                          classId: widget.classId,
                          title: title,
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          dueOn: dueDate,
                        );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        });
      },
    );
  }

  void _showRecordsSheet(BuildContext context, AssignmentItem assignment) async {
    final repo = ref.read(assignmentsRepositoryProvider);
    final records = await repo.getAssignmentRecords(assignment.id, widget.classId);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        assignment.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];
                      return ListTile(
                        title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'completed', icon: Icon(Icons.check, size: 14)),
                            ButtonSegment(value: 'missing', icon: Icon(Icons.close, size: 14)),
                            ButtonSegment(value: 'assigned', icon: Icon(Icons.hourglass_empty, size: 14)),
                          ],
                          selected: {r.status},
                          onSelectionChanged: (newVal) async {
                            setSheetState(() => r.status = newVal.first);
                            await repo.saveAssignmentRecords(
                              assignmentId: assignment.id,
                              records: records,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final assignmentsAsync = ref.watch(assignmentsStreamProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assignments),
        actions: [
          IconButton(
            tooltip: l10n.newAssignment,
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAssignmentDialog(context),
          ),
        ],
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('لا توجد واجبات منزلية لهذا القسم بعد', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newAssignment),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () => _showAddAssignmentDialog(context),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                child: ListTile(
                  title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a.description != null && a.description!.isNotEmpty)
                        Text(a.description!),
                      if (a.dueOn != null)
                        Text(
                          '📅 ${l10n.dueOn}: ${a.dueOn!.year}-${a.dueOn!.month.toString().padLeft(2, '0')}-${a.dueOn!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showRecordsSheet(context, a),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
