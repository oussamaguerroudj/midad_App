import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/data/local/app_database.dart';
import 'package:midad/data/repositories/academic_years_repository.dart';
import 'package:midad/data/repositories/analytics_repository.dart';
import 'package:midad/data/repositories/attendance_repository.dart';
import 'package:midad/data/repositories/classes_repository.dart';
import 'package:midad/data/repositories/gradebook_repository.dart';
import 'package:midad/data/repositories/students_repository.dart';
import 'package:midad/data/services/import_export_service.dart';
import 'package:midad/data/services/report_generator_service.dart';

void main() {
  late AppDatabase db;
  late AnalyticsRepository analyticsRepo;
  late ReportGeneratorService reportService;
  late ImportExportService importExportService;
  late ClassesRepository classesRepo;
  late StudentsRepository studentsRepo;
  late AttendanceRepository attendanceRepo;
  late GradebookRepository gradebookRepo;
  late AcademicYearsRepository ayRepo;

  setUp(() {
    db = AppDatabase.inMemory();
    analyticsRepo = AnalyticsRepository(db);
    reportService = ReportGeneratorService(db, analyticsRepo);
    importExportService = ImportExportService(db, analyticsRepo);

    final dio = Dio();
    classesRepo = ClassesRepository(db: db, dio: dio);
    studentsRepo = StudentsRepository(db: db, dio: dio);
    attendanceRepo = AttendanceRepository(db: db, dio: dio);
    gradebookRepo = GradebookRepository(db: db, dio: dio);
    ayRepo = AcademicYearsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 4 Analytics & Reports Offline-First Tests', () {
    test('ImportExportService: parses CSV with Arabic headers and imports students', () async {
      final classId = await classesRepo.createClass(
        name: '3 AS Math 1',
        level: '3AS',
        subjectName: 'الرياضيات',
      );

      const csvData = '''رقم_التسجيل,اللقب,الاسم
2026-001,بن علي,سارة
2026-002,قاسمي,أحمد
2026-003,منصوري,فاطمة''';

      final parsed = importExportService.parseCsvRoster(csvData);
      expect(parsed.length, 3);
      expect(parsed[0].firstName, 'سارة');
      expect(parsed[0].lastName, 'بن علي');
      expect(parsed[0].registrationNumber, '2026-001');

      final result = await importExportService.importRoster(classId: classId, students: parsed);
      expect(result.totalCreated, 3);
      expect(result.totalSkipped, 0);

      // Verify students enrolled in class
      final students = await studentsRepo.watchStudents(classId: classId).first;
      expect(students.length, 3);
    });

    test('AnalyticsRepository: computes class metrics, distribution, and student analytics', () async {
      await ayRepo.createAcademicYear(
        label: '2026-2027',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2027, 6, 30),
        isCurrent: true,
      );

      final classId = await classesRepo.createClass(
        name: '2 AS Sciences 1',
        level: '2AS',
        subjectName: 'الفيزياء',
      );

      final s1Id = await studentsRepo.createStudent(firstName: 'سارة', lastName: 'بن علي', classId: classId);
      final s2Id = await studentsRepo.createStudent(firstName: 'أحمد', lastName: 'قاسمي', classId: classId);
      final s3Id = await studentsRepo.createStudent(firstName: 'فاطمة', lastName: 'منصوري', classId: classId);

      // Attendance
      final sessionId = await attendanceRepo.createOrGetSession(
        classId: classId,
        date: DateTime(2026, 10, 1),
      );

      await attendanceRepo.saveRecords(
        sessionId: sessionId,
        records: [
          AttendanceRecordItem(studentId: s1Id, studentName: 'سارة بن علي', status: 'present'),
          AttendanceRecordItem(studentId: s2Id, studentName: 'أحمد قاسمي', status: 'late'),
          AttendanceRecordItem(studentId: s3Id, studentName: 'فاطمة منصوري', status: 'absent'),
        ],
      );

      // Add 2 more sessions where s3 is absent to trigger at-risk attendance threshold (>= 3 absences)
      for (var i = 2; i <= 3; i++) {
        final sid = await attendanceRepo.createOrGetSession(classId: classId, date: DateTime(2026, 10, i));
        await attendanceRepo.saveRecords(
          sessionId: sid,
          records: [
            AttendanceRecordItem(studentId: s1Id, studentName: 'سارة', status: 'present'),
            AttendanceRecordItem(studentId: s2Id, studentName: 'أحمد', status: 'present'),
            AttendanceRecordItem(studentId: s3Id, studentName: 'فاطمة', status: 'absent'),
          ],
        );
      }

      // Assessments
      final a1Id = await gradebookRepo.createAssessment(
        classId: classId,
        title: 'فرض الثلاثي 1',
        kind: 'test',
        assessedOn: DateTime(2026, 10, 15),
        maxScore: 20.0,
        coefficient: 1.0,
      );
      await gradebookRepo.saveResults(
        assessmentId: a1Id,
        maxScore: 20.0,
        results: [
          GradeResultItem(studentId: s1Id, studentName: 'سارة', score: 18.0),
          GradeResultItem(studentId: s2Id, studentName: 'أحمد', score: 12.0),
          GradeResultItem(studentId: s3Id, studentName: 'فاطمة', score: 6.0),
        ],
      );

      // Test Class Analytics
      final cAnalytics = await analyticsRepo.getClassAnalytics(classId);
      expect(cAnalytics.studentCount, 3);
      expect(cAnalytics.averageScore, 12.0);
      expect(cAnalytics.maxScore, 18.0);
      expect(cAnalytics.minScore, 6.0);
      expect(cAnalytics.passRatePercent, 66.7); // 2 out of 3 >= 10
      expect(cAnalytics.buckets.length, 5);
      expect(cAnalytics.topStudents.first.studentId, s1Id);
      expect(cAnalytics.topStudents.first.rank, 1);

      // Check At-Risk detection
      expect(cAnalytics.atRiskStudents.length, 1);
      expect(cAnalytics.atRiskStudents.first.studentId, s3Id);
      expect(cAnalytics.atRiskStudents.first.absentCount, 3);

      // Test Student Analytics
      final s1Analytics = await analyticsRepo.getStudentAnalytics(s1Id);
      expect(s1Analytics.studentName, 'سارة بن علي');
      expect(s1Analytics.averageScore, 18.0);
      expect(s1Analytics.rankInClass, 1);
      expect(s1Analytics.strengths.isNotEmpty, true);

      final s3Analytics = await analyticsRepo.getStudentAnalytics(s3Id);
      expect(s3Analytics.averageScore, 6.0);
      expect(s3Analytics.absentCount, 3);
      expect(s3Analytics.areasForGrowth.isNotEmpty, true);

      // Test Overview Analytics
      final overview = await analyticsRepo.getOverview();
      expect(overview.totalStudents, 3);
      expect(overview.totalClasses, 1);
      expect(overview.totalAssessments, 1);
      expect(overview.totalSessions, 3);
      expect(overview.totalAtRisk, 1);
    });

    test('ReportGeneratorService: generates student bulletin with official weighted scores', () async {
      await ayRepo.createAcademicYear(
        label: '2026-2027',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2027, 6, 30),
        isCurrent: true,
      );

      final classId = await classesRepo.createClass(
        name: '4 AM 3',
        level: '4AM',
        subjectName: 'التاريخ والجغرافيا',
      );
      final sId = await studentsRepo.createStudent(firstName: 'مريم', lastName: 'سعيداني', classId: classId);

      final aId = await gradebookRepo.createAssessment(
        classId: classId,
        title: 'امتحان تجريبي',
        kind: 'exam',
        assessedOn: DateTime(2026, 11, 1),
        maxScore: 20.0,
        coefficient: 2.0,
      );
      await gradebookRepo.saveResults(
        assessmentId: aId,
        maxScore: 20.0,
        results: [
          GradeResultItem(studentId: sId, studentName: 'مريم سعيداني', score: 17.5),
        ],
      );

      final bulletin = await reportService.generateStudentBulletin(
        classId: classId,
        studentId: sId,
        term: 'الفصل الأول',
      );

      expect(bulletin.studentName, 'مريم سعيداني');
      expect(bulletin.generalAverage, 17.5);
      expect(bulletin.honorRoll, 'امتياز');
      expect(bulletin.grades.length, 1);
      expect(bulletin.grades.first.weightedPoints, 35.0);

      // Certificate Generation
      final cert = await reportService.generateCertificate(studentId: sId, classId: classId);
      expect(cert.studentName, 'مريم سعيداني');
      expect(cert.averageScore, 17.5);

      // Export CSV
      final rosterCsv = await importExportService.exportStudentsRosterCsv(classId);
      expect(rosterCsv.contains('سعيداني'), true);
      expect(rosterCsv.contains('17.50'), true);

      final gradesCsv = await importExportService.exportGradebookMatrixCsv(classId);
      expect(gradesCsv.contains('امتحان تجريبي'), true);
      expect(gradesCsv.contains('17.50'), true);
    });
  });
}
