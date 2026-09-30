import 'package:drift/drift.dart';

import '../local/app_database.dart';

class GradeBucket {
  const GradeBucket({
    required this.key,
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String key;
  final String label;
  final int count;
  final double percentage;
}

class StudentPerformance {
  const StudentPerformance({
    required this.studentId,
    required this.name,
    required this.averageScore,
    this.rank,
  });

  final String studentId;
  final String name;
  final double averageScore;
  final int? rank;
}

class AtRiskStudent {
  const AtRiskStudent({
    required this.studentId,
    required this.name,
    this.averageScore,
    required this.absentCount,
    required this.reason,
    required this.severity,
  });

  final String studentId;
  final String name;
  final double? averageScore;
  final int absentCount;
  final String reason;
  final String severity; // 'warning' or 'danger'
}

class AssessmentTrend {
  const AssessmentTrend({
    required this.id,
    required this.title,
    required this.kind,
    required this.maxScore,
    required this.averageScore,
    this.date,
  });

  final String id;
  final String title;
  final String kind;
  final double maxScore;
  final double averageScore;
  final DateTime? date;
}

class ClassAnalytics {
  const ClassAnalytics({
    required this.classId,
    required this.className,
    required this.studentCount,
    required this.averageScore,
    required this.minScore,
    required this.maxScore,
    required this.passRatePercent,
    required this.buckets,
    required this.attendanceRatePercent,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.topStudents,
    required this.atRiskStudents,
    required this.assessmentTrends,
  });

  final String classId;
  final String className;
  final int studentCount;
  final double averageScore;
  final double minScore;
  final double maxScore;
  final double passRatePercent;
  final List<GradeBucket> buckets;
  final double attendanceRatePercent;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final List<StudentPerformance> topStudents;
  final List<AtRiskStudent> atRiskStudents;
  final List<AssessmentTrend> assessmentTrends;
}

class ClassSummaryItem {
  const ClassSummaryItem({
    required this.classId,
    required this.className,
    required this.studentCount,
    required this.averageScore,
    required this.attendanceRatePercent,
    required this.atRiskCount,
  });

  final String classId;
  final String className;
  final int studentCount;
  final double averageScore;
  final double attendanceRatePercent;
  final int atRiskCount;
}

class OverviewAnalytics {
  const OverviewAnalytics({
    required this.totalStudents,
    required this.totalClasses,
    required this.totalAssessments,
    required this.totalSessions,
    required this.overallAttendanceRate,
    required this.overallAverageScore,
    required this.totalAtRisk,
    required this.classes,
  });

  final int totalStudents;
  final int totalClasses;
  final int totalAssessments;
  final int totalSessions;
  final double overallAttendanceRate;
  final double overallAverageScore;
  final int totalAtRisk;
  final List<ClassSummaryItem> classes;
}

class StudentAssessmentHistoryItem {
  const StudentAssessmentHistoryItem({
    required this.assessmentId,
    required this.title,
    required this.kind,
    required this.maxScore,
    this.score,
    this.normalized20,
    this.classAverage,
    this.date,
  });

  final String assessmentId;
  final String title;
  final String kind;
  final double maxScore;
  final double? score;
  final double? normalized20;
  final double? classAverage;
  final DateTime? date;
}

class StudentAnalytics {
  const StudentAnalytics({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.averageScore,
    required this.rankInClass,
    required this.totalStudentsInClass,
    required this.attendanceRatePercent,
    required this.absentCount,
    required this.lateCount,
    required this.assessmentHistory,
    required this.strengths,
    required this.areasForGrowth,
  });

  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final double averageScore;
  final int rankInClass;
  final int totalStudentsInClass;
  final double attendanceRatePercent;
  final int absentCount;
  final int lateCount;
  final List<StudentAssessmentHistoryItem> assessmentHistory;
  final List<String> strengths;
  final List<String> areasForGrowth;
}

class AnalyticsRepository {
  AnalyticsRepository(this.db);

  final AppDatabase db;

  Future<OverviewAnalytics> getOverview() async {
    final classesList = await (db.select(db.classes)..where((c) => c.deletedAt.isNull())).get();
    final studentsList = await (db.select(db.students)..where((s) => s.deletedAt.isNull())).get();
    final assessmentsList = await (db.select(db.assessments)..where((a) => a.deletedAt.isNull())).get();
    final sessionsList = await (db.select(db.attendanceSessions)..where((s) => s.deletedAt.isNull())).get();
    final recordsList = await (db.select(db.attendanceRecords)..where((r) => r.deletedAt.isNull())).get();

    final totalAttRecords = recordsList.length;
    final presentOrLate = recordsList.where((r) => r.status == 'present' || r.status == 'late').length;
    final globalAttRate = totalAttRecords > 0 ? (presentOrLate / totalAttRecords) * 100.0 : 0.0;

    // All grades normalized
    final allResults = await (db.select(db.assessmentResults)..where((r) => r.deletedAt.isNull() & r.score.isNotNull())).get();
    final assessmentMap = {for (final a in assessmentsList) a.id: a};

    final allNormScores = <double>[];
    for (final r in allResults) {
      final ass = assessmentMap[r.assessmentId];
      if (ass != null && ass.maxScore > 0 && r.score != null) {
        allNormScores.add((r.score! / ass.maxScore) * 20.0);
      }
    }
    final overallAvg = allNormScores.isNotEmpty ? allNormScores.reduce((a, b) => a + b) / allNormScores.length : 0.0;

    final classSummaries = <ClassSummaryItem>[];
    var globalAtRisk = 0;

    for (final c in classesList) {
      final analytics = await getClassAnalytics(c.id);
      globalAtRisk += analytics.atRiskStudents.length;
      classSummaries.add(
        ClassSummaryItem(
          classId: c.id,
          className: c.name,
          studentCount: analytics.studentCount,
          averageScore: analytics.averageScore,
          attendanceRatePercent: analytics.attendanceRatePercent,
          atRiskCount: analytics.atRiskStudents.length,
        ),
      );
    }

    return OverviewAnalytics(
      totalStudents: studentsList.length,
      totalClasses: classesList.length,
      totalAssessments: assessmentsList.length,
      totalSessions: sessionsList.length,
      overallAttendanceRate: double.parse(globalAttRate.toStringAsFixed(1)),
      overallAverageScore: double.parse(overallAvg.toStringAsFixed(2)),
      totalAtRisk: globalAtRisk,
      classes: classSummaries,
    );
  }

  Future<ClassAnalytics> getClassAnalytics(String classId) async {
    final schoolClass = await (db.select(db.classes)..where((c) => c.id.equals(classId) & c.deletedAt.isNull())).getSingleOrNull();
    final className = schoolClass?.name ?? 'القسم';

    // Students enrolled in class
    final links = await (db.select(db.classStudents)..where((cs) => cs.classId.equals(classId) & cs.deletedAt.isNull())).get();
    final studentIds = links.map((l) => l.studentId).toSet();

    final students = studentIds.isEmpty
        ? <Student>[]
        : await (db.select(db.students)..where((s) => s.id.isIn(studentIds) & s.deletedAt.isNull())).get();

    // Assessments
    final assessments = await (db.select(db.assessments)
          ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.assessedOn)]))
        .get();
    final assessmentIds = assessments.map((a) => a.id).toSet();
    final assessmentMap = {for (final a in assessments) a.id: a};

