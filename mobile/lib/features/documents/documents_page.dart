import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String? _selectedFolderId;
  String? _selectedFolderName;

  void _showNewFolderDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.newFolder),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'اسم المجلد',
              border: OutlineInputBorder(borderRadius: AppRadius.control),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ref.read(documentsRepositoryProvider).createFolder(
                      name: nameCtrl.text.trim(),
                      parentId: _selectedFolderId,
                    );
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _showAddDocumentDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    String mimeType = 'application/pdf';

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
                    l10n.newDocument,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم الملف أو الوثيقة',
                      hintText: 'مثال: ملخص_الوحدة_الأولى.pdf',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: mimeType,
                    decoration: InputDecoration(
                      labelText: 'نوع الملف',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'application/pdf', child: Text('📄 مستند PDF')),
                      DropdownMenuItem(value: 'application/msword', child: Text('📝 مستند Word (DOCX)')),
                      DropdownMenuItem(value: 'image/jpeg', child: Text('🖼️ صورة أو مخطط')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => mimeType = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final fileName = nameCtrl.text.trim();
                      final key = 'local_docs/${DateTime.now().millisecondsSinceEpoch}_$fileName';

                      await ref.read(documentsRepositoryProvider).createDocument(
                            folderId: _selectedFolderId,
                            fileName: fileName,
                            mimeType: mimeType,
                            sizeBytes: 524288, // 512 KB simulation
                            storageKey: key,
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

  IconData _fileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('text')) return Icons.description;
    if (mimeType.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _fileColor(String mimeType) {
    if (mimeType.contains('pdf')) return Colors.red.shade700;
    if (mimeType.contains('word')) return Colors.blue.shade700;
    if (mimeType.contains('image')) return Colors.teal;
    return AppColors.brand;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foldersAsync = ref.watch(documentFoldersProvider);
    final documentsAsync = ref.watch(documentsStreamProvider(_selectedFolderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedFolderName ?? l10n.documentsTitle),
        leading: _selectedFolderId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedFolderId = null;
                    _selectedFolderName = null;
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            tooltip: l10n.newFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showNewFolderDialog(context),
          ),
          IconButton(
            tooltip: l10n.newDocument,
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showAddDocumentDialog(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Folders Section (Only at root level)
          if (_selectedFolderId == null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: Text(
                  'المجلدات',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            foldersAsync.when(
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
              data: (folders) {
                if (folders.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                      child: Text('لا توجد مجلدات بعد. يمكنك إنشاء مجلد لتنظيم ملفاتك.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final f = folders[index];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFolderId = f.id;
                              _selectedFolderName = f.name;
                            });
                          },
                          borderRadius: AppRadius.control,
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brandSoft.withValues(alpha: 0.3),
                              borderRadius: AppRadius.control,
                              border: Border.all(color: AppColors.brandSoft),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder, color: AppColors.brand, size: 32),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],

          // Files Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    _selectedFolderId != null ? 'الملفات داخل هذا المجلد' : l10n.allFiles,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.newDocument),
                    onPressed: () => _showAddDocumentDialog(context),
                  ),
                ],
              ),
            ),
          ),

          documentsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
            data: (docs) {
              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open, size: 54, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          const Text('لا توجد مستندات بعد في هذا الموقع', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: Text(l10n.newDocument),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                            onPressed: () => _showAddDocumentDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final d = docs[index];
                    final sizeKb = (d.sizeBytes / 1024).toStringAsFixed(1);
                    final icon = _fileIcon(d.mimeType);
                    final color = _fileColor(d.mimeType);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(d.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$sizeKb KB · محفوظ محلياً للعمل دون إنترنت'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('حذف المستند'),
                                  content: Text('هل أنت متأكد من حذف "${d.fileName}"؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(documentsRepositoryProvider).deleteDocument(d.id);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
