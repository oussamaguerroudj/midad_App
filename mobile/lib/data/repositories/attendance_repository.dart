import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';

class AttendanceRecordItem {
  AttendanceRecordItem({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note,
  });

  final String studentId;
  final String studentName;
  String status; // 'present' | 'absent' | 'late' | 'excused'
  String? note;
}

class AttendanceRepository {
  AttendanceRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;

  Future<String> createOrGetSession({
    required String classId,
    required DateTime date,
    String slot = '',
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existing = await (db.select(db.attendanceSessions)
          ..where((s) =>
              s.classId.equals(classId) &
              s.sessionDate.equals(dateOnly) &
              s.slot.equals(slot) &
              s.deletedAt.isNull()))
        .getSingleOrNull();

    if (existing != null) return existing.id;

    final now = DateTime.now();
    final sessionId = 'attsess_${dateOnly.millisecondsSinceEpoch}_$slot';

    await db.transaction(() async {
      await db.into(db.attendanceSessions).insert(
            AttendanceSessionsCompanion.insert(
              id: sessionId,
              classId: classId,
              sessionDate: dateOnly,
              slot: Value(slot),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_att_$sessionId',
              entityType: 'attendance_session',
              entityId: sessionId,
              operation: 'CREATE',
              payload: jsonEncode({
                'class_id': classId,
                'session_date': dateOnly.toIso8601String().split('T').first,
                'slot': slot,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    _trySyncSessionRemote(sessionId, classId, dateOnly, slot);
    return sessionId;
  }

  Future<List<AttendanceRecordItem>> getSessionRoster(String sessionId, String classId) async {
    // 1. Get class students
    final studentLinks = await (db.select(db.classStudents).join([
      innerJoin(db.students, db.students.id.equalsExp(db.classStudents.studentId)),
    ])
          ..where(db.classStudents.classId.equals(classId) &
              db.classStudents.deletedAt.isNull() &
              db.students.deletedAt.isNull()))
        .get();

    // 2. Get existing records
    final records = await (db.select(db.attendanceRecords)
          ..where((r) => r.sessionId.equals(sessionId) & r.deletedAt.isNull()))
        .get();
    final recordMap = {for (final r in records) r.studentId: r};

    final roster = <AttendanceRecordItem>[];
    for (final row in studentLinks) {
      final s = row.readTable(db.students);
      final r = recordMap[s.id];
      roster.add(AttendanceRecordItem(
        studentId: s.id,
        studentName: '${s.firstName} ${s.lastName}',
        status: r?.status ?? 'present',
        note: r?.note,
      ));
    }

    return roster;
  }

  Future<void> saveRecords({
    required String sessionId,
    required List<AttendanceRecordItem> records,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      for (final item in records) {
        final recordId = '${sessionId}_${item.studentId}';

        await db.into(db.attendanceRecords).insertOnConflictUpdate(
              AttendanceRecordsCompanion.insert(
                id: recordId,
                sessionId: sessionId,
                studentId: item.studentId,
                status: item.status,
                note: Value(item.note),
                syncStatus: const Value('pending'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Audit entry
        await db.into(db.auditEntries).insert(
              AuditEntriesCompanion.insert(
                id: 'aud_att_${recordId}_${now.millisecondsSinceEpoch}',
                action: 'save_attendance',
                entityType: 'attendance_record',
                entityId: Value(recordId),
                afterJson: Value(jsonEncode({'status': item.status, 'note': item.note})),
                occurredAt: now,
              ),
            );
      }

      // Sync queue
      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_rec_${sessionId}_${now.millisecondsSinceEpoch}',
              entityType: 'attendance_records',
              entityId: sessionId,
              operation: 'UPDATE',
              payload: jsonEncode({
                'session_id': sessionId,
                'records': records
                    .map((r) => {'student_id': r.studentId, 'status': r.status, 'note': r.note})
                    .toList(),
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    _trySyncRecordsRemote(sessionId, records);
  }

  Future<void> _trySyncSessionRemote(String localId, String classId, DateTime date, String slot) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final res = await dio.post<Map<String, dynamic>>(
        '/attendance/sessions',
        data: {'class_id': classId, 'session_date': dateStr, 'slot': slot},
      );
      if (res.statusCode == 200 && res.data != null) {
        await (db.update(db.attendanceSessions)..where((s) => s.id.equals(localId))).write(
          const AttendanceSessionsCompanion(syncStatus: Value('synced')),
        );
      }
    } catch (_) {}
  }

  Future<void> _trySyncRecordsRemote(String sessionId, List<AttendanceRecordItem> records) async {
    try {
      final res = await dio.post<List<dynamic>>(
        '/attendance/sessions/$sessionId/records',
        data: {
          'records': records
              .map((r) => {'student_id': r.studentId, 'status': r.status, 'note': r.note})
              .toList(),
        },
      );
      if (res.statusCode == 200) {
        await (db.update(db.attendanceRecords)..where((r) => r.sessionId.equals(sessionId))).write(
          const AttendanceRecordsCompanion(syncStatus: Value('synced')),
        );
      }
    } catch (_) {}
  }
}
