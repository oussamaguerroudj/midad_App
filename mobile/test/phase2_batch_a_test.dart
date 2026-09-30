import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/data/local/app_database.dart';
import 'package:midad/data/repositories/assignments_repository.dart';
import 'package:midad/data/repositories/classes_repository.dart';
import 'package:midad/data/repositories/curriculum_repository.dart';
import 'package:midad/data/repositories/lessons_repository.dart';
import 'package:midad/data/repositories/students_repository.dart';

void main() {
  group('Phase 2 Batch (a) Repositories Offline-First Tests', () {
    late AppDatabase db;
    late Dio dio;
    late ClassesRepository classesRepo;
    late StudentsRepository studentsRepo;
    late LessonsRepository lessonsRepo;
    late AssignmentsRepository assignmentsRepo;
    late CurriculumRepository curriculumRepo;

    setUp(() {
      db = AppDatabase.inMemory();
      dio = Dio();
      classesRepo = ClassesRepository(db: db, dio: dio);
      studentsRepo = StudentsRepository(db: db, dio: dio);
      lessonsRepo = LessonsRepository(db: db, dio: dio);
      assignmentsRepo = AssignmentsRepository(db: db, dio: dio);
      curriculumRepo = CurriculumRepository(db: db, dio: dio);
    });

    tearDown(() async {
      await db.close();
    });

    test('LessonsRepository: create lesson and update journal with audit trail', () async {
      final classId = await classesRepo.createClass(
        name: '3 ع ت 1',
        level: 'الثالثة ثانوي',
        subjectName: 'علوم الطبيعة والحياة',
      );

      final lessonId = await lessonsRepo.createLesson(
        topic: 'آليات تركيب البروتين',
        classId: classId,
        lessonDate: DateTime.now(),
        durationMin: 60,
        objectives: 'التعرف على مراحل الاستنساخ والترجمة',
        content: 'تجارب واستغلال وثائق الكتاب المدرسي',
        completion: 'planned',
      );

      expect(lessonId, isNotEmpty);

      // Verify lesson stored locally
      final lesson = await lessonsRepo.getLessonById(lessonId);
      expect(lesson, isNotNull);
      expect(lesson!.topic, 'آليات تركيب البروتين');
      expect(lesson.completion, 'planned');
      expect(lesson.version, 1);

      // Update Teacher Journal (mark completed with covered content)
      await lessonsRepo.updateJournal(
        lessonId: lessonId,
        completion: 'completed',
        journalCovered: 'تم إنجاز تجارب استخلاص الـ ARN واستنتاج دور الـ ARNm.',
      );

      final updatedLesson = await lessonsRepo.getLessonById(lessonId);
      expect(updatedLesson!.completion, 'completed');
      expect(updatedLesson.journalCovered, contains('ARN'));
      expect(updatedLesson.version, 2);

      // Verify audit logs
      final auditEntries = await db.select(db.auditEntries).get();
      expect(auditEntries.any((a) => a.action == 'update_journal' && a.entityId == lessonId), isTrue);

      // Verify sync queue
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems.any((q) => q.entityType == 'lesson' && q.operation == 'CREATE'), isTrue);
      expect(queueItems.any((q) => q.entityType == 'lesson' && q.operation == 'UPDATE'), isTrue);
    });

    test('AssignmentsRepository: create assignment and save student records', () async {
      final classId = await classesRepo.createClass(
        name: '2 ر 1',
        level: 'الثانية ثانوي',
        subjectName: 'الرياضيات',
      );

      final studentId = await studentsRepo.createStudent(
        firstName: 'مهدي',
        lastName: 'براهيمي',
        classId: classId,
      );

      final assignmentId = await assignmentsRepo.createAssignment(
        classId: classId,
        title: 'واجب منزلي: المتتاليات الحسابية',
        description: 'حل التمارين 12 و 15 صفحة 88',
        dueOn: DateTime.now().add(const Duration(days: 3)),
      );

      expect(assignmentId, isNotEmpty);

      // Save student assignment record
      await assignmentsRepo.saveAssignmentRecords(
        assignmentId: assignmentId,
        records: [
          AssignmentRecordItem(
            studentId: studentId,
            studentName: 'مهدي براهيمي',
            status: 'completed',
          ),
        ],
      );

      final records = await assignmentsRepo.getAssignmentRecords(assignmentId, classId);
      expect(records.length, 1);
      expect(records.first.studentId, studentId);
      expect(records.first.status, 'completed');

      // Verify audit trail
      final auditEntries = await db.select(db.auditEntries).get();
      expect(auditEntries.any((a) => a.action == 'save_assignment_record'), isTrue);
    });

    test('CurriculumRepository: create units, lessons, and track class progress', () async {
      final classId = await classesRepo.createClass(
        name: '1 ج م ع 2',
        level: 'الأولى ثانوي',
        subjectName: 'الفيزياء',
      );

      final unitId = await curriculumRepo.createUnit(
        level: 'الأولى ثانوي',
        title: 'الوحدة 1: القوة والحركات المستقيمة',
        position: 1,
      );

      final lessonId = await curriculumRepo.createLesson(
        unitId: unitId,
        title: 'الدرس 1: الحركة المستقيمة المنتظمة',
        position: 1,
      );

      expect(unitId, isNotEmpty);
      expect(lessonId, isNotEmpty);

      // Track progress
      await curriculumRepo.updateProgress(
        classId: classId,
        curriculumLessonId: lessonId,
        status: 'completed',
      );

      // Verify through stream/watch
      final unitsList = await curriculumRepo.watchUnits(level: 'الأولى ثانوي', classId: classId).first;
      expect(unitsList.length, 1);
      expect(unitsList.first.lessons.length, 1);
      expect(unitsList.first.lessons.first.progressStatus, 'completed');
    });
  });
}
