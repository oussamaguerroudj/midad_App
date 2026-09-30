import 'package:drift/drift.dart';

/// Local (SQLite) schema. Every replicated table carries sync metadata:
///   version    - last server version known (optimistic locking, spec §49)
///   syncStatus - 'synced' | 'pending' | 'conflict'
///   deletedAt  - soft delete, so deletions can be synced
/// IDs are client-generated UUID strings so offline creation never needs the server.
mixin SyncColumns on Table {
  IntColumn get version => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@TableIndex(name: 'idx_sync_queue_status_created', columns: {#status, #createdAt})
@TableIndex(name: 'idx_sync_queue_entity', columns: {#entityType, #entityId})
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // CREATE | UPDATE | DELETE
  TextColumn get payload => text()(); // JSON
  IntColumn get baseVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|processing|synced|failed
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (operation IN ('CREATE','UPDATE','DELETE'))",
        "CHECK (status IN ('pending','processing','synced','failed'))",
      ];
}

class AcademicYears extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get label => text()();
  DateTimeColumn get startsOn => dateTime()();
  DateTimeColumn get endsOn => dateTime()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Subjects extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_classes_year', columns: {#academicYearId})
class Classes extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get name => text()();
  TextColumn get level => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_students_name', columns: {#lastName, #firstName})
class Students extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get externalRef => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_class_students_class', columns: {#classId})
class ClassStudents extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [{classId, studentId}];
}

@TableIndex(name: 'idx_att_sessions_class_date', columns: {#classId, #sessionDate})
class AttendanceSessions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  DateTimeColumn get sessionDate => dateTime()();
  TextColumn get slot => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [{classId, sessionDate, slot}];
}

class AttendanceRecords extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(AttendanceSessions, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get status => text()(); // present|absent|late|excused
  TextColumn get note => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [{sessionId, studentId}];
  @override
  List<String> get customConstraints => ["CHECK (status IN ('present','absent','late','excused'))"];
}

@TableIndex(name: 'idx_assessments_class_date', columns: {#classId, #assessedOn})
class Assessments extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get title => text()();
  TextColumn get kind => text()();
  DateTimeColumn get assessedOn => dateTime()();
  RealColumn get maxScore => real().withDefault(const Constant(20))();
  RealColumn get coefficient => real().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (max_score > 0)', 'CHECK (coefficient > 0)'];
}

class AssessmentResults extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get assessmentId => text().references(Assessments, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  RealColumn get score => real().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [{assessmentId, studentId}];
  @override
  List<String> get customConstraints => ['CHECK (score IS NULL OR score >= 0)'];
}

/// Local audit trail; uploaded with the sync batch. Append-only.
class AuditEntries extends Table {
  TextColumn get id => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_lessons_class_date', columns: {#classId, #lessonDate})
class Lessons extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().nullable().references(Classes, #id)();
  TextColumn get subjectId => text().nullable().references(Subjects, #id)();
  TextColumn get topic => text()();
  DateTimeColumn get lessonDate => dateTime().nullable()();
  IntColumn get durationMin => integer().nullable().withDefault(const Constant(60))();
  TextColumn get objectives => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get activities => text().nullable()();
  TextColumn get homework => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get journalCovered => text().nullable()();
  TextColumn get completion => text().withDefault(const Constant('planned'))(); // planned|in_progress|completed

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (completion IN ('planned','in_progress','completed'))"];
}

@TableIndex(name: 'idx_assignments_class_due', columns: {#classId, #dueOn})
class Assignments extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueOn => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AssignmentRecords extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get assignmentId => text().references(Assignments, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get status => text().withDefault(const Constant('assigned'))(); // assigned|completed|missing|excused

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{assignmentId, studentId}];

  @override
  List<String> get customConstraints => ["CHECK (status IN ('assigned','completed','missing','excused'))"];
}

class CurriculumUnits extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get subjectId => text().nullable().references(Subjects, #id)();
  TextColumn get level => text()();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class CurriculumLessons extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get unitId => text().references(CurriculumUnits, #id)();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class CurriculumProgresses extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get curriculumLessonId => text().references(CurriculumLessons, #id)();
  TextColumn get status => text().withDefault(const Constant('not_started'))(); // not_started|in_progress|completed

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{classId, curriculumLessonId}];

  @override
  List<String> get customConstraints => ["CHECK (status IN ('not_started','in_progress','completed'))"];
}

class Tasks extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))(); // low|medium|high
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (priority IN ('low','medium','high'))"];
}

// --- Phase 3: Organization Tables ---

class DocumentFolders extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Documents extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable().references(DocumentFolders, #id)();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get storageKey => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SeatingPlans extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get name => text()();
  TextColumn get layout => text().withDefault(const Constant('custom'))(); // rows|groups|u_shape|custom

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (layout IN ('rows','groups','u_shape','custom'))"];
}

class SeatingPlanMembers extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get planId => text().references(SeatingPlans, #id)();
  TextColumn get studentId => text().nullable().references(Students, #id)();
  RealColumn get seatX => real()();
  RealColumn get seatY => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class StudentGroups extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class GroupMembers extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(StudentGroups, #id)();
  TextColumn get studentId => text().references(Students, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{groupId, studentId}];
}

class StudentActivityLogs extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get classId => text().references(Classes, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  DateTimeColumn get loggedOn => dateTime()();
  TextColumn get category => text()(); // participated|completed_homework|late|positive_contribution|classroom_note
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (category IN ('participated','completed_homework','late','positive_contribution','classroom_note'))"
      ];
}

class Favorites extends Table {
  TextColumn get id => text()();
  TextColumn get targetType => text()(); // class|student|lesson|document
  TextColumn get targetId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{targetType, targetId}];
}

