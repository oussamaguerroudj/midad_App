import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/local/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/students_repository.dart';

class StudentGroupsPage extends ConsumerWidget {
  const StudentGroupsPage({required this.classId, super.key});
  final String classId;

  void _showNewGroupDialog(BuildContext context, WidgetRef ref, List<StudentItem> students) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final selectedStudents = <String>{};

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
                    l10n.newGroup,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم الفوج / المجموعة',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('اختر أعضاء الفوج من طلاب القسم:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final isSelected = selectedStudents.contains(s.id);
                        return CheckboxListTile(
                          dense: true,
                          value: isSelected,
                          title: Text('${s.firstName} ${s.lastName}'),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedStudents.add(s.id);
                              } else {
                                selectedStudents.remove(s.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await ref.read(organizationRepositoryProvider).createGroup(
                            classId: classId,
                            name: nameCtrl.text.trim(),
                            studentIds: selectedStudents.toList(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(studentGroupsStreamProvider(classId));
    final studentsAsync = ref.watch(studentsStreamProvider((classId: classId, search: null)));
    final students = studentsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studentGroups),
        actions: [
          IconButton(
            tooltip: l10n.newGroup,
            icon: const Icon(Icons.group_add),
            onPressed: () => _showNewGroupDialog(context, ref, students),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('لم يتم إنشاء أفواج أو مجموعات لهذا القسم بعد', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newGroup),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () => _showNewGroupDialog(context, ref, students),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              return _GroupCard(group: g, students: students);
            },
          );
        },
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.students});
  final StudentGroup group;
  final List<StudentItem> students;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(group.id));
    final studentMap = {for (final s in students) s.id: s};

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.brandSoft,
                  child: Icon(Icons.group, color: AppColors.brand),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            membersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString()),
              data: (members) {
                if (members.isEmpty) {
                  return const Text('لا يوجد طلاب في هذا الفوج', style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: members.map((m) {
                    final s = studentMap[m.studentId];
                    return Chip(
                      avatar: const Icon(Icons.person, size: 16, color: AppColors.brand),
                      label: Text(s != null ? '${s.firstName} ${s.lastName}' : 'طالب'),
                      backgroundColor: AppColors.lightBackground,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  return ref.watch(organizationRepositoryProvider).watchGroupMembers(groupId);
});