    // Results
    final results = assessmentIds.isEmpty
        ? <AssessmentResult>[]
        : await (db.select(db.assessmentResults)
              ..where((r) => r.assessmentId.isIn(assessmentIds) & r.deletedAt.isNull() & r.score.isNotNull()))
            .get();

    final studentScoresMap = <String, List<double>>{};
    final assessmentScoresMap = <String, List<double>>{};
    final allScores = <double>[];

    for (final r in results) {
      final ass = assessmentMap[r.assessmentId];
      if (ass != null && ass.maxScore > 0 && r.score != null) {
        final norm = (r.score! / ass.maxScore) * 20.0;
        studentScoresMap.putIfAbsent(r.studentId, () => []).add(norm);
        assessmentScoresMap.putIfAbsent(r.assessmentId, () => []).add(norm);
        allScores.add(norm);
      }
    }

    final avgScore = allScores.isNotEmpty ? allScores.reduce((a, b) => a + b) / allScores.length : 0.0;
    final minScore = allScores.isNotEmpty ? allScores.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxScore = allScores.isNotEmpty ? allScores.reduce((a, b) => a > b ? a : b) : 0.0;

    // Student performance items
    final performances = <StudentPerformance>[];
    for (final s in students) {
      final scs = studentScoresMap[s.id] ?? [];
      final sAvg = scs.isNotEmpty ? scs.reduce((a, b) => a + b) / scs.length : 0.0;
      performances.add(
        StudentPerformance(
          studentId: s.id,
          name: '${s.firstName} ${s.lastName}',
          averageScore: double.parse(sAvg.toStringAsFixed(2)),
        ),
      );
    }
    performances.sort((a, b) => b.averageScore.compareTo(a.averageScore));
    final rankedPerformances = <StudentPerformance>[];
    for (var i = 0; i < performances.length; i++) {
      final p = performances[i];
      rankedPerformances.add(
        StudentPerformance(
          studentId: p.studentId,
          name: p.name,
          averageScore: p.averageScore,
          rank: i + 1,
        ),
      );
    }

