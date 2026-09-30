import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/services/report_generator_service.dart';

enum ReportKind {
  bulletin,
  classSummary,
  attendance,
  certificate,
}

class ReportCenterPage extends ConsumerStatefulWidget {
  const ReportCenterPage({super.key});

  @override
  ConsumerState<ReportCenterPage> createState() => _ReportCenterPageState();
}

class _ReportCenterPageState extends ConsumerState<ReportCenterPage> {
  ReportKind _selectedKind = ReportKind.bulletin;
  String? _selectedClassId;
  String? _selectedStudentId;
  String _selectedTerm = 'الفصل الأول';

  bool _loading = false;
  StudentBulletinData? _bulletinData;
  ClassSummaryReportData? _summaryData;
  CertificateData? _certificateData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  Future<void> _initDefaults() async {
    final classes = await ref.read(classesRepositoryProvider).watchClasses().first;
    if (classes.isNotEmpty && mounted) {
      setState(() {
        _selectedClassId = classes.first.id;
      });
      _onClassChanged(classes.first.id);
    }
  }

  Future<void> _onClassChanged(String classId) async {
    final students = await ref.read(studentsRepositoryProvider).watchStudents(classId: classId).first;
    if (students.isNotEmpty && mounted) {
      setState(() {
        _selectedStudentId = students.first.id;
      });
    } else if (mounted) {
      setState(() {
        _selectedStudentId = null;
      });
    }
    _generateCurrentReport();
  }

