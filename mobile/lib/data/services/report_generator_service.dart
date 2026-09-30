import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../repositories/analytics_repository.dart';

class BulletinGradeEntry {
  const BulletinGradeEntry({
    required this.assessmentId,
    required this.title,
    required this.kind,
    required this.score,
    required this.maxScore,
    required this.normalized20,
    required this.coefficient,
    required this.weightedPoints,
    this.date,
  });

  final String assessmentId;
  final String title;
  final String kind;
  final double score;
  final double maxScore;
  final double normalized20;
  final double coefficient;
  final double weightedPoints;
  final DateTime? date;
}

class StudentBulletinData {
  const StudentBulletinData({
    required this.schoolName,
    required this.teacherName,
    required this.academicYear,
    required this.className,
    required this.term,
    required this.studentId,
    required this.studentName,
    this.registrationNumber,
    required this.grades,
    required this.totalCoefficient,
    required this.totalWeightedPoints,
    required this.generalAverage,
    required this.rankInClass,
    required this.totalStudentsInClass,
    required this.classHighestAverage,
    required this.classLowestAverage,
    required this.classOverallAverage,
    required this.absentCount,
    required this.lateCount,
    required this.honorRoll,
    required this.teacherAppreciation,
  });

  final String schoolName;
  final String teacherName;
  final String academicYear;
  final String className;
  final String term;
  final String studentId;
  final String studentName;
  final String? registrationNumber;
  final List<BulletinGradeEntry> grades;
  final double totalCoefficient;
  final double totalWeightedPoints;
  final double generalAverage;
  final int rankInClass;
  final int totalStudentsInClass;
  final double classHighestAverage;
  final double classLowestAverage;
  final double classOverallAverage;
  final int absentCount;
  final int lateCount;
  final String honorRoll;
  final String teacherAppreciation;
}

class ClassSummaryReportData {
  const ClassSummaryReportData({
    required this.schoolName,
    required this.teacherName,
    required this.academicYear,
    required this.className,
    required this.term,
    required this.analytics,
    required this.studentsRoster,
  });

  final String schoolName;
  final String teacherName;
  final String academicYear;
  final String className;
  final String term;
  final ClassAnalytics analytics;
  final List<ClassSummaryStudentItem> studentsRoster;
}

class ClassSummaryStudentItem {
  const ClassSummaryStudentItem({
    required this.rank,
    required this.studentId,
    required this.name,
    this.registrationNumber,
    required this.averageScore,
    required this.absentCount,
    required this.honorRoll,
  });

  final int rank;
  final String studentId;
  final String name;
  final String? registrationNumber;
  final double averageScore;
  final int absentCount;
  final String honorRoll;
}

class CertificateData {
  const CertificateData({
    required this.schoolName,
    required this.teacherName,
    required this.academicYear,
    required this.studentName,
    required this.className,
    required this.title,
    required this.reason,
    required this.averageScore,
    required this.date,
  });

  final String schoolName;
  final String teacherName;
  final String academicYear;
  final String studentName;
  final String className;
  final String title;
  final String reason;
  final double averageScore;
  final DateTime date;
}

class ReportGeneratorService {
  ReportGeneratorService(this.db, this.analyticsRepo);

  final AppDatabase db;
  final AnalyticsRepository analyticsRepo;

  String _determineHonorRoll(double average) {
    if (average >= 17.0) return 'امتياز';
    if (average >= 15.0) return 'تهنئة';
    if (average >= 13.0) return 'لوحة شرف';
    if (average >= 10.0) return 'تشجيع';
    return 'إنذار وتنبيه';
  }

  String _determineAppreciation(double average) {
    if (average >= 16.0) return 'نتائج ممتازة جداً وسلوك مثالي، واصل على هذا التألق.';
    if (average >= 14.0) return 'مستوى متميز ومجهود جاد ومثمر، يمكن تحقيق الأفضل.';
    if (average >= 12.0) return 'نتائج حسنة ومجهود طيب، يُرجى مضاعفة التركيز.';
    if (average >= 10.0) return 'مستوى متوسط ومقبول، يتطلب المزيد من الاجتهاد والمثابرة.';
    return 'نتائج دون العتبة المطلوبة، يجب التدارك العاجل والالتزام بالمراجعة المستمرة.';
  }

