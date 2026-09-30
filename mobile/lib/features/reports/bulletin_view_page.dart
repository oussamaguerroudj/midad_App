import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/services/report_generator_service.dart';

class BulletinViewPage extends ConsumerStatefulWidget {
  const BulletinViewPage({
    super.key,
    required this.classId,
    required this.studentId,
    this.term = 'الفصل الأول',
  });

  final String classId;
  final String studentId;
  final String term;

  @override
  ConsumerState<BulletinViewPage> createState() => _BulletinViewPageState();
}

class _BulletinViewPageState extends ConsumerState<BulletinViewPage> {
  late Future<StudentBulletinData> _bulletinFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bulletinFuture = ref.read(reportGeneratorServiceProvider).generateStudentBulletin(
          classId: widget.classId,
          studentId: widget.studentId,
          term: widget.term,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف النقاط الرسمي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'نسخ ملخص الكشف',
            onPressed: () async {
              final b = await _bulletinFuture;
              Clipboard.setData(ClipboardData(
                text: 'كشف نقاط ${b.studentName} (${b.className}): المعدل ${b.generalAverage}/20 - الرتبة ${b.rankInClass}/${b.totalStudentsInClass}',
              ));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ ملخص كشف النقاط.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة أو تصدير PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('كشف النقاط جاهز للطباعة أو الإرسال.')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<StudentBulletinData>(
        future: _bulletinFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          final b = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Official Header
                    Center(
                      child: Column(
                        children: [
                          Text(
                            b.schoolName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'كشف النقاط الفصلي — تقييم التعلمات',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brand),
                          ),
                          Text(
                            '${b.term}  •  الموسم الدراسي: ${b.academicYear}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 28),

                    // Student Meta Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'التلميذ(ة): ${b.studentName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (b.registrationNumber != null)
                              Text('رقم التسجيل: ${b.registrationNumber}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'القسم: ${b.className}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'الرتبة: ${b.rankInClass} / ${b.totalStudentsInClass}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Table
                    if (b.grades.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text('لا توجد تقييمات مسجلة بعد.', textAlign: TextAlign.center),
                      )
                    else
                      Table(
                        border: TableBorder.all(color: AppColors.lightBorder),
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(1.5),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            children: const [
                              Padding(padding: EdgeInsets.all(6), child: Text('التقييم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('العلامة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('المعامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('الجداء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          ...b.grades.map((g) => TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(g.title, style: const TextStyle(fontSize: 12))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(g.kind, style: const TextStyle(fontSize: 12))),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text('${g.normalized20}/20', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${g.coefficient}', style: const TextStyle(fontSize: 12))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${g.weightedPoints}', style: const TextStyle(fontSize: 12))),
                                ],
                              )),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),

                    // Averages Summary Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                      ),

                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric('المعدل العام', '${b.generalAverage}/20', isPrimary: true),
                              _buildMetric('مجموع المعاملات', '${b.totalCoefficient}'),
                              _buildMetric('مجموع النقاط', '${b.totalWeightedPoints}'),
                              _buildMetric('التقدير', b.honorRoll, color: AppColors.brand),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('أعلى معدل: ${b.classHighestAverage}', style: const TextStyle(fontSize: 11)),
                              Text('أدنى معدل: ${b.classLowestAverage}', style: const TextStyle(fontSize: 11)),
                              Text('معدل القسم: ${b.classOverallAverage}', style: const TextStyle(fontSize: 11)),
                              Text('الغيابات: ${b.absentCount}', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Observations & Signatures
                    Text(
                      'ملاحظة الأستاذ(ة): ${b.teacherAppreciation}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 32),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('توقيع الأستاذ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('تأشيرة الإدارة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('توقيع الولي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value, {bool isPrimary = false, Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isPrimary ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isPrimary ? AppColors.brand : AppColors.textPrimary),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
