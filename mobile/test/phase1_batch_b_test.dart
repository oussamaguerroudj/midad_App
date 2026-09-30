import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/data/local/app_database.dart';
import 'package:midad/data/repositories/attendance_repository.dart';
import 'package:midad/data/repositories/classes_repository.dart';
import 'package:midad/data/repositories/gradebook_repository.dart';
import 'package:midad/data/repositories/students_repository.dart';
import 'package:midad/data/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase 1 Batch (b) Repositories & Sync Engine Offline-First Tests', () {
    late AppDatabase db;
    late Dio dio;
    late SharedPreferences prefs;
    late ClassesRepository classesRepo;
    late StudentsRepository studentsRepo;
    late AttendanceRepository attendanceRepo;
    late GradebookRepository gradebookRepo;
    late SyncEngine syncEngine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.inMemory();
      dio = Dio();
      classesRepo = ClassesRepository(db: db, dio: dio);
      studentsRepo = StudentsRepository(db: db, dio: dio);
      attendanceRepo = AttendanceRepository(db: db, dio: dio);
      gradebookRepo = GradebookRepository(db: db, dio: dio);
      syncEngine = SyncEngine(db: db, dio: dio, prefs: prefs);
    });

    tearDown(() async {
      await db.close();
    });

    test('AttendanceRepository: create session and save roster records with audit entry', () async {
      final classId = await classesRepo.createClass(
        name: '3 ع ت 2',
        level: 'الثالثة ثانوي',
        subjectName: 'العلوم الفيزيائية',
      );

      final studentId1 = await studentsRepo.createStudent(
        firstName: 'علي',
        lastName: 'بوزيد',
        externalRef: 'ST-010',
        classId: classId,
      );

      final studentId2 = await studentsRepo.createStudent(
        firstName: 'سارة',
        lastName: 'حسني',
        externalRef: 'ST-011',
        classId: classId,
      );

      final today = DateTime.now();
      final sessionId = await attendanceRepo.createOrGetSession(
        classId: classId,
        date: today,
      );

      expect(sessionId, isNotEmpty);

      // Verify roster query
      final initialRoster = await attendanceRepo.getSessionRoster(sessionId, classId);
      expect(initialRoster.length, 2);
      expect(initialRoster.any((r) => r.studentId == studentId1), isTrue);
      expect(initialRoster.any((r) => r.studentId == studentId2), isTrue);

      // Save records (one present, one absent)
      final recordsToSave = [
        AttendanceRecordItem(
          studentId: studentId1,
          studentName: 'علي بوزيد',
          status: 'present',
        ),
        AttendanceRecordItem(
          studentId: studentId2,
          studentName: 'سارة حسني',
          status: 'absent',
          note: 'مرض',
        ),
      ];

      await attendanceRepo.saveRecords(
        sessionId: sessionId,
        records: recordsToSave,
      );

      // Verify records are persisted in SQLite
      final updatedRoster = await attendanceRepo.getSessionRoster(sessionId, classId);
      final r1 = updatedRoster.firstWhere((r) => r.studentId == studentId1);
      final r2 = updatedRoster.firstWhere((r) => r.studentId == studentId2);
      expect(r1.status, 'present');
      expect(r2.status, 'absent');
      expect(r2.note, 'مرض');

      // Verify audit trail entry was recorded
      final auditEntries = await db.select(db.auditEntries).get();
      expect(auditEntries.any((a) => a.action == 'save_attendance' && a.entityId == '${sessionId}_$studentId1'), isTrue);

      // Verify sync queue entries exist
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems.any((q) => q.entityType == 'attendance_records'), isTrue);
    });

    test('GradebookRepository: create assessment, save results, and enforce score <= maxScore', () async {
      final classId = await classesRepo.createClass(
        name: '1 ج م أ 1',
        level: 'الأولى ثانوي',
        subjectName: 'اللغة العربية',
      );

      final studentId = await studentsRepo.createStudent(
        firstName: 'يوسف',
        lastName: 'قاسم',
        externalRef: 'ST-020',
        classId: classId,
      );

      final assessmentId = await gradebookRepo.createAssessment(
        classId: classId,
        title: 'فرض محروس رقم 1',
        kind: 'test',
        assessedOn: DateTime.now(),
        maxScore: 20.0,
        coefficient: 2.0,
      );

      expect(assessmentId, isNotEmpty);

      final assessment = await gradebookRepo.getAssessment(assessmentId);
      expect(assessment, isNotNull);
      expect(assessment!.title, 'فرض محروس رقم 1');
      expect(assessment.maxScore, 20.0);
      expect(assessment.coefficient, 2.0);

      // Attempt saving invalid score > maxScore: must throw ArgumentError
      final invalidResults = [
        GradeResultItem(
          studentId: studentId,
          studentName: 'يوسف قاسم',
          score: 25.0, // > 20.0
        ),
      ];

      expect(
        () async => await gradebookRepo.saveResults(
          assessmentId: assessmentId,
          maxScore: 20.0,
          results: invalidResults,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Save valid score
      final validResults = [
        GradeResultItem(
          studentId: studentId,
          studentName: 'يوسف قاسم',
          score: 17.5,
        ),
      ];

      await gradebookRepo.saveResults(
        assessmentId: assessmentId,
        maxScore: 20.0,
        results: validResults,
      );

      final loadedResults = await gradebookRepo.getAssessmentResults(assessmentId, classId);
      expect(loadedResults.length, 1);
      expect(loadedResults.first.score, 17.5);
      expect(loadedResults.first.status, 'graded');

      // Verify audit entry for assessment
      final auditEntries = await db.select(db.auditEntries).get();
      expect(auditEntries.any((a) => a.action == 'save_grade' && a.entityId == '${assessmentId}_$studentId'), isTrue);
    });

    test('SyncEngine: reports pending mutations count accurately', () async {
      final initialCount = await syncEngine.pendingMutationsCount();
      expect(initialCount, 0);

      await classesRepo.createClass(
        name: 'قسم تجريبي',
        level: 'مستوى',
        subjectName: 'مادة',
      );

      final afterCount = await syncEngine.pendingMutationsCount();
      expect(afterCount, greaterThan(0));
    });
  });
}
