import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/settings/settings_controller.dart';
import 'local/app_database.dart';
import 'repositories/auth_repository.dart';
import 'repositories/classes_repository.dart';
import 'repositories/students_repository.dart';

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

final classesStreamProvider = StreamProvider<List<ClassWithSubject>>((ref) {
  final repo = ref.watch(classesRepositoryProvider);
  return repo.watchClasses();
});

final studentsStreamProvider = StreamProvider.family<List<StudentItem>, ({String? classId, String? search})>((ref, params) {
  final repo = ref.watch(studentsRepositoryProvider);
  return repo.watchStudents(classId: params.classId, search: params.search);
});
