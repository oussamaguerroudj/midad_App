import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';

class ClassWithSubject {
  const ClassWithSubject({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectId,
    required this.subjectName,
    required this.studentCount,
    required this.syncStatus,
  });

  final String id;
  final String name;
  final String? level;
  final String subjectId;
  final String subjectName;
  final int studentCount;
  final String syncStatus;
}

class ClassesRepository {
  ClassesRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;

  Stream<List<ClassWithSubject>> watchClasses() {
    final query = db.select(db.classes).join([
      innerJoin(db.subjects, db.subjects.id.equalsExp(db.classes.subjectId)),
    ])..where(db.classes.deletedAt.isNull());

    return query.watch().asyncMap((rows) async {
      final result = <ClassWithSubject>[];
      for (final row in rows) {
        final classRow = row.readTable(db.classes);
        final subjectRow = row.readTable(db.subjects);

        // Count active students in class
        final studentCountQuery = db.selectOnly(db.classStudents)
          ..addColumns([db.classStudents.id.count()])
          ..where(db.classStudents.classId.equals(classRow.id) & db.classStudents.deletedAt.isNull());
        final count = await studentCountQuery.map((r) => r.read(db.classStudents.id.count()) ?? 0).getSingle();

        result.add(ClassWithSubject(
          id: classRow.id,
          name: classRow.name,
          level: classRow.level,
          subjectId: subjectRow.id,
          subjectName: subjectRow.name,
          studentCount: count,
          syncStatus: classRow.syncStatus,
        ));
      }
      return result;
    });
  }

  Future<ClassWithSubject?> getClassById(String id) async {
    final query = db.select(db.classes).join([
      innerJoin(db.subjects, db.subjects.id.equalsExp(db.classes.subjectId)),
    ])..where(db.classes.id.equals(id) & db.classes.deletedAt.isNull());

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final classRow = row.readTable(db.classes);
    final subjectRow = row.readTable(db.subjects);

    final countQuery = db.selectOnly(db.classStudents)
      ..addColumns([db.classStudents.id.count()])
      ..where(db.classStudents.classId.equals(classRow.id) & db.classStudents.deletedAt.isNull());
    final count = await countQuery.map((r) => r.read(db.classStudents.id.count()) ?? 0).getSingle();

    return ClassWithSubject(
      id: classRow.id,
      name: classRow.name,
      level: classRow.level,
      subjectId: subjectRow.id,
      subjectName: subjectRow.name,
      studentCount: count,
      syncStatus: classRow.syncStatus,
    );
  }

  Future<String> createClass({
    required String name,
    String? level,
    required String subjectName,
  }) async {
    final now = DateTime.now();

    // 1. Ensure subject exists in local DB
    final existingSubject = await (db.select(db.subjects)
          ..where((s) => s.name.equals(subjectName) & s.deletedAt.isNull()))
        .getSingleOrNull();

    final subjectId = existingSubject?.id ?? 'subj_${now.millisecondsSinceEpoch}';
    if (existingSubject == null) {
      await db.into(db.subjects).insert(
            SubjectsCompanion.insert(
              id: subjectId,
              name: subjectName,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 2. Ensure academic year exists in local DB
    final existingYear = await (db.select(db.academicYears)
          ..where((y) => y.deletedAt.isNull()))
        .getSingleOrNull();

    final yearId = existingYear?.id ?? 'year_${now.millisecondsSinceEpoch}';
    if (existingYear == null) {
      final startYear = now.month >= 9 ? now.year : now.year - 1;
      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: yearId,
              label: '$startYear-${startYear + 1}',
              startsOn: DateTime(startYear, 9, 1),
              endsOn: DateTime(startYear + 1, 6, 30),
              isCurrent: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 3. Create class
    final classId = 'cls_${now.millisecondsSinceEpoch}';
    final payload = jsonEncode({
      'id': classId,
      'name': name.trim(),
      'level': level?.trim(),
      'subject_name': subjectName.trim(),
      'academic_year_id': yearId,
    });

    await db.transaction(() async {
      await db.into(db.classes).insert(
            ClassesCompanion.insert(
              id: classId,
              academicYearId: yearId,
              subjectId: subjectId,
              name: name.trim(),
              level: Value(level?.trim()),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_${now.millisecondsSinceEpoch}',
              entityType: 'class',
              entityId: classId,
              operation: 'CREATE',
              payload: payload,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    // Try background sync if possible
    _trySyncClassRemote(classId, name, level, subjectName, yearId);

    return classId;
  }

  Future<void> _trySyncClassRemote(
    String localId,
    String name,
    String? level,
    String subjectName,
    String yearId,
  ) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/classes',
        data: {
          'name': name.trim(),
          'level': level?.trim(),
          'subject_name': subjectName.trim(),
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final serverData = res.data!;
        final serverVersion = serverData['version'] as int? ?? 1;
        await (db.update(db.classes)..where((c) => c.id.equals(localId))).write(
          ClassesCompanion(
            syncStatus: const Value('synced'),
            version: Value(serverVersion),
          ),
        );
      }
    } catch (_) {
      // Retained in sync_queue for background sync
    }
  }

  Future<void> syncFromRemote() async {
    try {
      final res = await dio.get<List<dynamic>>('/classes');
      if (res.statusCode == 200 && res.data != null) {
        final now = DateTime.now();
        for (final item in res.data!) {
          final m = item as Map<String, dynamic>;
          final cId = m['id'] as String;
          final cName = m['name'] as String;
          final cLevel = m['level'] as String?;
          final sId = m['subject_id'] as String;
          final sName = m['subject_name'] as String;
          final yId = m['academic_year_id'] as String;
          final ver = m['version'] as int? ?? 1;

          // Upsert subject
          await db.into(db.subjects).insertOnConflictUpdate(
                SubjectsCompanion.insert(
                  id: sId,
                  name: sName,
                  syncStatus: const Value('synced'),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // Upsert class
          await db.into(db.classes).insertOnConflictUpdate(
                ClassesCompanion.insert(
                  id: cId,
                  academicYearId: yId,
                  subjectId: sId,
                  name: cName,
                  level: Value(cLevel),
                  syncStatus: const Value('synced'),
                  version: Value(ver),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
