import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/local/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/students_repository.dart';

class SeatingPlanPage extends ConsumerStatefulWidget {
  const SeatingPlanPage({required this.classId, super.key});
  final String classId;

  @override
  ConsumerState<SeatingPlanPage> createState() => _SeatingPlanPageState();
}

class _SeatingPlanPageState extends ConsumerState<SeatingPlanPage> {
  String? _selectedPlanId;

  void _showNewPlanDialog(BuildContext context, List<StudentItem> students) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: 'مخطط الصفوف الرئيسي');
    String layout = 'rows';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.newSeatingPlan),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المخطط',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: layout,
                    decoration: InputDecoration(
                      labelText: 'التوزيع',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'rows', child: Text('صفوف تقليدية (Rows)')),
                      DropdownMenuItem(value: 'groups', child: Text('مجموعات وجزر (Groups)')),
                      DropdownMenuItem(value: 'u_shape', child: Text('شكل حرف U (U-Shape)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => layout = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);

                    // Build default layout assignments for enrolled students
                    final members = <({String? studentId, double seatX, double seatY})>[];
                    for (int i = 0; i < students.length; i++) {
                      final row = (i ~/ 4).toDouble();
                      final col = (i % 4).toDouble();
                      members.add((studentId: students[i].id, seatX: col, seatY: row));
                    }

                    final created = await ref.read(organizationRepositoryProvider).createSeatingPlan(
                          classId: widget.classId,
                          name: nameCtrl.text.trim(),
                          layout: layout,
                          members: members,
                        );
                    setState(() => _selectedPlanId = created.id);
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plansAsync = ref.watch(seatingPlansStreamProvider(widget.classId));
    final studentsAsync = ref.watch(studentsStreamProvider((classId: widget.classId, search: null)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.seatingPlan),
        actions: [
          IconButton(
            tooltip: l10n.newSeatingPlan,
            icon: const Icon(Icons.add),
            onPressed: () {
              final students = studentsAsync.value ?? [];
              _showNewPlanDialog(context, students);
            },
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('لا يوجد مخطط جلوس بعد لهذا القسم', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newSeatingPlan),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () {
                      final students = studentsAsync.value ?? [];
                      _showNewPlanDialog(context, students);
                    },
                  ),
                ],
              ),
            );
          }

          final activePlanId = _selectedPlanId ?? plans.first.id;
          final planMembersAsync = ref.watch(seatingPlanMembersProvider(activePlanId));
          final studentMap = {for (final s in (studentsAsync.value ?? <StudentItem>[])) s.id: s};

          return Column(
            children: [
              // Plan selector bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    const Icon(Icons.layers, size: 20, color: AppColors.brand),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: activePlanId,
                        underline: const SizedBox(),
                        items: plans
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name} (${p.layout})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPlanId = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Teacher desk marker
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: AppRadius.control,
                    border: Border.all(color: AppColors.brand),
                  ),
                  child: const Center(
                    child: Text('منصة الأستاذ / السبورة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand)),
                  ),
                ),
              ),

              // Seating grid representation
              Expanded(
                child: planMembersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (members) {
                    if (members.isEmpty) {
                      return const Center(child: Text('المخطط فارغ. لم يتم توزيع المقاعد بعد.'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final m = members[index];
                        final s = m.studentId != null ? studentMap[m.studentId] : null;

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.control,
                            side: BorderSide(
                              color: s != null ? AppColors.brand : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  s != null ? Icons.person : Icons.event_seat,
                                  size: 20,
                                  color: s != null ? AppColors.brand : AppColors.textSecondary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s != null ? '${s.firstName}\n${s.lastName}' : 'مقعد شاغر',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: s != null ? FontWeight.bold : FontWeight.normal,
                                    color: s != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

final seatingPlanMembersProvider = StreamProvider.family<List<SeatingPlanMember>, String>((ref, planId) {
  return ref.watch(organizationRepositoryProvider).watchPlanMembers(planId);
});