    // Pass rate
    final passCount = rankedPerformances.where((p) => p.averageScore >= 10.0).length;
    final passRate = rankedPerformances.isNotEmpty ? (passCount / rankedPerformances.length) * 100.0 : 0.0;

    // Grade Distribution Buckets
    var bBelow10 = 0;
    var bAverage = 0;
    var bGood = 0;
    var bVeryGood = 0;
    var bExcellent = 0;

    for (final p in rankedPerformances) {
      if (p.averageScore < 10.0) {
        bBelow10++;
      } else if (p.averageScore < 12.0) {
        bAverage++;
      } else if (p.averageScore < 14.0) {
        bGood++;
      } else if (p.averageScore < 16.0) {
        bVeryGood++;
      } else {
        bExcellent++;
      }
    }

    final totalP = rankedPerformances.isEmpty ? 1 : rankedPerformances.length;
    final buckets = [
      GradeBucket(
        key: 'below_10',
        label: 'دون المتوسط (< 10)',
        count: bBelow10,
        percentage: double.parse(((bBelow10 / totalP) * 100.0).toStringAsFixed(1)),
      ),
      GradeBucket(
        key: 'average',
        label: 'متوسط (10 - 11.99)',
        count: bAverage,
        percentage: double.parse(((bAverage / totalP) * 100.0).toStringAsFixed(1)),
      ),
      GradeBucket(
        key: 'good',
        label: 'حسن (12 - 13.99)',
        count: bGood,
        percentage: double.parse(((bGood / totalP) * 100.0).toStringAsFixed(1)),
      ),
      GradeBucket(
        key: 'very_good',
        label: 'جيد جداً (14 - 15.99)',
        count: bVeryGood,
        percentage: double.parse(((bVeryGood / totalP) * 100.0).toStringAsFixed(1)),
      ),
      GradeBucket(
        key: 'excellent',
        label: 'ممتاز (16 - 20)',
        count: bExcellent,
        percentage: double.parse(((bExcellent / totalP) * 100.0).toStringAsFixed(1)),
      ),
    ];

    // Attendance stats
    final sessions = await (db.select(db.attendanceSessions)..where((s) => s.classId.equals(classId) & s.deletedAt.isNull())).get();
    final sessionIds = sessions.map((s) => s.id).toSet();

    final attRecords = sessionIds.isEmpty
        ? <AttendanceRecord>[]
        : await (db.select(db.attendanceRecords)..where((r) => r.sessionId.isIn(sessionIds) & r.deletedAt.isNull())).get();

    var presentC = 0;
    var absentC = 0;
    var lateC = 0;
    var excusedC = 0;

    final studentAbsencesMap = <String, int>{};

    for (final r in attRecords) {
      switch (r.status) {
        case 'present':
          presentC++;
          break;
        case 'absent':
          absentC++;
          studentAbsencesMap[r.studentId] = (studentAbsencesMap[r.studentId] ?? 0) + 1;
          break;
        case 'late':
          lateC++;
          studentAbsencesMap[r.studentId] = (studentAbsencesMap[r.studentId] ?? 0) + 1;
          break;
        case 'excused':
          excusedC++;
          break;
      }
    }

    final totalAtt = attRecords.length;
    final attRate = totalAtt > 0 ? ((presentC + lateC) / totalAtt) * 100.0 : 0.0;

