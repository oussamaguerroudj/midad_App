import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class AssignmentItem {
  AssignmentItem({
    required this.id,
    required this.classId,
    required this.title,
    this.description,
    this.dueOn,
    this.version = 1,
    this.syncStatus = 'pending',
  });

  final String id;
  final String classId;
  final String title;
  final String? description;
  final DateTime? dueOn;
  final int version;
  final String syncStatus;
}

class AssignmentRecordItem {
  AssignmentRecordItem({
    required this.studentId,
    required this.studentName,
    this.status = 'assigned',
  });

  final String studentId;
  final String studentName;
  String status; // assigned | completed | missing | excused
}

class AssignmentsRepository {
  AssignmentsRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;
  static const _uuid = Uuid();

  Stream<List<AssignmentItem>> watchAssignments(String classId) {
    final query = db.select(db.assignments)
      ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.desc(a.dueOn), (a) => OrderingTerm.desc(a.createdAt)]);

    return query.watch().map((rows) {
      return rows
          .map((a) => AssignmentItem(
                id: a.id,
                classId: a.classId,
                title: a.title,
                description: a.description,
                dueOn: a.dueOn,
                version: a.version,
                syncStatus: a.syncStatus,
              ))
          .toList();
    });
  }

  Future<String> createAssignment({
    required String classId,
    required String title,
    String? description,
    DateTime? dueOn,
  }) async {
    final assignmentId = _uuid.v4();
    final now = DateTime.now();

    await db.transaction(() async {
      await db.into(db.assignments).insert(
            AssignmentsCompanion.insert(
              id: assignmentId,
              classId: classId,
              title: title.trim(),
              description: Value(description),
              dueOn: Value(dueOn),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Audit entry
      await db.into(db.auditEntries).insert(
            AuditEntriesCompanion.insert(
              id: _uuid.v4(),
              action: 'create_assignment',
              entityType: 'assignment',
              entityId: Value(assignmentId),
              afterJson: Value(jsonEncode({'title': title, 'classId': classId})),
              occurredAt: now,
            ),
          );

      // Sync queue
      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_asg_${now.millisecondsSinceEpoch}',
              entityType: 'assignment',
              entityId: assignmentId,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': assignmentId,
                'class_id': classId,
                'title': title,
                'description': description,
                'due_on': dueOn?.toIso8601String(),
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return assignmentId;
  }

  Future<List<AssignmentRecordItem>> getAssignmentRecords(String assignmentId, String classId) async {
    final studentLinks = await (db.select(db.classStudents).join([
      innerJoin(db.students, db.students.id.equalsExp(db.classStudents.studentId)),
    ])
          ..where(db.classStudents.classId.equals(classId) &
              db.classStudents.deletedAt.isNull() &
              db.students.deletedAt.isNull()))
        .get();

    final records = await (db.select(db.assignmentRecords)
          ..where((r) => r.assignmentId.equals(assignmentId) & r.deletedAt.isNull()))
        .get();
    final recordMap = {for (final r in records) r.studentId: r};

    final items = <AssignmentRecordItem>[];
    for (final row in studentLinks) {
      final s = row.readTable(db.students);
      final r = recordMap[s.id];
      items.add(AssignmentRecordItem(
        studentId: s.id,
        studentName: '${s.firstName} ${s.lastName}',
        status: r?.status ?? 'assigned',
      ));
    }
    return items;
  }

  Future<void> saveAssignmentRecords({
    required String assignmentId,
    required List<AssignmentRecordItem> records,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      for (final item in records) {
        final recordId = '${assignmentId}_${item.studentId}';

        await db.into(db.assignmentRecords).insertOnConflictUpdate(
              AssignmentRecordsCompanion.insert(
                id: recordId,
                assignmentId: assignmentId,
                studentId: item.studentId,
                status: Value(item.status),
                syncStatus: const Value('pending'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db.into(db.auditEntries).insert(
              AuditEntriesCompanion.insert(
                id: _uuid.v4(),
                action: 'save_assignment_record',
                entityType: 'assignment_record',
                entityId: Value(recordId),
                afterJson: Value(jsonEncode({'status': item.status})),
                occurredAt: now,
              ),
            );
      }

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_asg_rec_${now.millisecondsSinceEpoch}',
              entityType: 'assignment_records',
              entityId: assignmentId,
              operation: 'UPDATE',
              payload: jsonEncode({
                'assignment_id': assignmentId,
                'records': records.map((r) => {'student_id': r.studentId, 'status': r.status}).toList(),
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
}
