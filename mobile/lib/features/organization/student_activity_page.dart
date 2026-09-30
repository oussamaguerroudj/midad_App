import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/students_repository.dart';

class StudentActivityPage extends ConsumerStatefulWidget {
  const StudentActivityPage({required this.classId, super.key});
  final String classId;

  @override
  ConsumerState<StudentActivityPage> createState() => _StudentActivityPageState();
}

class _StudentActivityPageState extends ConsumerState<StudentActivityPage> {
  String? _filterStudentId;

  void _showLogActivityDialog(BuildContext context, List<StudentItem> students) {
    final l10n = AppLocalizations.of(context);
    String? selectedStudentId = students.isNotEmpty ? students.first.id : null;
    String category = 'positive_contribution';
    final noteCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.logActivity,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Student picker
                  DropdownButtonFormField<String>(
                    initialValue: selectedStudentId,
                    decoration: InputDecoration(
                      labelText: l10n.studentsTitle,
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                    items: students
                        .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.firstName} ${s.lastName}')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedStudentId = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category picker
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'نوع النشاط أو الملاحظة',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'positive_contribution', child: Text('🌟 مساهمة إيجابية ومتميزة')),
                      DropdownMenuItem(value: 'participated', child: Text('✋ مشاركة صفية')),
                      DropdownMenuItem(value: 'completed_homework', child: Text('📝 إنجاز الواجب')),
                      DropdownMenuItem(value: 'late', child: Text('⏱️ تأخر عن بداية الحصة')),
                      DropdownMenuItem(value: 'classroom_note', child: Text('📌 ملاحظة انضباطية / سلوكية')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => category = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Note text field
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'تفاصيل الملاحظة (اختياري)',
                      hintText: 'وصف موضوعي ومحدد لما حدث...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () async {
                      if (selectedStudentId == null) return;
                      Navigator.pop(ctx);

                      await ref.read(organizationRepositoryProvider).logActivity(
                            classId: widget.classId,
                            studentId: selectedStudentId!,
                            category: category,
                            note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                          );
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'positive_contribution':
      case 'participated':
        return AppColors.success;
      case 'completed_homework':
        return AppColors.secondary;
      case 'late':
        return AppColors.warning;
      case 'classroom_note':
      default:
        return AppColors.accent;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'positive_contribution':
        return Icons.star;
      case 'participated':
        return Icons.pan_tool;
      case 'completed_homework':
        return Icons.assignment_turned_in;
      case 'late':
        return Icons.access_time;
      case 'classroom_note':
      default:
        return Icons.note_alt;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'positive_contribution':
        return 'مساهمة متميزة';
      case 'participated':
        return 'مشاركة صفية';
      case 'completed_homework':
        return 'إنجاز الواجب';
      case 'late':
        return 'تأخر';
      case 'classroom_note':
      default:
        return 'ملاحظة سلوكية';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logsAsync = ref.watch(activityLogsStreamProvider(widget.classId));
    final studentsAsync = ref.watch(studentsStreamProvider((classId: widget.classId, search: null)));
    final students = studentsAsync.value ?? [];
    final studentMap = {for (final s in students) s.id: s};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityLogs),
        actions: [
          IconButton(
            tooltip: l10n.logActivity,
            icon: const Icon(Icons.add_comment),
            onPressed: () => _showLogActivityDialog(context, students),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (logs) {
          final filteredLogs = _filterStudentId == null
              ? logs
              : logs.where((l) => l.studentId == _filterStudentId).toList();

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('لا توجد تسجيلات نشاط أو مشاركة مسجلة بعد', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.logActivity),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () => _showLogActivityDialog(context, students),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter chip bar
              if (students.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _filterStudentId == null,
                        label: const Text('الكل'),
                        onSelected: (_) => setState(() => _filterStudentId = null),
                      ),
                      const SizedBox(width: 8),
                      ...students.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _filterStudentId == s.id,
                            label: Text('${s.firstName} ${s.lastName}'),
                            onSelected: (selected) {
                              setState(() => _filterStudentId = selected ? s.id : null);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Activity logs list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    final s = studentMap[log.studentId];
                    final dateStr = '${log.loggedOn.year}-${log.loggedOn.month.toString().padLeft(2, '0')}-${log.loggedOn.day.toString().padLeft(2, '0')}';
                    final color = _categoryColor(log.category);

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(_categoryIcon(log.category), color: color, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              s != null ? '${s.firstName} ${s.lastName}' : 'طالب',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _categoryLabel(log.category),
                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (log.note != null && log.note!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(log.note!, style: const TextStyle(color: AppColors.textPrimary)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
