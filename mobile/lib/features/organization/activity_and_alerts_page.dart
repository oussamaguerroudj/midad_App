import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/local/app_database.dart';
import '../../data/providers.dart';

class ActivityAndAlertsPage extends ConsumerWidget {
  const ActivityAndAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.followUpAlerts),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.notifications_active_outlined),
                text: l10n.followUpAlerts,
              ),
              Tab(
                icon: const Icon(Icons.history_outlined),
                text: l10n.activityHistory,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FollowUpAlertsTab(),
            _ActivityHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _FollowUpAlertsTab extends ConsumerWidget {
  const _FollowUpAlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(followUpAlertsProvider);

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 64, color: AppColors.success),
                SizedBox(height: AppSpacing.sm),
                Text('الوضع ممتاز! لا توجد تنبيهات متابعة حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('كافة الطلاب في مسار سليم من حيث الحضور والتحصيل', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final a = alerts[index];
            final isDanger = a.severity == 'danger';
            final color = isDanger ? AppColors.danger : AppColors.warning;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.card,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        a.ruleType == 'attendance' ? Icons.warning_amber_rounded : Icons.trending_down,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                a.studentName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  a.ruleType == 'attendance' ? 'غياب متكرر' : 'تراجع تحصيلي',
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.message,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityHistoryTab extends ConsumerWidget {
  const _ActivityHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final historyStream = (db.select(db.auditEntries)
          ..orderBy([(t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)]))
        .watch();

    return StreamBuilder<List<AuditEntry>>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snapshot.data!;

        if (entries.isEmpty) {
          return const Center(
            child: Text('لا توجد سجلات نشاط مسجلة بعد', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            final dateStr = '${e.occurredAt.hour.toString().padLeft(2, '0')}:${e.occurredAt.minute.toString().padLeft(2, '0')} · ${e.occurredAt.year}-${e.occurredAt.month.toString().padLeft(2, '0')}-${e.occurredAt.day.toString().padLeft(2, '0')}';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.brandSoft,
                  child: Icon(
                    e.action == 'CREATE'
                        ? Icons.add_circle_outline
                        : e.action == 'UPDATE'
                            ? Icons.edit_outlined
                            : Icons.delete_outline,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                title: Text('${e.action} ${e.entityType}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            );
          },
        );
      },
    );
  }
}
