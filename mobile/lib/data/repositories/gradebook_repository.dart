import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';

class AssessmentItem {
  const AssessmentItem({
    required this.id,
    required this.classId,
    required this.title,
    required this.kind,
    required this.assessedOn,
    required this.maxScore,
    required this.coefficient,
    required this.syncStatus,
  });

  final String id;
  final String classId;
  final String title;
  final String kind;
  final DateTime assessedOn;
  final double maxScore;
  final double coefficient;
  final String syncStatus;
}

class GradeResultItem {
  GradeResultItem({
    required this.studentId,
    required this.studentName,
    this.score,
    this.status = 'graded',
  });

  final String studentId;
  final String studentName;
  double? score;
  String status;
}

class GradebookRepository {
  GradebookRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;

  Stream<List<AssessmentItem>> watchAssessments(String classId) {
    final query = db.select(db.assessments)
      ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.desc(a.assessedOn)]);

    return query.watch().map((rows) {
      return rows
          .map((a) => AssessmentItem(
                id: a.id,
                classId: a.classId,
                title: a.title,
                kind: a.kind,
                assessedOn: a.assessedOn,
                maxScore: a.maxScore,
                coefficient: a.coefficient,
                syncStatus: a.syncStatus,
              ))
          .toList();
    });
  }

  Future<AssessmentItem?> getAssessment(String id) async {
    final query = db.select(db.assessments)
      ..where((a) => a.id.equals(id) & a.deletedAt.isNull());
    final a = await query.getSingleOrNull();
    if (a == null) return null;
    return AssessmentItem(
      id: a.id,
      classId: a.classId,
      title: a.title,
      kind: a.kind,
      assessedOn: a.assessedOn,
      maxScore: a.maxScore,
      coefficient: a.coefficient,
      syncStatus: a.syncStatus,
    );
  }

  Future<String> createAssessment({
    required String classId,
    required String title,
    String kind = 'test',
    required DateTime assessedOn,
    double maxScore = 20.0,
    double coefficient = 1.0,
  }) async {
    final now = DateTime.now();
    final assessmentId = 'asm_${now.millisecondsSinceEpoch}';

    await db.transaction(() async {
      await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              id: assessmentId,
              classId: classId,
              title: title.trim(),
              kind: kind,
              assessedOn: assessedOn,
              maxScore: Value(maxScore),
              coefficient: Value(coefficient),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_asm_$assessmentId',
              entityType: 'assessment',
              entityId: assessmentId,
              operation: 'CREATE',
              payload: jsonEncode({
                'class_id': classId,
                'title': title.trim(),
                'kind': kind,
                'assessed_on': assessedOn.toIso8601String().split('T').first,
                'max_score': maxScore,
                'coefficient': coefficient,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    _trySyncAssessmentRemote(assessmentId, classId, title, kind, assessedOn, maxScore, coefficient);
    return assessmentId;
  }

  Future<List<GradeResultItem>> getAssessmentResults(String assessmentId, String classId) async {
    // 1. Get class students
    final studentLinks = await (db.select(db.classStudents).join([
      innerJoin(db.students, db.students.id.equalsExp(db.classStudents.studentId)),
    ])
          ..where(db.classStudents.classId.equals(classId) &
              db.classStudents.deletedAt.isNull() &
              db.students.deletedAt.isNull()))
        .get();

    // 2. Get existing results
    final results = await (db.select(db.assessmentResults)
          ..where((r) => r.assessmentId.equals(assessmentId) & r.deletedAt.isNull()))
        .get();
    final resultMap = {for (final r in results) r.studentId: r};

    final items = <GradeResultItem>[];
    for (final row in studentLinks) {
      final s = row.readTable(db.students);
      final r = resultMap[s.id];
      items.add(GradeResultItem(
        studentId: s.id,
        studentName: '${s.firstName} ${s.lastName}',
        score: r?.score,
        status: r?.score != null ? 'graded' : 'pending',
      ));
    }

    return items;
  }

  Future<void> saveResults({
    required String assessmentId,
    required double maxScore,
    required List<GradeResultItem> results,
  }) async {
    // Check constraint: score <= maxScore
    for (final r in results) {
      if (r.score != null && r.score! > maxScore) {
        throw ArgumentError('Score ${r.score} exceeds max score $maxScore');
      }
    }

    final now = DateTime.now();

    await db.transaction(() async {
      for (final item in results) {
        final resultId = '${assessmentId}_${item.studentId}';

        await db.into(db.assessmentResults).insertOnConflictUpdate(
              AssessmentResultsCompanion.insert(
                id: resultId,
                assessmentId: assessmentId,
                studentId: item.studentId,
                score: Value(item.score),
                syncStatus: const Value('pending'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Audit entry
        await db.into(db.auditEntries).insert(
              AuditEntriesCompanion.insert(
                id: 'aud_grd_${resultId}_${now.millisecondsSinceEpoch}',
                action: 'save_grade',
                entityType: 'assessment_result',
                entityId: Value(resultId),
                afterJson: Value(jsonEncode({'score': item.score, 'status': item.status})),
                occurredAt: now,
              ),
            );
      }

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_res_${assessmentId}_${now.millisecondsSinceEpoch}',
              entityType: 'assessment_results',
              entityId: assessmentId,
              operation: 'UPDATE',
              payload: jsonEncode({
                'assessment_id': assessmentId,
                'results': results
                    .map((r) => {'student_id': r.studentId, 'score': r.score, 'status': r.status})
                    .toList(),
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    _trySyncResultsRemote(assessmentId, results);
  }

  Future<void> _trySyncAssessmentRemote(
    String localId,
    String classId,
    String title,
    String kind,
    DateTime date,
    double maxScore,
    double coeff,
  ) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/assessments',
        data: {
          'class_id': classId,
          'title': title.trim(),
          'kind': kind,
          'assessed_on': date.toIso8601String().split('T').first,
          'max_score': maxScore,
          'coefficient': coeff,
        },
      );
      if (res.statusCode == 200) {
        await (db.update(db.assessments)..where((a) => a.id.equals(localId))).write(
          const AssessmentsCompanion(syncStatus: Value('synced')),
        );
      }
    } catch (_) {}
  }

  Future<void> _trySyncResultsRemote(String assessmentId, List<GradeResultItem> results) async {
    try {
      final res = await dio.post<List<dynamic>>(
        '/assessments/$assessmentId/results',
        data: {
          'results': results
              .map((r) => {'student_id': r.studentId, 'score': r.score, 'status': r.status})
              .toList(),
        },
      );
      if (res.statusCode == 200) {
        await (db.update(db.assessmentResults)..where((r) => r.assessmentId.equals(assessmentId))).write(
          const AssessmentResultsCompanion(syncStatus: Value('synced')),
        );
      }
    } catch (_) {}
  }
}
