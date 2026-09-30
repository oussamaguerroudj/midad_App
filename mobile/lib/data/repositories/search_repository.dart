import '../local/app_database.dart';

class LocalSearchResult {
  const LocalSearchResult({
    required this.id,
    required this.type, // class | student | lesson | document | task
    required this.title,
    this.subtitle,
  });

  final String id;
  final String type;
  final String title;
  final String? subtitle;
}

class SearchRepository {
  SearchRepository(this._db);
  final AppDatabase _db;

  Future<List<LocalSearchResult>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final results = <LocalSearchResult>[];

    // 1. Classes
    final classes = await (_db.select(_db.classes)..where((t) => t.deletedAt.isNull())).get();
    for (final c in classes) {
      if (c.name.toLowerCase().contains(q) || (c.level != null && c.level!.toLowerCase().contains(q))) {
        results.add(LocalSearchResult(id: c.id, type: 'class', title: c.name, subtitle: c.level ?? 'قسم'));
      }
    }

    // 2. Students
    final students = await (_db.select(_db.students)..where((t) => t.deletedAt.isNull())).get();
    for (final s in students) {
      final fullName = '${s.firstName} ${s.lastName}'.toLowerCase();
      if (fullName.contains(q) || (s.externalRef != null && s.externalRef!.toLowerCase().contains(q))) {
        results.add(LocalSearchResult(
          id: s.id,
          type: 'student',
          title: '${s.firstName} ${s.lastName}',
          subtitle: s.externalRef ?? 'تلميذ',
        ));
      }
    }

    // 3. Lessons
    final lessons = await (_db.select(_db.lessons)..where((t) => t.deletedAt.isNull())).get();
    for (final l in lessons) {
      if (l.topic.toLowerCase().contains(q) || (l.objectives != null && l.objectives!.toLowerCase().contains(q))) {
        results.add(LocalSearchResult(id: l.id, type: 'lesson', title: l.topic, subtitle: 'مذكرة تحضير'));
      }
    }

    // 4. Documents
    final docs = await (_db.select(_db.documents)..where((t) => t.deletedAt.isNull())).get();
    for (final d in docs) {
      if (d.fileName.toLowerCase().contains(q)) {
        results.add(LocalSearchResult(
          id: d.id,
          type: 'document',
          title: d.fileName,
          subtitle: '${(d.sizeBytes / 1024).toStringAsFixed(1)} KB',
        ));
      }
    }

    // 5. Tasks
    final tasks = await (_db.select(_db.tasks)..where((t) => t.deletedAt.isNull())).get();
    for (final t in tasks) {
      if (t.title.toLowerCase().contains(q)) {
        results.add(LocalSearchResult(id: t.id, type: 'task', title: t.title, subtitle: 'مهمة'));
      }
    }

    return results;
  }
}
