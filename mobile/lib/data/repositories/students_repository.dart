import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';

class StudentItem {
  const StudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.externalRef,
    required this.syncStatus,
    this.enrolledClasses = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? externalRef;
  final String syncStatus;
  final List<String> enrolledClasses;

  String get fullName => '$firstName $lastName';
}

class StudentsRepository {
  StudentsRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;

  Stream<List<StudentItem>> watchStudents({String? classId, String? search}) {
    final query = db.select(db.students)..where((s) => s.deletedAt.isNull());

    if (classId != null && classId.isNotEmpty) {
      query.join([
        innerJoin(
          db.classStudents,
          db.classStudents.studentId.equalsExp(db.students.id) &
              db.classStudents.classId.equals(classId) &
              db.classStudents.deletedAt.isNull(),
        ),
      ]);
    }

    return query.watch().asyncMap((rows) async {
      final result = <StudentItem>[];
      for (final student in rows) {
        // Search filter in-memory or via SQL
        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          final matches = student.firstName.toLowerCase().contains(q) ||
              student.lastName.toLowerCase().contains(q) ||
              (student.externalRef?.toLowerCase().contains(q) ?? false);
          if (!matches) continue;
        }

        // Fetch enrolled class names
        final classLinks = await (db.select(db.classStudents).join([
          innerJoin(db.classes, db.classes.id.equalsExp(db.classStudents.classId)),
        ])
              ..where(db.classStudents.studentId.equals(student.id) &
                  db.classStudents.deletedAt.isNull() &
                  db.classes.deletedAt.isNull()))
            .get();

        final classNames = classLinks.map((r) => r.readTable(db.classes).name).toList();

        result.add(StudentItem(
          id: student.id,
          firstName: student.firstName,
          lastName: student.lastName,
          externalRef: student.externalRef,
          syncStatus: student.syncStatus,
          enrolledClasses: classNames,
        ));
      }
      return result;
    });
  }

  Future<StudentItem?> getStudentById(String id) async {
    final student = await (db.select(db.students)..where((s) => s.id.equals(id) & s.deletedAt.isNull())).getSingleOrNull();
    if (student == null) return null;

    final classLinks = await (db.select(db.classStudents).join([
      innerJoin(db.classes, db.classes.id.equalsExp(db.classStudents.classId)),
    ])
          ..where(db.classStudents.studentId.equals(student.id) &
              db.classStudents.deletedAt.isNull() &
              db.classes.deletedAt.isNull()))
        .get();

    final classNames = classLinks.map((r) => r.readTable(db.classes).name).toList();

    return StudentItem(
      id: student.id,
      firstName: student.firstName,
      lastName: student.lastName,
      externalRef: student.externalRef,
      syncStatus: student.syncStatus,
      enrolledClasses: classNames,
    );
  }

  Future<String> createStudent({
    required String firstName,
    required String lastName,
    String? externalRef,
    String? classId,
  }) async {
    final now = DateTime.now();
    final studentId = 'std_${now.millisecondsSinceEpoch}';

    final payload = jsonEncode({
      'id': studentId,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'external_ref': externalRef?.trim(),
      'class_id': classId,
    });

    await db.transaction(() async {
      await db.into(db.students).insert(
            StudentsCompanion.insert(
              id: studentId,
              firstName: firstName.trim(),
              lastName: lastName.trim(),
              externalRef: Value(externalRef?.trim()),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (classId != null && classId.isNotEmpty) {
        await db.into(db.classStudents).insert(
              ClassStudentsCompanion.insert(
                id: 'cs_${now.millisecondsSinceEpoch}',
                classId: classId,
                studentId: studentId,
                syncStatus: const Value('pending'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_std_${now.millisecondsSinceEpoch}',
              entityType: 'student',
              entityId: studentId,
              operation: 'CREATE',
              payload: payload,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    // Try background sync
    _trySyncStudentRemote(studentId, firstName, lastName, externalRef, classId);

    return studentId;
  }

  Future<void> _trySyncStudentRemote(
    String localId,
    String firstName,
    String lastName,
    String? externalRef,
    String? classId,
  ) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/students',
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'external_ref': externalRef?.trim(),
          'class_id': classId,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final serverData = res.data!;
        final serverVersion = serverData['version'] as int? ?? 1;
        await (db.update(db.students)..where((s) => s.id.equals(localId))).write(
          StudentsCompanion(
            syncStatus: const Value('synced'),
            version: Value(serverVersion),
          ),
        );
      }
    } catch (_) {
      // Retained in sync queue
    }
  }

  Future<void> syncFromRemote({String? classId}) async {
    try {
      final queryParams = classId != null ? {'class_id': classId} : null;
      final res = await dio.get<List<dynamic>>('/students', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final now = DateTime.now();
        for (final item in res.data!) {
          final m = item as Map<String, dynamic>;
          final sId = m['id'] as String;
          final fName = m['first_name'] as String;
          final lName = m['last_name'] as String;
          final ref = m['external_ref'] as String?;
          final ver = m['version'] as int? ?? 1;

          await db.into(db.students).insertOnConflictUpdate(
                StudentsCompanion.insert(
                  id: sId,
                  firstName: fName,
                  lastName: lName,
                  externalRef: Value(ref),
                  syncStatus: const Value('synced'),
                  version: Value(ver),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          final classes = m['classes'] as List<dynamic>? ?? [];
          for (final cls in classes) {
            final cMap = cls as Map<String, dynamic>;
            final cId = cMap['id'] as String;
            final linkId = '${cId}_$sId';
            await db.into(db.classStudents).insertOnConflictUpdate(
                  ClassStudentsCompanion.insert(
                    id: linkId,
                    classId: cId,
                    studentId: sId,
                    syncStatus: const Value('synced'),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
