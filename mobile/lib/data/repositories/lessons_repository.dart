import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class LessonItem {
  LessonItem({
    required this.id,
    this.classId,
    this.className,
    this.subjectId,
    required this.topic,
    this.lessonDate,
    this.durationMin = 60,
    this.objectives,
    this.content,
    this.activities,
    this.homework,
    this.notes,
    this.journalCovered,
    this.completion = 'planned',
    this.version = 1,
    this.syncStatus = 'pending',
  });

  final String id;
  final String? classId;
  final String? className;
  final String? subjectId;
  final String topic;
  final DateTime? lessonDate;
  final int? durationMin;
  final String? objectives;
  final String? content;
  final String? activities;
  final String? homework;
  final String? notes;
  final String? journalCovered;
  final String completion; // planned | in_progress | completed
  final int version;
  final String syncStatus;
}

class LessonsRepository {
  LessonsRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;
  static const _uuid = Uuid();

  Stream<List<LessonItem>> watchLessons({String? classId}) {
    final query = db.select(db.lessons)
      ..where((l) {
        var pred = l.deletedAt.isNull();
        if (classId != null) {
          pred = pred & l.classId.equals(classId);
        }
        return pred;
      })
      ..orderBy([(l) => OrderingTerm.desc(l.lessonDate), (l) => OrderingTerm.desc(l.createdAt)]);

    return query.watch().asyncMap((rows) async {
      final items = <LessonItem>[];
      for (final r in rows) {
        String? className;
        if (r.classId != null) {
          final c = await (db.select(db.classes)..where((cl) => cl.id.equals(r.classId!))).getSingleOrNull();
          className = c?.name;
        }

        items.add(LessonItem(
          id: r.id,
          classId: r.classId,
          className: className,
          subjectId: r.subjectId,
          topic: r.topic,
          lessonDate: r.lessonDate,
          durationMin: r.durationMin,
          objectives: r.objectives,
          content: r.content,
          activities: r.activities,
          homework: r.homework,
          notes: r.notes,
          journalCovered: r.journalCovered,
          completion: r.completion,
          version: r.version,
          syncStatus: r.syncStatus,
        ));
      }
      return items;
    });
  }

  Future<LessonItem?> getLessonById(String id) async {
    final r = await (db.select(db.lessons)..where((l) => l.id.equals(id) & l.deletedAt.isNull())).getSingleOrNull();
    if (r == null) return null;

    String? className;
    if (r.classId != null) {
      final c = await (db.select(db.classes)..where((cl) => cl.id.equals(r.classId!))).getSingleOrNull();
      className = c?.name;
    }

    return LessonItem(
      id: r.id,
      classId: r.classId,
      className: className,
      subjectId: r.subjectId,
      topic: r.topic,
      lessonDate: r.lessonDate,
      durationMin: r.durationMin,
      objectives: r.objectives,
      content: r.content,
      activities: r.activities,
      homework: r.homework,
      notes: r.notes,
      journalCovered: r.journalCovered,
      completion: r.completion,
      version: r.version,
      syncStatus: r.syncStatus,
    );
  }

  Future<String> createLesson({
    required String topic,
    String? classId,
    String? subjectId,
    DateTime? lessonDate,
    int? durationMin = 60,
    String? objectives,
    String? content,
    String? activities,
    String? homework,
    String? notes,
    String completion = 'planned',
  }) async {
    final lessonId = _uuid.v4();
    final now = DateTime.now();

    await db.transaction(() async {
      await db.into(db.lessons).insert(
            LessonsCompanion.insert(
              id: lessonId,
              topic: topic.trim(),
              classId: Value(classId),
              subjectId: Value(subjectId),
              lessonDate: Value(lessonDate),
              durationMin: Value(durationMin),
              objectives: Value(objectives),
              content: Value(content),
              activities: Value(activities),
              homework: Value(homework),
              notes: Value(notes),
              completion: Value(completion),
              version: const Value(1),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Audit entry
      await db.into(db.auditEntries).insert(
            AuditEntriesCompanion.insert(
              id: _uuid.v4(),
              action: 'create_lesson',
              entityType: 'lesson',
              entityId: Value(lessonId),
              afterJson: Value(jsonEncode({'topic': topic, 'completion': completion})),
              occurredAt: now,
            ),
          );

      // Sync queue
      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_les_${now.millisecondsSinceEpoch}',
              entityType: 'lesson',
              entityId: lessonId,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': lessonId,
                'topic': topic,
                'class_id': classId,
                'subject_id': subjectId,
                'lesson_date': lessonDate?.toIso8601String(),
                'duration_min': durationMin,
                'objectives': objectives,
                'content': content,
                'activities': activities,
                'homework': homework,
                'notes': notes,
                'completion': completion,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return lessonId;
  }

  Future<void> updateJournal({
    required String lessonId,
    required String completion,
    required String journalCovered,
  }) async {
    final existing = await (db.select(db.lessons)..where((l) => l.id.equals(lessonId))).getSingleOrNull();
    if (existing == null) throw StateError('Lesson $lessonId not found');

    final now = DateTime.now();
    final newVersion = existing.version + 1;

    await db.transaction(() async {
      await (db.update(db.lessons)..where((l) => l.id.equals(lessonId))).write(
        LessonsCompanion(
          completion: Value(completion),
          journalCovered: Value(journalCovered),
          version: Value(newVersion),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ),
      );

      // Audit entry
      await db.into(db.auditEntries).insert(
            AuditEntriesCompanion.insert(
              id: _uuid.v4(),
              action: 'update_journal',
              entityType: 'lesson',
              entityId: Value(lessonId),
              beforeJson: Value(jsonEncode({'completion': existing.completion, 'covered': existing.journalCovered})),
              afterJson: Value(jsonEncode({'completion': completion, 'covered': journalCovered})),
              occurredAt: now,
            ),
          );

      // Sync queue
      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_les_jrn_${now.millisecondsSinceEpoch}',
              entityType: 'lesson',
              entityId: lessonId,
              operation: 'UPDATE',
              baseVersion: Value(existing.version),
              payload: jsonEncode({
                'completion': completion,
                'journal_covered': journalCovered,
                'base_version': existing.version,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
}
