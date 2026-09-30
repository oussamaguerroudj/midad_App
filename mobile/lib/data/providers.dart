import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/settings/settings_controller.dart';
import 'local/app_database.dart';
import 'repositories/academic_years_repository.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/assignments_repository.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/classes_repository.dart';
import 'repositories/curriculum_repository.dart';
import 'repositories/documents_repository.dart';
import 'repositories/gradebook_repository.dart';
import 'repositories/lessons_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/search_repository.dart';
import 'repositories/students_repository.dart';
import 'repositories/tasks_repository.dart';
import 'services/import_export_service.dart';
import 'services/report_generator_service.dart';
import 'sync/sync_engine.dart';


final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.onDevice();
  ref.onDispose(db.close);
  return db;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return buildDio(storage: storage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(dio: dio, storage: storage, prefs: prefs);
});

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return ClassesRepository(db: db, dio: dio);
});

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return StudentsRepository(db: db, dio: dio);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return AttendanceRepository(db: db, dio: dio);
});

final gradebookRepositoryProvider = Provider<GradebookRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return GradebookRepository(db: db, dio: dio);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncEngine(db: db, dio: dio, prefs: prefs);
});

final classesStreamProvider = StreamProvider<List<ClassWithSubject>>((ref) {
  final repo = ref.watch(classesRepositoryProvider);
  return repo.watchClasses();
});

final studentsStreamProvider = StreamProvider.family<List<StudentItem>, ({String? classId, String? search})>((ref, params) {
  final repo = ref.watch(studentsRepositoryProvider);
  return repo.watchStudents(classId: params.classId, search: params.search);
});

final assessmentsStreamProvider = StreamProvider.family<List<AssessmentItem>, String>((ref, classId) {
  final repo = ref.watch(gradebookRepositoryProvider);
  return repo.watchAssessments(classId);
});

final lessonsRepositoryProvider = Provider<LessonsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return LessonsRepository(db: db, dio: dio);
});

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return AssignmentsRepository(db: db, dio: dio);
});

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return CurriculumRepository(db: db, dio: dio);
});

final lessonsStreamProvider = StreamProvider.family<List<LessonItem>, String?>((ref, classId) {
  final repo = ref.watch(lessonsRepositoryProvider);
  return repo.watchLessons(classId: classId);
});

final assignmentsStreamProvider = StreamProvider.family<List<AssignmentItem>, String>((ref, classId) {
  final repo = ref.watch(assignmentsRepositoryProvider);
  return repo.watchAssignments(classId);
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioProvider);
  return TasksRepository(db: db, dio: dio);
});

final tasksStreamProvider = StreamProvider.family<List<TaskItem>, bool?>((ref, completed) {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.watchTasks(completed: completed);
});

// --- Phase 3: Organization Providers ---

final academicYearsRepositoryProvider = Provider<AcademicYearsRepository>((ref) {
  return AcademicYearsRepository(ref.watch(appDatabaseProvider));
});

final currentAcademicYearProvider = StreamProvider<AcademicYear?>((ref) {
  return ref.watch(academicYearsRepositoryProvider).watchCurrent();
});

final allAcademicYearsProvider = StreamProvider<List<AcademicYear>>((ref) {
  return ref.watch(academicYearsRepositoryProvider).watchAll();
});

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(appDatabaseProvider));
});

final documentFoldersProvider = StreamProvider<List<DocumentFolder>>((ref) {
  return ref.watch(documentsRepositoryProvider).watchFolders();
});

final documentsStreamProvider = StreamProvider.family<List<Document>, String?>((ref, folderId) {
  return ref.watch(documentsRepositoryProvider).watchDocuments(folderId: folderId);
});

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(ref.watch(appDatabaseProvider));
});

final seatingPlansStreamProvider = StreamProvider.family<List<SeatingPlan>, String>((ref, classId) {
  return ref.watch(organizationRepositoryProvider).watchSeatingPlans(classId);
});

final studentGroupsStreamProvider = StreamProvider.family<List<StudentGroup>, String>((ref, classId) {
  return ref.watch(organizationRepositoryProvider).watchGroups(classId);
});

final activityLogsStreamProvider = StreamProvider.family<List<StudentActivityLog>, String>((ref, classId) {
  return ref.watch(organizationRepositoryProvider).watchActivityLogs(classId);
});

final followUpAlertsProvider = FutureProvider<List<LocalFollowUpAlert>>((ref) {
  return ref.watch(organizationRepositoryProvider).evaluateFollowUpRules();
});

final favoritesStreamProvider = StreamProvider.family<List<Favorite>, String>((ref, targetType) {
  return ref.watch(organizationRepositoryProvider).watchFavorites(targetType);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(appDatabaseProvider));
});

// --- Phase 4: Analytics & Reports Providers ---

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});

final reportGeneratorServiceProvider = Provider<ReportGeneratorService>((ref) {
  return ReportGeneratorService(
    ref.watch(appDatabaseProvider),
    ref.watch(analyticsRepositoryProvider),
  );
});

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  return ImportExportService(
    ref.watch(appDatabaseProvider),
    ref.watch(analyticsRepositoryProvider),
  );
});

final overviewAnalyticsProvider = FutureProvider<OverviewAnalytics>((ref) {
  return ref.watch(analyticsRepositoryProvider).getOverview();
});

final classAnalyticsProvider = FutureProvider.family<ClassAnalytics, String>((ref, classId) {
  return ref.watch(analyticsRepositoryProvider).getClassAnalytics(classId);
});

final studentAnalyticsProvider = FutureProvider.family<StudentAnalytics, String>((ref, studentId) {
  return ref.watch(analyticsRepositoryProvider).getStudentAnalytics(studentId);
});