    // At-Risk Students
    final atRiskList = <AtRiskStudent>[];
    for (final p in rankedPerformances) {
      final abs = studentAbsencesMap[p.studentId] ?? 0;
      final reasons = <String>[];
      if (abs >= 5) {
        reasons.add('غياب متكرر ($abs حصص)');
      } else if (abs >= 3) {
        reasons.add('تنبيه غياب ($abs حصص)');
      }
      if (p.averageScore < 10.0) {
        reasons.add('معدل تحصيلي ضعيف (${p.averageScore}/20)');
      }

      if (reasons.isNotEmpty) {
        final severity = (abs >= 5 || p.averageScore < 8.0) ? 'danger' : 'warning';
        atRiskList.add(
          AtRiskStudent(
            studentId: p.studentId,
            name: p.name,
            averageScore: p.averageScore,
            absentCount: abs,
            reason: reasons.join(' • '),
            severity: severity,
          ),
        );
      }
    }

    // Assessment Trends
    final trends = <AssessmentTrend>[];
    for (final a in assessments) {
      final aScs = assessmentScoresMap[a.id] ?? [];
      final aAvg = aScs.isNotEmpty ? aScs.reduce((x, y) => x + y) / aScs.length : 0.0;
      trends.add(
        AssessmentTrend(
          id: a.id,
          title: a.title,
          kind: a.kind,
          maxScore: a.maxScore,
          averageScore: double.parse(aAvg.toStringAsFixed(2)),
          date: a.assessedOn,
        ),
      );
    }

