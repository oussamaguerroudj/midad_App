import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/data/local/app_database.dart';
import 'package:midad/data/repositories/academic_years_repository.dart';
import 'package:midad/data/repositories/classes_repository.dart';
import 'package:midad/data/repositories/documents_repository.dart';
import 'package:midad/data/repositories/organization_repository.dart';
import 'package:midad/data/repositories/search_repository.dart';
import 'package:midad/data/repositories/students_repository.dart';

void main() {
  late AppDatabase db;
  late AcademicYearsRepository ayRepo;
  late DocumentsRepository docRepo;
  late OrganizationRepository orgRepo;
  late SearchRepository searchRepo;
  late ClassesRepository classesRepo;
  late StudentsRepository studentsRepo;

  setUp(() {
    db = AppDatabase.inMemory();
    ayRepo = AcademicYearsRepository(db);
    docRepo = DocumentsRepository(db);
    orgRepo = OrganizationRepository(db);
    searchRepo = SearchRepository(db);
    final dio = Dio();
    classesRepo = ClassesRepository(db: db, dio: dio);
    studentsRepo = StudentsRepository(db: db, dio: dio);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 3 Organization Offline-First Tests', () {
    test('AcademicYearsRepository: creates year and sets current', () async {
      final y1 = await ayRepo.createAcademicYear(
        label: '2026-2027',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2027, 6, 30),
        isCurrent: true,
      );
      expect(y1.label, '2026-2027');
      expect(y1.isCurrent, true);

      final y2 = await ayRepo.createAcademicYear(
        label: '2027-2028',
        startsOn: DateTime(2027, 9, 1),
        endsOn: DateTime(2028, 6, 30),
        isCurrent: false,
      );
      expect(y2.isCurrent, false);

      await ayRepo.setCurrent(y2.id);
      final current = await ayRepo.watchCurrent().first;
      expect(current?.id, y2.id);
    });

    test('DocumentsRepository: creates folders and documents with soft-delete', () async {
      final folder = await docRepo.createFolder(name: 'الامتحانات الرسمية');
      expect(folder.name, 'الامتحانات الرسمية');

      final doc = await docRepo.createDocument(
        folderId: folder.id,
        fileName: 'examen_math_t1.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 204800,
        storageKey: 'docs/test/examen.pdf',
      );
      expect(doc.fileName, 'examen_math_t1.pdf');
      expect(doc.folderId, folder.id);

      final docs = await docRepo.watchDocuments(folderId: folder.id).first;
      expect(docs.length, 1);

      await docRepo.deleteDocument(doc.id);
      final afterDelete = await docRepo.watchDocuments(folderId: folder.id).first;
      expect(afterDelete.isEmpty, true);
    });

    test('OrganizationRepository: seating plans, groups, activities, favorites, and alerts', () async {
      // 1. Create class and students
      final clsId = await classesRepo.createClass(
        name: '3 AS Math',
        subjectName: 'رياضيات',
      );

      final s1Id = await studentsRepo.createStudent(
        firstName: 'يوسف',
        lastName: 'قاسمي',
        classId: clsId,
      );
      final s2Id = await studentsRepo.createStudent(
        firstName: 'مريم',
        lastName: 'علوي',
        classId: clsId,
      );

      // 2. Seating Plan
      final plan = await orgRepo.createSeatingPlan(
        classId: clsId,
        name: 'مخطط القاعة 4',
        layout: 'rows',
        members: [
          (studentId: s1Id, seatX: 0.0, seatY: 0.0),
          (studentId: s2Id, seatX: 1.0, seatY: 0.0),
        ],
      );
      expect(plan.name, 'مخطط القاعة 4');

      final plans = await orgRepo.watchSeatingPlans(clsId).first;
      expect(plans.length, 1);

      final planMembers = await orgRepo.watchPlanMembers(plan.id).first;
      expect(planMembers.length, 2);

      // 3. Student Groups
      final group = await orgRepo.createGroup(
        classId: clsId,
        name: 'فوج البحث',
        studentIds: [s1Id, s2Id],
      );
      expect(group.name, 'فوج البحث');

      final groups = await orgRepo.watchGroups(clsId).first;
      expect(groups.length, 1);

      final groupMembers = await orgRepo.watchGroupMembers(group.id).first;
      expect(groupMembers.length, 2);

      // 4. Activity / Participation Log
      final log = await orgRepo.logActivity(
        classId: clsId,
        studentId: s1Id,
        category: 'positive_contribution',
        note: 'مشاركة ممتازة في حل تمرين النهايات',
      );
      expect(log.category, 'positive_contribution');

      final logs = await orgRepo.watchActivityLogs(clsId).first;
      expect(logs.length, 1);

      // 5. Favorites
      expect(await orgRepo.isFavorite('class', clsId), false);
      await orgRepo.toggleFavorite('class', clsId);
      expect(await orgRepo.isFavorite('class', clsId), true);
      await orgRepo.toggleFavorite('class', clsId);
      expect(await orgRepo.isFavorite('class', clsId), false);

      // 6. Search Repository
      final results = await searchRepo.search('قاسمي');
      expect(results.length, 1);
      expect(results.first.type, 'student');
      expect(results.first.title, 'يوسف قاسمي');

      final classResults = await searchRepo.search('3 AS');
      expect(classResults.length, 1);
      expect(classResults.first.type, 'class');
    });
  });
}
