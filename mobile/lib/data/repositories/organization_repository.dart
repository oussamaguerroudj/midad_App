import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class LocalFollowUpAlert {
  const LocalFollowUpAlert({
    required this.id,
    required this.ruleType,
    required this.severity,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.message,
    this.metricValue,
  });

  final String id;
  final String ruleType; // attendance | academic
  final String severity; // warning | danger
  final String studentId;
  final String studentName;
  final String className;
  final String message;
  final num? metricValue;
}

class OrganizationRepository {
  OrganizationRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  // --- Seating Plans ---
  Stream<List<SeatingPlan>> watchSeatingPlans(String classId) {
    return (_db.select(_db.seatingPlans)
          ..where((t) => t.classId.equals(classId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<SeatingPlanMember>> watchPlanMembers(String planId) {
    return (_db.select(_db.seatingPlanMembers)
          ..where((t) => t.planId.equals(planId) & t.deletedAt.isNull()))
        .watch();
  }

  Future<SeatingPlan> createSeatingPlan({
    required String classId,
    required String name,
    String layout = 'custom',
    List<({String? studentId, double seatX, double seatY})> members = const [],
  }) async {
    final now = DateTime.now();
    final planId = _uuid.v4();

    return _db.transaction(() async {
      final companion = SeatingPlansCompanion(
        id: Value(planId),
        classId: Value(classId),
        name: Value(name),
        layout: Value(layout),
        version: const Value(1),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await _db.into(_db.seatingPlans).insert(companion);

      final membersPayload = <Map<String, dynamic>>[];
      for (final m in members) {
        final memId = _uuid.v4();
        await _db.into(_db.seatingPlanMembers).insert(
              SeatingPlanMembersCompanion(
                id: Value(memId),
                planId: Value(planId),
                studentId: Value(m.studentId),
                seatX: Value(m.seatX),
                seatY: Value(m.seatY),
                version: const Value(1),
                syncStatus: const Value('pending'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        membersPayload.add({
          'id': memId,
          'student_id': m.studentId,
          'seat_x': m.seatX,
          'seat_y': m.seatY,
        });
      }

      final queueId = _uuid.v4();
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion(
              id: Value(queueId),
              entityType: const Value('seating_plan'),
              entityId: Value(planId),
              operation: const Value('CREATE'),
              payload: Value(jsonEncode({
                'id': planId,
                'class_id': classId,
                'name': name,
                'layout': layout,
                'members': membersPayload,
              })),
              baseVersion: const Value(0),
              createdAt: Value(now),
              updatedAt: Value(now),
              status: const Value('pending'),
            ),
          );

      return (await (_db.select(_db.seatingPlans)..where((t) => t.id.equals(planId))).getSingle());
    });
  }

  // --- Student Groups ---
  Stream<List<StudentGroup>> watchGroups(String classId) {
    return (_db.select(_db.studentGroups)
          ..where((t) => t.classId.equals(classId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    return (_db.select(_db.groupMembers)
          ..where((t) => t.groupId.equals(groupId) & t.deletedAt.isNull()))
        .watch();
  }

  Future<StudentGroup> createGroup({
    required String classId,
    required String name,
    List<String> studentIds = const [],
  }) async {
    final now = DateTime.now();
    final groupId = _uuid.v4();

    return _db.transaction(() async {
      final companion = StudentGroupsCompanion(
        id: Value(groupId),
        classId: Value(classId),
        name: Value(name),
        version: const Value(1),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await _db.into(_db.studentGroups).insert(companion);

      for (final sId in studentIds) {
        final memId = _uuid.v4();
        await _db.into(_db.groupMembers).insert(
              GroupMembersCompanion(
                id: Value(memId),
                groupId: Value(groupId),
                studentId: Value(sId),
                version: const Value(1),
                syncStatus: const Value('pending'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      final queueId = _uuid.v4();
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion(
              id: Value(queueId),
              entityType: const Value('student_group'),
              entityId: Value(groupId),
              operation: const Value('CREATE'),
              payload: Value(jsonEncode({
                'id': groupId,
                'class_id': classId,
                'name': name,
                'student_ids': studentIds,
              })),
              baseVersion: const Value(0),
              createdAt: Value(now),
              updatedAt: Value(now),
              status: const Value('pending'),
            ),
          );

      return (await (_db.select(_db.studentGroups)..where((t) => t.id.equals(groupId))).getSingle());
    });
  }

  // --- Student Activity / Participation Log ---
  Stream<List<StudentActivityLog>> watchActivityLogs(String classId, {String? studentId}) {
    final query = _db.select(_db.studentActivityLogs)
      ..where((t) => t.classId.equals(classId) & t.deletedAt.isNull());
    if (studentId != null) {
      query.where((t) => t.studentId.equals(studentId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.loggedOn, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<StudentActivityLog> logActivity({
    required String classId,
    required String studentId,
    required String category,
    String? note,
    DateTime? loggedOn,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final date = loggedOn ?? now;

    final companion = StudentActivityLogsCompanion(
      id: Value(id),
      classId: Value(classId),
      studentId: Value(studentId),
      loggedOn: Value(date),
      category: Value(category),
      note: Value(note),
      version: const Value(1),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.into(_db.studentActivityLogs).insert(companion);

    final queueId = _uuid.v4();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion(
            id: Value(queueId),
            entityType: const Value('student_activity_log'),
            entityId: Value(id),
            operation: const Value('CREATE'),
            payload: Value(jsonEncode({
              'id': id,
              'class_id': classId,
              'student_id': studentId,
              'logged_on': date.toIso8601String(),
              'category': category,
              'note': note,
            })),
            baseVersion: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
            status: const Value('pending'),
          ),
        );

    return (await (_db.select(_db.studentActivityLogs)..where((t) => t.id.equals(id))).getSingle());
  }

  // --- Favorites ---
  Stream<List<Favorite>> watchFavorites(String targetType) {
    return (_db.select(_db.favorites)..where((t) => t.targetType.equals(targetType))).watch();
  }

  Future<bool> isFavorite(String targetType, String targetId) async {
    final entry = await (_db.select(_db.favorites)
          ..where((t) => t.targetType.equals(targetType) & t.targetId.equals(targetId)))
        .getSingleOrNull();
    return entry != null;
  }

  Future<void> toggleFavorite(String targetType, String targetId) async {
    final existing = await (_db.select(_db.favorites)
          ..where((t) => t.targetType.equals(targetType) & t.targetId.equals(targetId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.favorites)..where((t) => t.id.equals(existing.id))).go();
    } else {
      await _db.into(_db.favorites).insert(
            FavoritesCompanion(
              id: Value(_uuid.v4()),
              targetType: Value(targetType),
              targetId: Value(targetId),
              createdAt: Value(DateTime.now()),
            ),
          );
    }
  }

  // --- Local Follow-Up Rule Evaluation ---
  Future<List<LocalFollowUpAlert>> evaluateFollowUpRules() async {
    final alerts = <LocalFollowUpAlert>[];

    // Rule 1: Students with 3 or more absences
    final students = await (_db.select(_db.students)..where((t) => t.deletedAt.isNull())).get();
    final classes = await (_db.select(_db.classes)..where((t) => t.deletedAt.isNull())).get();
    final classMap = {for (final c in classes) c.id: c.name};

    for (final s in students) {
      final records = await (_db.select(_db.attendanceRecords)
            ..where((t) => t.studentId.equals(s.id) & t.deletedAt.isNull()))
          .get();

      final absences = records.where((r) => r.status == 'absent' || r.status == 'late').length;
      if (absences >= 3) {
        alerts.add(
          LocalFollowUpAlert(
            id: 'att-${s.id}',
            ruleType: 'attendance',
            severity: absences >= 5 ? 'danger' : 'warning',
            studentId: s.id,
            studentName: '${s.firstName} ${s.lastName}',
            className: classMap.values.isNotEmpty ? classMap.values.first : 'القسم',
            message: 'تنبيه غياب: $absences تسجيلات غياب/تأخر مسجلة لهذا التلميذ.',
            metricValue: absences,
          ),
        );
      }

      // Rule 2: Low scores < 10
      final results = await (_db.select(_db.assessmentResults)
            ..where((t) => t.studentId.equals(s.id) & t.deletedAt.isNull()))
          .get();
      final validScores = results.where((r) => r.score != null).map((r) => r.score!).toList();
      if (validScores.isNotEmpty) {
        final avg = validScores.reduce((a, b) => a + b) / validScores.length;
        if (avg < 10.0) {
          alerts.add(
            LocalFollowUpAlert(
              id: 'acad-${s.id}',
              ruleType: 'academic',
              severity: 'warning',
              studentId: s.id,
              studentName: '${s.firstName} ${s.lastName}',
              className: classMap.values.isNotEmpty ? classMap.values.first : 'القسم',
              message: 'متابعة تحصيلية: معدل التقييمات (${avg.toStringAsFixed(1)}/20) يقل عن عتبة التمكّن.',
              metricValue: avg,
            ),
          );
        }
      }
    }

    return alerts;
  }
}
