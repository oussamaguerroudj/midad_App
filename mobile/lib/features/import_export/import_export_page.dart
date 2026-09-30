import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/services/import_export_service.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedClassId;

  // Import Tab State
  final _csvController = TextEditingController();
  List<ParsedRosterStudent> _parsedRows = [];
  bool _isImporting = false;

  // Export Tab State
  String _exportPreview = '';
  String _currentExportType = 'roster'; // 'roster' | 'grades'
  bool _isExporting = false;

  final String _sampleCsv = '''رقم_التسجيل,اللقب,الاسم
2026-001,بن علي,سارة
2026-002,قاسمي,أحمد
2026-003,منصوري,فاطمة
2026-004,رحماني,يوسف
2026-005,بلقاسم,إيمان''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedClassId = widget.initialClassId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initClass());
  }

  Future<void> _initClass() async {
    if (_selectedClassId == null) {
      final classes = await ref.read(classesRepositoryProvider).watchClasses().first;
      if (classes.isNotEmpty && mounted) {
        setState(() => _selectedClassId = classes.first.id);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  void _onCsvChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _parsedRows = []);
      return;
    }
    final service = ref.read(importExportServiceProvider);
    final rows = service.parseCsvRoster(text);
    setState(() => _parsedRows = rows);
  }

  Future<void> _performImport() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد قسم أولاً.')));
      return;
    }
    if (_parsedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات صالحة للاستيراد.')));
      return;
    }

    setState(() => _isImporting = true);
    final service = ref.read(importExportServiceProvider);

    try {
      final result = await service.importRoster(
        classId: _selectedClassId!,
        students: _parsedRows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('تم استيراد ${result.totalCreated} تلميذ بنجاح! (تم تخطي ${result.totalSkipped})'),
          ),
        );
        setState(() {
          _csvController.clear();
          _parsedRows = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستيراد: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _performExport(String type) async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد قسم أولاً.')));
      return;
    }

    setState(() {
      _isExporting = true;
      _currentExportType = type;
    });

    final service = ref.read(importExportServiceProvider);
    try {
      String csv = '';
      if (type == 'roster') {
        csv = await service.exportStudentsRosterCsv(_selectedClassId!);
      } else {
        csv = await service.exportGradebookMatrixCsv(_selectedClassId!);
      }
      if (mounted) setState(() => _exportPreview = csv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد وتصدير البيانات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.file_upload), text: 'استيراد التلاميذ (CSV)'),
            Tab(icon: Icon(Icons.file_download), text: 'تصدير التقارير (CSV)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Class Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            color: Colors.grey.shade100,
            child: classesAsync.when(
              data: (classes) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'القسم المستهدف',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: _selectedClassId,
                items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedClassId = val;
                    _exportPreview = '';
                  });

                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImportTab(),
                _buildExportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('بيانات التلاميذ بتنسيق CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton.icon(
                      icon: const Icon(Icons.paste, size: 16),
                      label: const Text('إدراج نموذج تجريبي'),
                      onPressed: () {
                        _csvController.text = _sampleCsv;
                        _onCsvChanged(_sampleCsv);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'التنسيق المدعوم: رقم_التسجيل,اللقب,الاسم (مفصولة بفواصل أو فواصل منقوطة)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _csvController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'الصق أسطر CSV هنا...\n2026-001,بن علي,سارة\n2026-002,قاسمي,أحمد',
                    border: OutlineInputBorder(borderRadius: AppRadius.card),
                  ),
                  onChanged: _onCsvChanged,
                ),
                const SizedBox(height: AppSpacing.md),

                // Live Parsed Preview
                if (_parsedRows.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'معاينة البيانات المستخرجة (${_parsedRows.length} تلميذ):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Text('${_parsedRows.length} سطر جاهز',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _parsedRows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final r = _parsedRows[idx];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.brandSoft,
                            child: Text('${idx + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.brand)),
                          ),
                          title: Text('${r.firstName} ${r.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(r.registrationNumber ?? '-', style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Import Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isImporting ? 'جاري الاستيراد...' : 'استيراد التلاميذ إلى القسم الآن'),
                  onPressed: _isImporting || _parsedRows.isEmpty ? null : _performImport,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Export Action Buttons Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اختر نوع التقرير للتصدير بتنسيق Excel / CSV:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.people),
                        label: const Text('قائمة التلاميذ والغيابات'),
                        onPressed: () => _performExport('roster'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.grid_on),
                        label: const Text('جدول النقاط الإجمالي'),
                        onPressed: () => _performExport('grades'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Export Result & Preview
        if (_isExporting)
          const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
        else if (_exportPreview.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentExportType == 'roster' ? 'معاينة ملف قائمة التلاميذ' : 'معاينة ملف جدول النقاط',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.white,
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('نسخ البيانات'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _exportPreview));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ محتوى CSV إلى الحافظة بنجاح.')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Text(
                        _exportPreview,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
