import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart'; // generated: dart run build_runner build

@DriftDatabase(tables: [
  SyncQueue,
  AcademicYears,
  Subjects,
  Classes,
  Students,
  ClassStudents,
  AttendanceSessions,
  AttendanceRecords,
  Assessments,
  AssessmentResults,
  AuditEntries,
  Lessons,
  Assignments,
  AssignmentRecords,
  CurriculumUnits,
  CurriculumLessons,
  CurriculumProgresses,
  Tasks,
  DocumentFolders,
  Documents,
  SeatingPlans,
  SeatingPlanMembers,
  StudentGroups,
  GroupMembers,
  StudentActivityLogs,
  Favorites,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database (file in the app documents directory).
  factory AppDatabase.onDevice() => AppDatabase(LazyDatabase(() async {
        final dir = await getApplicationDocumentsDirectory();
        return NativeDatabase.createInBackground(File(p.join(dir.path, 'midad.sqlite')));
      }));

  /// For tests.
  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
        // Every schema bump adds an explicit onUpgrade step; data is never dropped.
      );
}
