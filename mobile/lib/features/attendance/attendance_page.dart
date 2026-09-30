import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({required this.classId, super.key});

  final String classId;

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  String? _sessionId;
  List<AttendanceRecordItem> _records = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSessionAndRoster();
  }

  Future<void> _loadSessionAndRoster() async {
    setState(() => _isLoading = true);
    final repo = ref.read(attendanceRepositoryProvider);
    final sId = await repo.createOrGetSession(
      classId: widget.classId,
      date: _selectedDate,
    );
    final roster = await repo.getSessionRoster(sId, widget.classId);

    if (mounted) {
      setState(() {
        _sessionId = sId;
        _records = roster;
        _isLoading = false;
      });
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final r in _records) {
        r.status = 'present';
      }
    });
  }

  Future<void> _save() async {
    if (_sessionId == null) return;
    setState(() => _isSaving = true);

    final l10n = AppLocalizations.of(context);
    await ref.read(attendanceRepositoryProvider).saveRecords(
          sessionId: _sessionId!,
          records: _records,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncDone)),
      );
    }
  }

  void _setStatus(AttendanceRecordItem item, String status) {
    setState(() {
      item.status = status;
    });
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'present':
        return AppColors.success;
      case 'absent':
        return AppColors.danger;
      case 'late':
        return AppColors.warning;
      case 'excused':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.attendance),
        actions: [
          IconButton(
            tooltip: l10n.markAllPresent,
            icon: const Icon(Icons.done_all),
            onPressed: _markAllPresent,
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
                // Date bar & Mark all present button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  color: AppColors.brandSoft.withValues(alpha: 0.3),
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
                          if (picked != null && picked != _selectedDate) {
                            setState(() => _selectedDate = picked);
                            _loadSessionAndRoster();
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: AppColors.brand),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.done_all, size: 16),
                        label: Text(l10n.markAllPresent),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                        ),
                        onPressed: _markAllPresent,
                      ),
                    ],
                  ),
                ),

                // Summary Stats
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatusChip(
                        label: l10n.present,
                        count: _records.where((r) => r.status == 'present').length,
                        color: AppColors.success,
                      ),
                      _StatusChip(
                        label: l10n.absent,
                        count: _records.where((r) => r.status == 'absent').length,
                        color: AppColors.danger,
                      ),
                      _StatusChip(
                        label: l10n.late,
                        count: _records.where((r) => r.status == 'late').length,
                        color: AppColors.warning,
                      ),
                      _StatusChip(
                        label: l10n.excused,
                        count: _records.where((r) => r.status == 'excused').length,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Roster
                Expanded(
                  child: _records.isEmpty
                      ? Center(child: Text(l10n.noStudentsYet))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final item = _records[index];
                            final color = _colorForStatus(item.status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: color.withValues(alpha: 0.15),
                                      child: Text(
                                        item.studentName.isNotEmpty ? item.studentName[0] : 'ط',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.studentName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (item.note != null && item.note!.isNotEmpty)
                                            Text(
                                              item.note!,
                                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Status Toggle Buttons
                                    _StatusButton(
                                      text: l10n.present,
                                      isSelected: item.status == 'present',
                                      color: AppColors.success,
                                      onTap: () => _setStatus(item, 'present'),
                                    ),
                                    const SizedBox(width: 4),
                                    _StatusButton(
                                      text: l10n.absent,
                                      isSelected: item.status == 'absent',
                                      color: AppColors.danger,
                                      onTap: () => _setStatus(item, 'absent'),
                                    ),
                                    const SizedBox(width: 4),
                                    _StatusButton(
                                      text: l10n.late,
                                      isSelected: item.status == 'late',
                                      color: AppColors.warning,
                                      onTap: () => _setStatus(item, 'late'),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: $count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.text,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: isSelected ? color : AppColors.lightBorder),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
