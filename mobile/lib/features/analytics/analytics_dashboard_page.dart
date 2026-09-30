import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/classes_repository.dart';


class AnalyticsDashboardPage extends ConsumerStatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  ConsumerState<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends ConsumerState<AnalyticsDashboardPage> {
  String? _selectedClassId; // null = Global Overview

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAnalytics),
        actions: [
          IconButton(
            tooltip: 'مركز التقارير والكشوفات',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            tooltip: 'استيراد وتصدير البيانات',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => context.push('/import-export'),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ: $err')),
        data: (classes) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(overviewAnalyticsProvider);
              if (_selectedClassId != null) {
                ref.invalidate(classAnalyticsProvider(_selectedClassId!));
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Quick navigation to Report Center & Import/Export
                _buildActionBanner(context),
                const SizedBox(height: AppSpacing.md),

                // Class Selector Tabs/Chips
                _buildClassSelector(classes),
                const SizedBox(height: AppSpacing.md),

                // Content: Either Overview or Class-specific Analytics
                if (_selectedClassId == null)
                  _buildGlobalOverview(context)
                else
                  _buildClassAnalytics(context, _selectedClassId!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandSoft.withValues(alpha: 0.5),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),

      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.brand,
            child: Icon(Icons.assessment, color: AppColors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مركز التحليلات والتقارير الرسمية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'استخراج كشوف النقاط، شهادات التقدير، وتصدير الرقمنة',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),


          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
            ),
            icon: const Icon(Icons.description, size: 16),
            label: const Text('التقارير'),
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector(List<ClassWithSubject> classes) {

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('نظرة عامة شاملة'),
            selected: _selectedClassId == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedClassId = null);
            },
            selectedColor: AppColors.brand,
            labelStyle: TextStyle(
              color: _selectedClassId == null ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ...classes.map((c) {
            final isSelected = _selectedClassId == c.id;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(c.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedClassId = selected ? c.id : null);
                },
                selectedColor: AppColors.brand,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGlobalOverview(BuildContext context) {
    final overviewAsync = ref.watch(overviewAnalyticsProvider);

    return overviewAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('خطأ في تحميل التحليلات: $err')),
      data: (ov) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'نسبة الحضور العامة',
                    value: '${ov.overallAttendanceRate}%',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    subtitle: '${ov.totalSessions} حصة مسجلة',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricCard(
                    title: 'المعدل العام للمادة',
                    value: '${ov.overallAverageScore}/20',
                    icon: Icons.trending_up,
                    color: AppColors.secondary,
                    subtitle: '${ov.totalAssessments} تقييم منجز',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'تلاميذ تحت المتابعة',
                    value: '${ov.totalAtRisk}',
                    icon: Icons.warning_amber_rounded,
                    color: ov.totalAtRisk > 0 ? AppColors.danger : AppColors.success,
                    subtitle: 'غياب متكرر أو تعثر دراسي',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricCard(
                    title: 'إجمالي التلاميذ',
                    value: '${ov.totalStudents}',
                    icon: Icons.people_outline,
                    color: AppColors.brand,
                    subtitle: 'موزعون على ${ov.totalClasses} أقسام',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Class comparison list
            const Text(
              'مقارنة أداء الأفواج والأقسام',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (ov.classes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('لا توجد أقسام مسجلة حالياً.', textAlign: TextAlign.center),
                ),
              )
            else
              ...ov.classes.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brandSoft,
                        child: Text(
                          c.averageScore.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand, fontSize: 13),
                        ),
                      ),
                      title: Text(c.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${c.studentCount} تلميذ  •  حضور ${c.attendanceRatePercent}%  •  ${c.atRiskCount} بحاجة لمتابعة',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        setState(() => _selectedClassId = c.classId);
                      },
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildClassAnalytics(BuildContext context, String classId) {
    final classAsync = ref.watch(classAnalyticsProvider(classId));

    return classAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('خطأ: $err')),
      data: (ca) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Class Highlights
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('المعدل العام', '${ca.averageScore}/20', AppColors.brand),
                        _buildStatColumn('نسبة النجاح', '${ca.passRatePercent}%', AppColors.success),
                        _buildStatColumn('نسبة الحضور', '${ca.attendanceRatePercent}%', AppColors.secondary),
                        _buildStatColumn('أعلى معدل', '${ca.maxScore}/20', AppColors.accent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Grade Distribution (مخطط توزيع العلامات)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التوزيع الإحصائي للعلامات والمعدلات',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...ca.buckets.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${b.count} تلميذ (${b.percentage}%)',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: b.percentage / 100.0,
                                backgroundColor: AppColors.lightBorder,
                                color: _getBucketColor(b.key),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Top Students (لوحة الشرف)
            if (ca.topStudents.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'لوحة الشرف للمتفوقين',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brand),
                          ),
                          TextButton(
                            onPressed: () => context.push('/reports'),
                            child: const Text('طباعة الشهادات'),
                          ),
                        ],
                      ),
                      ...ca.topStudents.take(5).map((s) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: s.rank == 1
                                  ? Colors.amber.shade100
                                  : (s.rank == 2 ? Colors.blueGrey.shade100 : Colors.brown.shade100),
                              child: Text(
                                '#${s.rank ?? "-"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${s.averageScore}/20',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                              ),
                            ),
                            onTap: () {
                              context.push('/reports/bulletin/$classId/${s.studentId}');
                            },
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // At-Risk Watchlist (المتابعة والإنذار المبكر)
            if (ca.atRiskStudents.isNotEmpty) ...[
              Card(
                color: Colors.red.shade50.withValues(alpha: 0.5),
                child: Padding(

                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: AppColors.danger, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'قائمة المتابعة والتدخل البيداغوجي',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.danger),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Text(
                        'تلاميذ يقل معدلهم عن 10/20 أو لديهم 3 غيابات فأكثر.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...ca.atRiskStudents.map((ar) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ar.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(ar.reason, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.receipt_long, size: 20),
                                  tooltip: 'كشف النقاط',
                                  onPressed: () {
                                    context.push('/reports/bulletin/$classId/${ar.studentId}');
                                  },
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Assessment Timeline
            if (ca.assessmentTrends.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تطور معدلات الفروض والاختبارات',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...ca.assessmentTrends.map((t) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('النوع: ${t.kind}  •  العلامة القصوى: ${t.maxScore.toInt()}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: t.averageScore >= 10 ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: t.averageScore >= 10 ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              child: Text(
                                'المعدل: ${t.averageScore}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.averageScore >= 10 ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _getBucketColor(String key) {
    switch (key) {
      case 'excellent':
        return Colors.green.shade700;
      case 'very_good':
        return Colors.teal;
      case 'good':
        return Colors.blue;
      case 'average':
        return Colors.amber.shade700;
      default:
        return AppColors.danger;
    }
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
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
                    title,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
