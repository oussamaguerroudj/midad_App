import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../repositories/analytics_repository.dart';

class ParsedRosterStudent {
  const ParsedRosterStudent({
    required this.firstName,
    required this.lastName,
    this.registrationNumber,
    this.gender,
  });

  final String firstName;
  final String lastName;
  final String? registrationNumber;
  final String? gender;
}

class ImportRosterResult {
  const ImportRosterResult({
    required this.totalProcessed,
    required this.totalCreated,
    required this.totalSkipped,
    required this.errors,
  });

  final int totalProcessed;
  final int totalCreated;
  final int totalSkipped;
  final List<String> errors;
}

class ImportExportService {
  ImportExportService(this.db, this.analyticsRepo);

  final AppDatabase db;
  final AnalyticsRepository analyticsRepo;
  final _uuid = const Uuid();

  /// Parses CSV or TSV raw string into structured student rows.
  List<ParsedRosterStudent> parseCsvRoster(String content) {
    final lines = const LineSplitter().convert(content.trim());
    if (lines.isEmpty) return [];

    // Determine delimiter (comma, semicolon, or tab)
    final firstLine = lines.first;
    String delimiter = ',';
    if (firstLine.contains(';')) {
      delimiter = ';';
    } else if (firstLine.contains('\t')) {
      delimiter = '\t';
    }

    final headers = firstLine.split(delimiter).map((h) => h.trim().toLowerCase()).toList();

    int? fnIdx;
    int? lnIdx;
    int? refIdx;

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h.contains('first') || h.contains('اسم') || h.contains('prénom') || h.contains('prenom')) {
        fnIdx = i;
      } else if (h.contains('last') || h.contains('لقب') || h.contains('nom') || h.contains('family')) {
        lnIdx = i;
      } else if (h.contains('ref') || h.contains('تسجيل') || h.contains('رقم') || h.contains('matricule')) {
        refIdx = i;
      }
    }

    final hasHeader = fnIdx != null || lnIdx != null;
    final startRow = hasHeader ? 1 : 0;
    if (!hasHeader) {
      if (headers.length >= 3) {
        refIdx = 0;
        lnIdx = 1;
        fnIdx = 2;
      } else if (headers.length >= 2) {
        lnIdx = 0;
        fnIdx = 1;
      }
    }

    final results = <ParsedRosterStudent>[];

    for (var i = startRow; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(delimiter).map((c) => c.trim()).toList();

      final fn = fnIdx != null && fnIdx < parts.length ? parts[fnIdx] : '';
      final ln = lnIdx != null && lnIdx < parts.length ? parts[lnIdx] : '';
      final ref = refIdx != null && refIdx < parts.length && parts[refIdx].isNotEmpty ? parts[refIdx] : null;

      if (fn.isNotEmpty || ln.isNotEmpty) {
        results.add(
          ParsedRosterStudent(
            firstName: fn.isNotEmpty ? fn : 'تلميذ',
            lastName: ln.isNotEmpty ? ln : 'جديد',
            registrationNumber: ref,
          ),
        );
      }
    }

    return results;
  }

  /// Imports parsed students into the local Drift database with sync queue entries.
  Future<ImportRosterResult> importRoster({
    required String classId,
    required List<ParsedRosterStudent> students,
  }) async {
    var created = 0;
    var skipped = 0;
    final errors = <String>[];

    // Check existing students in this class
    final existingLinks = await (db.select(db.classStudents)..where((cs) => cs.classId.equals(classId) & cs.deletedAt.isNull())).get();
    final existingStudentIds = existingLinks.map((l) => l.studentId).toSet();
    final existingStudents = existingStudentIds.isEmpty
        ? <Student>[]
        : await (db.select(db.students)..where((s) => s.id.isIn(existingStudentIds) & s.deletedAt.isNull())).get();

    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      try {
        final fn = s.firstName.trim();
        final ln = s.lastName.trim();
        if (fn.isEmpty || ln.isEmpty) {
          skipped++;
          errors.add('السطر ${i + 1}: الاسم واللقب مطلوبان.');
          continue;
        }

        final duplicate = existingStudents.any((existing) =>
            existing.firstName.toLowerCase() == fn.toLowerCase() && existing.lastName.toLowerCase() == ln.toLowerCase());

        if (duplicate) {
          skipped++;
          continue;
        }

        final studentId = _uuid.v4();
        final now = DateTime.now();

        await db.transaction(() async {
          await db.into(db.students).insert(
                StudentsCompanion.insert(
                  id: studentId,
                  firstName: fn,
                  lastName: ln,
                  externalRef: Value(s.registrationNumber),
                  syncStatus: const Value('pending'),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          await db.into(db.classStudents).insert(
                ClassStudentsCompanion.insert(
                  id: _uuid.v4(),
                  classId: classId,
                  studentId: studentId,
                  syncStatus: const Value('pending'),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          await db.into(db.syncQueue).insert(
                SyncQueueCompanion.insert(
                  id: _uuid.v4(),
                  entityType: 'student',
                  entityId: studentId,
                  operation: 'CREATE',
                  payload: jsonEncode({
                    'id': studentId,
                    'first_name': fn,
                    'last_name': ln,
                    'external_ref': s.registrationNumber,
                    'class_id': classId,
                  }),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        });


        created++;
      } catch (e) {
        skipped++;
        errors.add('السطر ${i + 1}: ${e.toString()}');
      }
    }

    return ImportRosterResult(
      totalProcessed: students.length,
      totalCreated: created,
      totalSkipped: skipped,
      errors: errors,
    );
  }

  /// Exports student roster with attendance count and GPA as CSV.
  Future<String> exportStudentsRosterCsv(String classId) async {
    final schoolClass = await (db.select(db.classes)..where((c) => c.id.equals(classId) & c.deletedAt.isNull())).getSingle();
    final links = await (db.select(db.classStudents)..where((cs) => cs.classId.equals(classId) & cs.deletedAt.isNull())).get();
    final studentIds = links.map((l) => l.studentId).toSet();

    final students = studentIds.isEmpty
        ? <Student>[]
        : await (db.select(db.students)
              ..where((s) => s.id.isIn(studentIds) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.lastName), (s) => OrderingTerm.asc(s.firstName)]))
            .get();

    final buffer = StringBuffer();
    // UTF-8 BOM for Microsoft Excel
    buffer.write('\uFEFF');
    buffer.writeln('الرقم,رقم_التسجيل,اللقب,الاسم,القسم,عدد_الغيابات,المعدل_العام');

    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final records = await (db.select(db.attendanceRecords)..where((r) => r.studentId.equals(s.id) & r.deletedAt.isNull())).get();
      final absCount = records.where((r) => r.status == 'absent').length;

      final sAnalytics = await analyticsRepo.getStudentAnalytics(s.id);

      buffer.writeln(
        '${i + 1},'
        '"${s.externalRef ?? ""}",'
        '"${s.lastName}",'
        '"${s.firstName}",'
        '"${schoolClass.name}",'
        '$absCount,'
        '${sAnalytics.averageScore.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  /// Exports gradebook matrix (students x assessments) as CSV.
  Future<String> exportGradebookMatrixCsv(String classId) async {
    final links = await (db.select(db.classStudents)..where((cs) => cs.classId.equals(classId) & cs.deletedAt.isNull())).get();
    final studentIds = links.map((l) => l.studentId).toSet();

    final students = studentIds.isEmpty
        ? <Student>[]
        : await (db.select(db.students)
              ..where((s) => s.id.isIn(studentIds) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.lastName), (s) => OrderingTerm.asc(s.firstName)]))
            .get();

    final assessments = await (db.select(db.assessments)
          ..where((a) => a.classId.equals(classId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.assessedOn)]))
        .get();

    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    // Header
    final header = <String>['الرقم', 'رقم_التسجيل', 'اللقب', 'الاسم'];
    for (final a in assessments) {
      header.add('"${a.title} (/${a.maxScore.toInt()})"');
    }
    header.add('المعدل_العام (/20)');
    buffer.writeln(header.join(','));

    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      final row = <String>[
        '${i + 1}',
        '"${s.externalRef ?? ""}"',
        '"${s.lastName}"',
        '"${s.firstName}"',
      ];

      final studentNorms = <double>[];
      for (final a in assessments) {
        final res = await (db.select(db.assessmentResults)
              ..where((r) => r.assessmentId.equals(a.id) & r.studentId.equals(s.id) & r.deletedAt.isNull()))
            .getSingleOrNull();

        if (res != null && res.score != null) {
          row.add(res.score!.toStringAsFixed(2));
          if (a.maxScore > 0) {
            studentNorms.add((res.score! / a.maxScore) * 20.0);
          }
        } else {
          row.add('-');
        }
      }

      final genAvg = studentNorms.isNotEmpty ? studentNorms.reduce((a, b) => a + b) / studentNorms.length : 0.0;
      row.add(studentNorms.isNotEmpty ? genAvg.toStringAsFixed(2) : '-');
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }
}