  Future<StudentBulletinData> generateStudentBulletin({
    required String classId,
    required String studentId,
    String term = 'الفصل الأول',
  }) async {
    // 1. Fetch Class & Student
    final schoolClass = await (db.select(db.classes)..where((c) => c.id.equals(classId) & c.deletedAt.isNull())).getSingle();
    final student = await (db.select(db.students)..where((s) => s.id.equals(studentId) & s.deletedAt.isNull())).getSingle();

    // 2. Fetch Academic Year
    final currAy = await (db.select(db.academicYears)..where((ay) => ay.isCurrent.equals(true) & ay.deletedAt.isNull())).getSingleOrNull();
    final ayLabel = currAy?.label ?? '2026-2027';

    // 3. Class Analytics for class highest, lowest, avg, rank
    final classAnalytics = await analyticsRepo.getClassAnalytics(classId);

    // 4. Assessments in class
    final assessments = await (db.select(db.assessments)
          ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.assessedOn)]))
        .get();

    final results = await (db.select(db.assessmentResults)
          ..where((r) => r.studentId.equals(studentId) & r.deletedAt.isNull() & r.score.isNotNull()))
        .get();
    final resultsMap = {for (final r in results) r.assessmentId: r};

    final gradeEntries = <BulletinGradeEntry>[];
    var totalCoef = 0.0;
    var totalWeighted = 0.0;

    for (final a in assessments) {
      final res = resultsMap[a.id];
      if (res != null && res.score != null && a.maxScore > 0) {
        final norm = (res.score! / a.maxScore) * 20.0;
        final coef = a.coefficient > 0 ? a.coefficient : 1.0;
        final weighted = norm * coef;

        gradeEntries.add(
          BulletinGradeEntry(
            assessmentId: a.id,
            title: a.title,
            kind: a.kind,
            score: res.score!,
            maxScore: a.maxScore,
            normalized20: double.parse(norm.toStringAsFixed(2)),
            coefficient: coef,
            weightedPoints: double.parse(weighted.toStringAsFixed(2)),
            date: a.assessedOn,
          ),
        );

        totalCoef += coef;
        totalWeighted += weighted;
      }
    }

    final genAvg = totalCoef > 0 ? totalWeighted / totalCoef : 0.0;

    // Student rank from class analytics
    var myRank = 1;
    for (var i = 0; i < classAnalytics.topStudents.length; i++) {
      if (classAnalytics.topStudents[i].studentId == studentId) {
        myRank = classAnalytics.topStudents[i].rank ?? (i + 1);
        break;
      }
    }

    // Attendance
    final records = await (db.select(db.attendanceRecords)..where((r) => r.studentId.equals(studentId) & r.deletedAt.isNull())).get();
    final absences = records.where((r) => r.status == 'absent').length;
    final lates = records.where((r) => r.status == 'late').length;

    return StudentBulletinData(
      schoolName: 'الجمهورية الجزائرية الديمقراطية الشعبية — وزارة التربية الوطنية',
      teacherName: 'الأستاذ المشرف',
      academicYear: ayLabel,
      className: schoolClass.name,
      term: term,
      studentId: student.id,
      studentName: '${student.firstName} ${student.lastName}',
      registrationNumber: student.externalRef,
      grades: gradeEntries,
      totalCoefficient: totalCoef,
      totalWeightedPoints: double.parse(totalWeighted.toStringAsFixed(2)),
      generalAverage: double.parse(genAvg.toStringAsFixed(2)),
      rankInClass: myRank,
      totalStudentsInClass: classAnalytics.studentCount,
      classHighestAverage: classAnalytics.maxScore,
      classLowestAverage: classAnalytics.minScore,
      classOverallAverage: classAnalytics.averageScore,
      absentCount: absences,
      lateCount: lates,
      honorRoll: _determineHonorRoll(genAvg),
      teacherAppreciation: _determineAppreciation(genAvg),
    );
  }

  Future<ClassSummaryReportData> generateClassSummary({
    required String classId,
    String term = 'الفصل الأول',
  }) async {
    final schoolClass = await (db.select(db.classes)..where((c) => c.id.equals(classId) & c.deletedAt.isNull())).getSingle();
    final currAy = await (db.select(db.academicYears)..where((ay) => ay.isCurrent.equals(true) & ay.deletedAt.isNull())).getSingleOrNull();
    final ayLabel = currAy?.label ?? '2026-2027';

    final analytics = await analyticsRepo.getClassAnalytics(classId);

    // Roster with details
    final roster = <ClassSummaryStudentItem>[];
    for (var i = 0; i < analytics.topStudents.length; i++) {
      final s = analytics.topStudents[i];
      final st = await (db.select(db.students)..where((row) => row.id.equals(s.studentId))).getSingleOrNull();
      final records = await (db.select(db.attendanceRecords)..where((r) => r.studentId.equals(s.studentId) & r.deletedAt.isNull())).get();
      final abs = records.where((r) => r.status == 'absent').length;

      roster.add(
        ClassSummaryStudentItem(
          rank: i + 1,
          studentId: s.studentId,
          name: s.name,
          registrationNumber: st?.externalRef,
          averageScore: s.averageScore,
          absentCount: abs,
          honorRoll: _determineHonorRoll(s.averageScore),
        ),
      );
    }

    return ClassSummaryReportData(
      schoolName: 'الجمهورية الجزائرية الديمقراطية الشعبية — وزارة التربية الوطنية',
      teacherName: 'الأستاذ المشرف',
      academicYear: ayLabel,
      className: schoolClass.name,
      term: term,
      analytics: analytics,
      studentsRoster: roster,
    );
  }

  Future<CertificateData> generateCertificate({
    required String studentId,
    required String classId,
    String title = 'شهادة تفوق وتقدير',
  }) async {
    final student = await (db.select(db.students)..where((s) => s.id.equals(studentId))).getSingle();
    final schoolClass = await (db.select(db.classes)..where((c) => c.id.equals(classId))).getSingle();
    final currAy = await (db.select(db.academicYears)..where((ay) => ay.isCurrent.equals(true) & ay.deletedAt.isNull())).getSingleOrNull();

    final sAnalytics = await analyticsRepo.getStudentAnalytics(studentId);

    var reason = 'نظير انضباطه المتميز ونتائجه الدراسية الباهرة ومثابرته في التحصيل العلمي.';
    if (sAnalytics.averageScore < 12.0) {
      reason = 'تشجيعاً له على مجهوداته المبذولة وتحفيزاً له على مواصلة الاجتهاد والتفوق.';
    }

    return CertificateData(
      schoolName: 'ثانوية المتفوقين',
      teacherName: 'أستاذ المادة',
      academicYear: currAy?.label ?? '2026-2027',
      studentName: '${student.firstName} ${student.lastName}',
      className: schoolClass.name,
      title: title,
      reason: reason,
      averageScore: sAnalytics.averageScore,
      date: DateTime.now(),
    );
  }
}
