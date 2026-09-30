import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/lessons_repository.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  DateTime _selectedDate = DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showRecordJournalSheet(BuildContext context, LessonItem lesson) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: lesson.journalCovered ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.recordJournal,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                lesson.topic,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brand),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.journalCovered,
                  hintText: 'اكتب ما تم إنجازه وشرحه مع الطلاب خلال الحصة...',
                  border: OutlineInputBorder(borderRadius: AppRadius.control),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(l10n.save),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                    ),
                    onPressed: () async {
                      final text = controller.text.trim();
                      await ref.read(lessonsRepositoryProvider).updateJournal(
                            lessonId: lesson.id,
                            completion: 'completed',
                            journalCovered: text,
                          );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.syncDone)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
            title: Text(l10n.newTask),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.tasks,
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('منخفضة (Low)')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسطة (Medium)')),
                    DropdownMenuItem(value: 'high', child: Text('عالية (High)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: () async {
                  final text = titleController.text.trim();
                  if (text.isNotEmpty) {
                    await ref.read(tasksRepositoryProvider).createTask(
                          title: text,
                          priority: priority,
                          dueAt: _selectedDate,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lessonsAsync = ref.watch(lessonsStreamProvider(null));
    final tasksAsync = ref.watch(tasksStreamProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plannerTitle),
        actions: [
          IconButton(
            tooltip: l10n.newLesson,
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/lessons/new'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Date bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              color: AppColors.brandSoft.withValues(alpha: 0.25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.brand),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Section Header: Lessons / Journal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.lessons,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.newLesson),
                    onPressed: () => context.push('/lessons/new'),
                  ),
                ],
              ),
            ),
          ),

          // Lessons List
          lessonsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator()))),
            error: (err, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(err.toString()))),
            data: (allLessons) {
              final dayLessons = allLessons.where((l) => l.lessonDate != null && _isSameDay(l.lessonDate!, _selectedDate)).toList();

              if (dayLessons.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.card,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Text(
                            'لا توجد حصص مجدولة لهذا اليوم.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = dayLessons[index];
                    final isDone = item.completion == 'completed';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: () => context.push('/lessons/${item.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.topic,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    _StatusBadge(status: item.completion),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    if (item.className != null) ...[
                                      Chip(
                                        label: Text(item.className!, style: const TextStyle(fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: AppColors.brandSoft.withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                    ],
                                    if (item.durationMin != null)
                                      Text(
                                        '⏱ ${item.durationMin} دقيقة',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                                if (item.journalCovered != null && item.journalCovered!.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: AppRadius.control,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.menu_book, size: 16, color: AppColors.success),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            item.journalCovered!,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xs),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    icon: Icon(isDone ? Icons.check_circle : Icons.edit_note, size: 16),
                                    label: Text(isDone ? 'تعديل دفتر النصوص' : l10n.recordJournal),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                                    ),
                                    onPressed: () => _showRecordJournalSheet(context, item),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: dayLessons.length,
                ),
              );
            },
          ),

          // Section Header: Tasks
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.lg, bottom: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.tasks,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_task),
                    tooltip: l10n.newTask,
                    onPressed: () => _showAddTaskDialog(context),
                  ),
                ],
              ),
            ),
          ),

          // Tasks List
          tasksAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (err, _) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(err.toString()))),
            data: (tasks) {
              if (tasks.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.card,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: Text(
                            'لا توجد مهام مسجلة. اضغط + لإضافة مهمة.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                        child: CheckboxListTile(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                          value: task.isCompleted,
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: task.priority == 'high'
                              ? const Text('أولوية عالية', style: TextStyle(color: AppColors.error, fontSize: 11))
                              : null,
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(tasksRepositoryProvider).toggleTask(task.id, val);
                            }
                          },
                        ),
                      ),
                    );
                  },
                  childCount: tasks.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'completed':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        label = 'مكتمل';
        break;
      case 'in_progress':
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        label = 'قيد الإنجاز';
        break;
      default:
        bg = AppColors.secondary.withValues(alpha: 0.15);
        fg = AppColors.secondary;
        label = 'مخطط';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.control),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
