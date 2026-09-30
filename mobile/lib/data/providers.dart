import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/settings/settings_controller.dart';
import 'local/app_database.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/classes_repository.dart';
import 'repositories/gradebook_repository.dart';
import 'repositories/students_repository.dart';
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
