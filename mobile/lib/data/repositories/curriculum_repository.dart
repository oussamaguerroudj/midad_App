import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class CurriculumLessonItem {
  CurriculumLessonItem({
    required this.id,
    required this.unitId,
    required this.title,
    this.position = 1,
    this.progressStatus = 'not_started',
  });

  final String id;
  final String unitId;
  final String title;
  final int position;
  final String progressStatus; // not_started | in_progress | completed
}

class CurriculumUnitItem {
  CurriculumUnitItem({
    required this.id,
    this.subjectId,
    required this.level,
    required this.title,
    this.position = 1,
    this.lessons = const [],
  });

  final String id;
  final String? subjectId;
  final String level;
  final String title;
  final int position;
  final List<CurriculumLessonItem> lessons;
}

class CurriculumRepository {
  CurriculumRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;
  static const _uuid = Uuid();

  Stream<List<CurriculumUnitItem>> watchUnits({String? subjectId, String? level, String? classId}) {
    final query = db.select(db.curriculumUnits)
      ..where((u) {
        var pred = u.deletedAt.isNull();
        if (subjectId != null) pred = pred & u.subjectId.equals(subjectId);
        if (level != null) pred = pred & u.level.equals(level);
        return pred;
      })
      ..orderBy([(u) => OrderingTerm.asc(u.position), (u) => OrderingTerm.asc(u.createdAt)]);

    return query.watch().asyncMap((units) async {
      final unitIds = units.map((u) => u.id).toList();

      final lessons = await (db.select(db.curriculumLessons)
            ..where((l) => l.unitId.isIn(unitIds) & l.deletedAt.isNull())
            ..orderBy([(l) => OrderingTerm.asc(l.position)]))
          .get();

      Map<String, String> progressMap = {};
      if (classId != null) {
        final progs = await (db.select(db.curriculumProgresses)
              ..where((p) => p.classId.equals(classId) & p.deletedAt.isNull()))
            .get();
        progressMap = {for (final p in progs) p.curriculumLessonId: p.status};
      }

      final unitLessonsMap = <String, List<CurriculumLessonItem>>{};
      for (final l in lessons) {
        final st = progressMap[l.id] ?? 'not_started';
        unitLessonsMap.putIfAbsent(l.unitId, () => []).add(CurriculumLessonItem(
              id: l.id,
              unitId: l.unitId,
              title: l.title,
              position: l.position,
              progressStatus: st,
            ));
      }

      return units.map((u) {
        return CurriculumUnitItem(
          id: u.id,
          subjectId: u.subjectId,
          level: u.level,
          title: u.title,
          position: u.position,
          lessons: unitLessonsMap[u.id] ?? [],
        );
      }).toList();
    });
  }

  Future<String> createUnit({
    String? subjectId,
    required String level,
    required String title,
    int position = 1,
  }) async {
    final unitId = _uuid.v4();
    final now = DateTime.now();

    await db.transaction(() async {
      await db.into(db.curriculumUnits).insert(
            CurriculumUnitsCompanion.insert(
              id: unitId,
              subjectId: Value(subjectId),
              level: level.trim(),
              title: title.trim(),
              position: Value(position),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_cu_${now.millisecondsSinceEpoch}',
              entityType: 'curriculum_unit',
              entityId: unitId,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': unitId,
                'subject_id': subjectId,
                'level': level,
                'title': title,
                'position': position,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return unitId;
  }

  Future<String> createLesson({
    required String unitId,
    required String title,
    int position = 1,
  }) async {
    final lessonId = _uuid.v4();
    final now = DateTime.now();

    await db.transaction(() async {
      await db.into(db.curriculumLessons).insert(
            CurriculumLessonsCompanion.insert(
              id: lessonId,
              unitId: unitId,
              title: title.trim(),
              position: Value(position),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_cl_${now.millisecondsSinceEpoch}',
              entityType: 'curriculum_lesson',
              entityId: lessonId,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': lessonId,
                'unit_id': unitId,
                'title': title,
                'position': position,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return lessonId;
  }

  Future<void> updateProgress({
    required String classId,
    required String curriculumLessonId,
    required String status,
  }) async {
    final now = DateTime.now();
    final progId = '${classId}_$curriculumLessonId';

    await db.transaction(() async {
      await db.into(db.curriculumProgresses).insertOnConflictUpdate(
            CurriculumProgressesCompanion.insert(
              id: progId,
              classId: classId,
              curriculumLessonId: curriculumLessonId,
              status: Value(status),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.auditEntries).insert(
            AuditEntriesCompanion.insert(
              id: _uuid.v4(),
              action: 'update_curriculum_progress',
              entityType: 'curriculum_progress',
              entityId: Value(progId),
              afterJson: Value(jsonEncode({'status': status})),
              occurredAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_cp_${now.millisecondsSinceEpoch}',
              entityType: 'curriculum_progress',
              entityId: progId,
              operation: 'UPDATE',
              payload: jsonEncode({
                'class_id': classId,
                'curriculum_lesson_id': curriculumLessonId,
                'status': status,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
}
