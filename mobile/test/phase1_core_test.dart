import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/core/l10n/generated/app_localizations.dart';
import 'package:midad/data/local/app_database.dart';
import 'package:midad/data/repositories/classes_repository.dart';
import 'package:midad/data/repositories/students_repository.dart';
import 'package:midad/features/auth/login_page.dart';

void main() {
  group('Phase 1 Repositories Offline-First Tests', () {
    late AppDatabase db;
    late Dio dio;
    late ClassesRepository classesRepo;
    late StudentsRepository studentsRepo;

    setUp(() {
      db = AppDatabase.inMemory();
      dio = Dio();
      classesRepo = ClassesRepository(db: db, dio: dio);
      studentsRepo = StudentsRepository(db: db, dio: dio);
    });

    tearDown(() async {
      await db.close();
    });

    test('createClass creates local class with pending status and sync queue item', () async {
      final classId = await classesRepo.createClass(
        name: '1 ج م ع 1',
        level: 'الأولى ثانوي',
        subjectName: 'الرياضيات',
      );

      final classRow = await classesRepo.getClassById(classId);
      expect(classRow, isNotNull);
      expect(classRow!.name, '1 ج م ع 1');
      expect(classRow.subjectName, 'الرياضيات');
      expect(classRow.syncStatus, 'pending');

      // Verify sync queue item was recorded
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems.length, 1);
      expect(queueItems.first.entityType, 'class');
      expect(queueItems.first.entityId, classId);
      expect(queueItems.first.operation, 'CREATE');
    });

    test('createStudent creates student with enrollment and sync queue item', () async {
      final classId = await classesRepo.createClass(
        name: '2 ع ت 1',
        level: 'الثانية ثانوي',
        subjectName: 'العلوم الفيزيائية',
      );

      final studentId = await studentsRepo.createStudent(
        firstName: 'محمد',
        lastName: 'العربي',
        externalRef: 'ST-001',
        classId: classId,
      );

      final student = await studentsRepo.getStudentById(studentId);
      expect(student, isNotNull);
      expect(student!.fullName, 'محمد العربي');
      expect(student.externalRef, 'ST-001');
      expect(student.syncStatus, 'pending');
      expect(student.enrolledClasses, contains('2 ع ت 1'));

      // Verify sync queue has both class and student mutations
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems.any((q) => q.entityType == 'student' && q.entityId == studentId), isTrue);
    });
  });

  group('LoginPage Widget Tests', () {
    testWidgets('renders login form with Arabic labels by default', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('ar'), Locale('en'), Locale('fr')],
            home: LoginPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مِداد'), findsOneWidget);
      expect(find.text('مساحة عمل المعلم'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2)); // email & password
    });
  });
}
