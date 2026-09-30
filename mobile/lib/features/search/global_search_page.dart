import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import '../../data/repositories/search_repository.dart';

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _searchController = TextEditingController();
  List<LocalSearchResult> _results = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final results = await ref.read(searchRepositoryProvider).search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'class':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'lesson':
        return Icons.menu_book;
      case 'document':
        return Icons.insert_drive_file;
      case 'task':
        return Icons.check_circle_outline;
      default:
        return Icons.search;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'class':
        return AppColors.brand;
      case 'student':
        return AppColors.secondary;
      case 'lesson':
        return AppColors.accent;
      case 'document':
        return Colors.orange.shade700;
      case 'task':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'class':
        return 'قسم';
      case 'student':
        return 'طالب';
      case 'lesson':
        return 'درس';
      case 'document':
        return 'مستند';
      case 'task':
        return 'مهمة';
      default:
        return '';
    }
  }

  void _onItemTapped(LocalSearchResult item) {
    switch (item.type) {
      case 'class':
        context.push('/classes/${item.id}');
        break;
      case 'student':
        // Navigates to classes or student detail
        context.push('/classes');
        break;
      case 'lesson':
        context.push('/lessons/${item.id}/edit');
        break;
      case 'document':
        context.push('/documents');
        break;
      case 'task':
        context.push('/planner');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ابحث عن قسم، طالب، درس، مستند أو مهمة...',
            border: InputBorder.none,
            hintStyle: const TextStyle(fontSize: 14),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: _performSearch,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchController.text.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.globalSearch, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'بحث شامل فوري في كافة بيانات التطبيق دون اتصال',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد نتائج تطابق "${_searchController.text}"',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        final color = _typeColor(r.type);
                        final icon = _typeIcon(r.type);
                        final label = _typeLabel(r.type);

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: r.subtitle != null ? Text(r.subtitle!) : null,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onTap: () => _onItemTapped(r),
                          ),
                        );
                      },
                    ),
    );
  }
}