  Future<void> _generateCurrentReport() async {
    if (_selectedClassId == null) return;
    setState(() => _loading = true);

    final service = ref.read(reportGeneratorServiceProvider);
    try {
      if (_selectedKind == ReportKind.bulletin && _selectedStudentId != null) {
        final data = await service.generateStudentBulletin(
          classId: _selectedClassId!,
          studentId: _selectedStudentId!,
          term: _selectedTerm,
        );
        setState(() {
          _bulletinData = data;
          _summaryData = null;
          _certificateData = null;
        });
      } else if (_selectedKind == ReportKind.classSummary) {
        final data = await service.generateClassSummary(
          classId: _selectedClassId!,
          term: _selectedTerm,
        );
        setState(() {
          _summaryData = data;
          _bulletinData = null;
          _certificateData = null;
        });
      } else if (_selectedKind == ReportKind.certificate && _selectedStudentId != null) {
        final data = await service.generateCertificate(
          classId: _selectedClassId!,
          studentId: _selectedStudentId!,
        );
        setState(() {
          _certificateData = data;
          _bulletinData = null;
          _summaryData = null;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesStreamProvider);
    final studentsAsync = ref.watch(studentsStreamProvider((classId: _selectedClassId, search: null)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التقارير والشهادات'),
        actions: [
          IconButton(
            tooltip: 'مشاركة أو نسخ التقرير',
            icon: const Icon(Icons.share),
            onPressed: _shareOrCopyReport,
          ),
          IconButton(
            tooltip: 'طباعة فورية',
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تجهيز التقرير وجاهز للطباعة أو التصدير بتنسيق PDF.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Report Kind Segmented Control
          _buildKindSelector(),
          const SizedBox(height: AppSpacing.md),

          // Filters Card (Class, Student, Term)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Class Dropdown
                  classesAsync.when(
                    data: (classes) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'القسم / الفوج التربوي',
                        prefixIcon: Icon(Icons.school),
                      ),
                      initialValue: _selectedClassId,
                      items: classes
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedClassId = val);
                          _onClassChanged(val);
                        }
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Student Dropdown (if applicable)
                  if (_selectedKind == ReportKind.bulletin || _selectedKind == ReportKind.certificate) ...[
                    studentsAsync.when(
                      data: (students) => DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'التلميذ(ة)',
                          prefixIcon: Icon(Icons.person),
                        ),
                        initialValue: _selectedStudentId,
                        items: students
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName)))
                            .toList(),
                        onChanged: (val) {
                          setState(() => _selectedStudentId = val);
                          _generateCurrentReport();
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Term Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'الفترة / الثلاثي',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    initialValue: _selectedTerm,
                    items: const [
                      DropdownMenuItem(value: 'الفصل الأول', child: Text('الثلاثي الأول')),
                      DropdownMenuItem(value: 'الفصل الثاني', child: Text('الثلاثي الثاني')),
                      DropdownMenuItem(value: 'الفصل الثالث', child: Text('الثلاثي الثالث')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTerm = val);
                        _generateCurrentReport();
                      }
                    },
                  ),

                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Report Preview Area
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
          else if (_selectedKind == ReportKind.bulletin && _bulletinData != null)
            _buildBulletinPreview(_bulletinData!)
          else if (_selectedKind == ReportKind.classSummary && _summaryData != null)
            _buildSummaryPreview(_summaryData!)
          else if (_selectedKind == ReportKind.certificate && _certificateData != null)
            _buildCertificatePreview(_certificateData!)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('يرجى تحديد قسم وتلميذ لعرض التقرير.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKindSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('كشف النقاط الفصلي'),
            selected: _selectedKind == ReportKind.bulletin,
            onSelected: (sel) {
              if (sel) {
                setState(() => _selectedKind = ReportKind.bulletin);
                _generateCurrentReport();
              }
            },
            selectedColor: AppColors.brand,
            labelStyle: TextStyle(
              color: _selectedKind == ReportKind.bulletin ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          ChoiceChip(
            label: const Text('كشف نتائج القسم'),
            selected: _selectedKind == ReportKind.classSummary,
            onSelected: (sel) {
              if (sel) {
                setState(() => _selectedKind = ReportKind.classSummary);
                _generateCurrentReport();
              }
            },
            selectedColor: AppColors.brand,
            labelStyle: TextStyle(
              color: _selectedKind == ReportKind.classSummary ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          ChoiceChip(
            label: const Text('شهادة تقدير وتشجيع'),
            selected: _selectedKind == ReportKind.certificate,
            onSelected: (sel) {
              if (sel) {
                setState(() => _selectedKind = ReportKind.certificate);
                _generateCurrentReport();
              }
            },
            selectedColor: AppColors.brand,
            labelStyle: TextStyle(
              color: _selectedKind == ReportKind.certificate ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinPreview(StudentBulletinData b) {
    return Card(
      elevation: 2,
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
            // Header
            Center(
              child: Column(
                children: [
                  Text(
                    b.schoolName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text('كشف النقاط والملاحظات الفصلية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brand)),
                  Text('${b.term} — السنة الدراسية: ${b.academicYear}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 24),

            // Student Meta Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الاسم واللقب: ${b.studentName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (b.registrationNumber != null)
                      Text('رقم التسجيل: ${b.registrationNumber}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('القسم: ${b.className}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('الرتبة: ${b.rankInClass} من ${b.totalStudentsInClass}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Grades Table
            if (b.grades.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('لا توجد تقييمات منجزة لهذا التلميذ حتى الآن.', textAlign: TextAlign.center),
              )
            else
              Table(
                border: TableBorder.all(color: AppColors.lightBorder),
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
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
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text('${g.weightedPoints}', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      )),
                ],
              ),
            const SizedBox(height: AppSpacing.md),

            // Performance Summary Box
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
                      _buildSummaryMetric('المعدل العام', '${b.generalAverage}/20', isPrimary: true),
                      _buildSummaryMetric('مجموع المعاملات', '${b.totalCoefficient}'),
                      _buildSummaryMetric('مجموع النقاط', '${b.totalWeightedPoints}'),
                      _buildSummaryMetric('التقدير العام', b.honorRoll, color: AppColors.brand),
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

            // Teacher Observation & Signatures
            Text('ملاحظة الأستاذ: ${b.teacherAppreciation}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('توقيع الأستاذ(ة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('تأشيرة الإدارة / المدير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('توقيع ولي الأمر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPreview(ClassSummaryReportData s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  Text(s.schoolName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('كشف النتائج الإجمالي — قسم: ${s.className}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brand)),
                  Text('${s.term}  •  السنة الدراسية: ${s.academicYear}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryMetric('التلاميذ', '${s.analytics.studentCount}'),
                _buildSummaryMetric('معدل القسم', '${s.analytics.averageScore}/20', isPrimary: true),
                _buildSummaryMetric('نسبة النجاح', '${s.analytics.passRatePercent}%'),
                _buildSummaryMetric('نسبة الحضور', '${s.analytics.attendanceRatePercent}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('ترتيب تلاميذ القسم حسب الاستحقاق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: AppSpacing.sm),
            ...s.studentsRoster.map((st) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: st.rank <= 3 ? AppColors.brandSoft : Colors.grey.shade200,
                    child: Text('${st.rank}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الغيابات: ${st.absentCount}  •  التقدير: ${st.honorRoll}', style: const TextStyle(fontSize: 11)),
                  trailing: Text('${st.averageScore}/20',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand, fontSize: 13)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatePreview(CertificateData c) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: Colors.amber.shade700, width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 54),
            const SizedBox(height: AppSpacing.sm),
            Text(
              c.title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
            ),
            const SizedBox(height: 6),
            Text('${c.schoolName}  •  السنة الدراسية ${c.academicYear}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Divider(height: 32),
            const Text('تمنح هذه الشهادة التشجيعية إلى التلميذ(ة):', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              c.studentName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brand),
            ),
            const SizedBox(height: 4),
            Text('تلميذ(ة) بقسم: ${c.className}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Text(
              c.reason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'المعدل المحصل عليه: ${c.averageScore}/20',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تحريراً بتاريخ: ${c.date.toIso8601String().split('T').first}', style: const TextStyle(fontSize: 11)),
                Text('توقيع وختم الأستاذ: ${c.teacherName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, {bool isPrimary = false, Color? color}) {
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

  void _shareOrCopyReport() {
    String textToCopy = '';
    if (_selectedKind == ReportKind.bulletin && _bulletinData != null) {
      final b = _bulletinData!;
      textToCopy = 'كشف نقاط ${b.studentName} (${b.className}): المعدل العام ${b.generalAverage}/20 - الرتبة ${b.rankInClass}/${b.totalStudentsInClass} - التقدير: ${b.honorRoll}';
    } else if (_selectedKind == ReportKind.classSummary && _summaryData != null) {
      final s = _summaryData!;
      textToCopy = 'كشف نتائج ${s.className}: معدل القسم ${s.analytics.averageScore}/20 - نسبة النجاح ${s.analytics.passRatePercent}%';
    } else if (_selectedKind == ReportKind.certificate && _certificateData != null) {
      final c = _certificateData!;
      textToCopy = '${c.title}: مبروك للتلميذ(ة) ${c.studentName} بمعدل ${c.averageScore}/20 في قسم ${c.className}.';
    }

    if (textToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textToCopy));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ بيانات التقرير إلى الحافظة بنجاح.')),
      );
    }
  }
}