    return ClassAnalytics(
      classId: classId,
      className: className,
      studentCount: students.length,
      averageScore: double.parse(avgScore.toStringAsFixed(2)),
      minScore: double.parse(minScore.toStringAsFixed(2)),
      maxScore: double.parse(maxScore.toStringAsFixed(2)),
      passRatePercent: double.parse(passRate.toStringAsFixed(1)),
      buckets: buckets,
      attendanceRatePercent: double.parse(attRate.toStringAsFixed(1)),
      presentCount: presentC,
      absentCount: absentC,
      lateCount: lateC,
      excusedCount: excusedC,
      topStudents: rankedPerformances.take(5).toList(),
      atRiskStudents: atRiskList,
      assessmentTrends: trends,
    );
  }

  Future<StudentAnalytics> getStudentAnalytics(String studentId) async {
    final student = await (db.select(db.students)..where((s) => s.id.equals(studentId) & s.deletedAt.isNull())).getSingle();
    final link = await (db.select(db.classStudents)..where((cs) => cs.studentId.equals(studentId) & cs.deletedAt.isNull())).getSingleOrNull();

    final classId = link?.classId ?? '';
    final schoolClass = classId.isNotEmpty
        ? await (db.select(db.classes)..where((c) => c.id.equals(classId) & c.deletedAt.isNull())).getSingleOrNull()
        : null;
    final className = schoolClass?.name ?? 'بدون قسم';

    // Peers in same class for rank calculation
    final peerLinks = classId.isNotEmpty
        ? await (db.select(db.classStudents)..where((cs) => cs.classId.equals(classId) & cs.deletedAt.isNull())).get()
        : <ClassStudent>[];
    final peerIds = peerLinks.map((p) => p.studentId).toSet();

    // Assessments
    final assessments = classId.isNotEmpty
        ? await (db.select(db.assessments)
              ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
              ..orderBy([(a) => OrderingTerm.asc(a.assessedOn)]))
            .get()
        : <Assessment>[];
    final assessmentIds = assessments.map((a) => a.id).toSet();
    final assessmentMap = {for (final a in assessments) a.id: a};

    final results = assessmentIds.isEmpty
        ? <AssessmentResult>[]
        : await (db.select(db.assessmentResults)
              ..where((r) => r.assessmentId.isIn(assessmentIds) & r.deletedAt.isNull() & r.score.isNotNull()))
            .get();

    final peerScores = <String, List<double>>{};
    final assessmentScores = <String, List<double>>{};
    final myResultsMap = <String, AssessmentResult>{};

    for (final r in results) {
      final ass = assessmentMap[r.assessmentId];
      if (ass != null && ass.maxScore > 0 && r.score != null) {
        final norm = (r.score! / ass.maxScore) * 20.0;
        peerScores.putIfAbsent(r.studentId, () => []).add(norm);
        assessmentScores.putIfAbsent(r.assessmentId, () => []).add(norm);
        if (r.studentId == studentId) {
          myResultsMap[r.assessmentId] = r;
        }
      }
    }

    final history = <StudentAssessmentHistoryItem>[];
    final myNormScores = <double>[];

    for (final a in assessments) {
      final aScs = assessmentScores[a.id] ?? [];
      final cAvg = aScs.isNotEmpty ? aScs.reduce((x, y) => x + y) / aScs.length : null;
      final myRes = myResultsMap[a.id];
      if (myRes != null && myRes.score != null && a.maxScore > 0) {
        final norm = (myRes.score! / a.maxScore) * 20.0;
        myNormScores.add(norm);
        history.add(
          StudentAssessmentHistoryItem(
            assessmentId: a.id,
            title: a.title,
            kind: a.kind,
            maxScore: a.maxScore,
            score: myRes.score,
            normalized20: double.parse(norm.toStringAsFixed(2)),
            classAverage: cAvg != null ? double.parse(cAvg.toStringAsFixed(2)) : null,
            date: a.assessedOn,
          ),
        );
      }
    }

    final studentAvg = myNormScores.isNotEmpty ? myNormScores.reduce((x, y) => x + y) / myNormScores.length : 0.0;

    // Rank
    final peerAverages = <({String sid, double avg})>[];
    for (final pid in peerIds) {
      final scs = peerScores[pid] ?? [];
      final avg = scs.isNotEmpty ? scs.reduce((x, y) => x + y) / scs.length : 0.0;
      peerAverages.add((sid: pid, avg: avg));
    }
    peerAverages.sort((a, b) => b.avg.compareTo(a.avg));
    var myRank = 1;
    for (var i = 0; i < peerAverages.length; i++) {
      if (peerAverages[i].sid == studentId) {
        myRank = i + 1;
        break;
      }
    }

    // Attendance
    final records = await (db.select(db.attendanceRecords)..where((r) => r.studentId.equals(studentId) & r.deletedAt.isNull())).get();
    final present = records.where((r) => r.status == 'present').length;
    final late = records.where((r) => r.status == 'late').length;
    final absent = records.where((r) => r.status == 'absent').length;
    final totalAtt = records.length;
    final attRate = totalAtt > 0 ? ((present + late) / totalAtt) * 100.0 : 0.0;

    final strengths = <String>[];
    final areasForGrowth = <String>[];

    if (attRate >= 90.0) {
      strengths.add('انضباط ممتاز وحضور منتظم (${attRate.toStringAsFixed(1)}%)');
    } else if (attRate < 75.0) {
      areasForGrowth.add('نسبة الغياب مرتفعة ($absent غيابات)');
    }

    if (studentAvg >= 14.0) {
      strengths.add('معدل تحصيلي متفوق (${studentAvg.toStringAsFixed(2)}/20)');
    } else if (studentAvg >= 10.0) {
      strengths.add('مستوى دراسي مستقر ومقبول (${studentAvg.toStringAsFixed(2)}/20)');
    } else {
      areasForGrowth.add('المعدل العام دون عتبة النجاح (${studentAvg.toStringAsFixed(2)}/20)');
    }

    for (final h in history) {
      if (h.normalized20 != null && h.normalized20! >= 16.0) {
        strengths.add('أداء متميز في ${h.title} (${h.normalized20}/20)');
      } else if (h.normalized20 != null && h.normalized20! < 9.0) {
        areasForGrowth.add('صعوبة في استيعاب ${h.title} (${h.normalized20}/20)');
      }
    }

    return StudentAnalytics(
      studentId: student.id,
      studentName: '${student.firstName} ${student.lastName}',
      classId: classId,
      className: className,
      averageScore: double.parse(studentAvg.toStringAsFixed(2)),
      rankInClass: myRank,
      totalStudentsInClass: peerIds.length,
      attendanceRatePercent: double.parse(attRate.toStringAsFixed(1)),
      absentCount: absent,
      lateCount: late,
      assessmentHistory: history,
      strengths: strengths.take(4).toList(),
      areasForGrowth: areasForGrowth.take(4).toList(),
    );
  }
}
