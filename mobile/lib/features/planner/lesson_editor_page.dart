import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';

class LessonEditorPage extends ConsumerStatefulWidget {
  const LessonEditorPage({super.key, this.lessonId});
  final String? lessonId;

  @override
  ConsumerState<LessonEditorPage> createState() => _LessonEditorPageState();
}

class _LessonEditorPageState extends ConsumerState<LessonEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicCtrl = TextEditingController();
  final _objectivesCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();
  final _homeworkCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  int _durationMin = 60;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.lessonId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final repo = ref.read(lessonsRepositoryProvider);
    final lesson = await repo.getLessonById(widget.lessonId!);
    if (lesson != null && mounted) {
      setState(() {
        _topicCtrl.text = lesson.topic;
        _selectedClassId = lesson.classId;
        _selectedDate = lesson.lessonDate ?? DateTime.now();
        _durationMin = lesson.durationMin ?? 60;
        _objectivesCtrl.text = lesson.objectives ?? '';
        _contentCtrl.text = lesson.content ?? '';
        _activitiesCtrl.text = lesson.activities ?? '';
        _homeworkCtrl.text = lesson.homework ?? '';
        _notesCtrl.text = lesson.notes ?? '';
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _objectivesCtrl.dispose();
    _contentCtrl.dispose();
    _activitiesCtrl.dispose();
    _homeworkCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final repo = ref.read(lessonsRepositoryProvider);

    try {
      if (widget.lessonId == null) {
        await repo.createLesson(
          topic: _topicCtrl.text.trim(),
          classId: _selectedClassId,
          lessonDate: _selectedDate,
          durationMin: _durationMin,
          objectives: _objectivesCtrl.text.trim().isEmpty ? null : _objectivesCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          activities: _activitiesCtrl.text.trim().isEmpty ? null : _activitiesCtrl.text.trim(),
          homework: _homeworkCtrl.text.trim().isEmpty ? null : _homeworkCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonId == null ? l10n.newLesson : l10n.editLesson),
        actions: [
          IconButton(
            tooltip: l10n.save,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Topic
                  TextFormField(
                    controller: _topicCtrl,
                    decoration: InputDecoration(
                      labelText: '${l10n.lessonTopic} *',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة موضوع الدرس' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Class Selector
                  classesAsync.when(
                    data: (classes) {
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
                        decoration: InputDecoration(
                          labelText: l10n.className,
                          border: OutlineInputBorder(borderRadius: AppRadius.control),
                        ),
                        items: classes
                            .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.subjectName})')))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedClassId = val),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Date and Duration
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _durationMin,
                          decoration: InputDecoration(
                            labelText: 'المدة (دقيقة)',
                            border: OutlineInputBorder(borderRadius: AppRadius.control),
                          ),
                          items: const [
                            DropdownMenuItem(value: 45, child: Text('45 دقيقة')),
                            DropdownMenuItem(value: 60, child: Text('60 دقيقة (ساعة)')),
                            DropdownMenuItem(value: 90, child: Text('90 دقيقة')),
                            DropdownMenuItem(value: 120, child: Text('120 دقيقة (ساعتان)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _durationMin = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Objectives
                  TextFormField(
                    controller: _objectivesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.objectives,
                      hintText: 'الأهداف والكفاءات المستهدفة...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Content & Activities
                  TextFormField(
                    controller: _contentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.contentAndActivities,
                      hintText: 'المحتوى التعليمي والأنشطة المقررة...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Homework
                  TextFormField(
                    controller: _homeworkCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.homework,
                      hintText: 'الواجبات والتطبيقات المنزلية...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Notes
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.notes,
                      hintText: 'ملاحظات وتذكيرات شخصية للمعلم...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: Text(l10n.save, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
