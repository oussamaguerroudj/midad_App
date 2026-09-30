import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/gradebook_repository.dart';

class AssessmentResultsPage extends ConsumerStatefulWidget {
  const AssessmentResultsPage({
    required this.classId,
    required this.assessmentId,
    super.key,
  });

  final String classId;
  final String assessmentId;

  @override
  ConsumerState<AssessmentResultsPage> createState() => _AssessmentResultsPageState();
}

class _AssessmentResultsPageState extends ConsumerState<AssessmentResultsPage> {
  List<GradeResultItem> _results = [];
  final Map<String, TextEditingController> _controllers = {};
  final List<Map<String, double?>> _undoHistory = [];
  double _maxScore = 20.0;
  String _assessmentTitle = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(gradebookRepositoryProvider);

    final a = await repo.getAssessment(widget.assessmentId);
    if (a != null) {
      _maxScore = a.maxScore;
      _assessmentTitle = a.title;
    }

    final results = await repo.getAssessmentResults(widget.assessmentId, widget.classId);

    for (final r in results) {
      _controllers[r.studentId] = TextEditingController(
        text: r.score != null ? (r.score! % 1 == 0 ? r.score!.toInt().toString() : r.score!.toString()) : '',
      );
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _pushHistorySnapshot() {
    final snapshot = {
      for (final r in _results) r.studentId: r.score,
    };
    _undoHistory.add(snapshot);
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    final last = _undoHistory.removeLast();
    setState(() {
      for (final r in _results) {
        if (last.containsKey(r.studentId)) {
          r.score = last[r.studentId];
          _controllers[r.studentId]?.text = r.score != null ? r.score.toString() : '';
        }
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    // Read current inputs
    for (final r in _results) {
      final text = _controllers[r.studentId]?.text.trim() ?? '';
      if (text.isEmpty) {
        r.score = null;
      } else {
        final parsed = double.tryParse(text);
        if (parsed == null || parsed < 0 || parsed > _maxScore) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.scoreExceedsMax(_maxScore.toString()))),
          );
          return;
        }
        r.score = parsed;
      }
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(gradebookRepositoryProvider).saveResults(
            assessmentId: widget.assessmentId,
            maxScore: _maxScore,
            results: _results,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_assessmentTitle.isNotEmpty ? _assessmentTitle : l10n.gradebook),
        actions: [
          IconButton(
            tooltip: l10n.undo,
            icon: const Icon(Icons.undo),
            onPressed: _undoHistory.isNotEmpty ? _undo : null,
          ),
          IconButton(
            tooltip: l10n.save,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: AppColors.brandSoft.withValues(alpha: 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.score,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${l10n.maxScore}: $_maxScore',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Rapid Score Entry List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final ctrl = _controllers[item.studentId]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.brandSoft,
                                child: Text(
                                  item.studentName.isNotEmpty ? item.studentName[0] : 'ط',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  item.studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Score Input Field
                              SizedBox(
                                width: 88,
                                child: TextFormField(
                                  controller: ctrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '/$_maxScore',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    border: OutlineInputBorder(borderRadius: AppRadius.control),
                                  ),
                                  onChanged: (val) {
                                    _pushHistorySnapshot();
                                    final d = double.tryParse(val.trim());
                                    item.score = d;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.save),
          ),
        ),
      ),
    );
  }
}
