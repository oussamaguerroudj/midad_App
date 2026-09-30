import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class AcademicYearsRepository {
  AcademicYearsRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<AcademicYear>> watchAll() {
    return (_db.select(_db.academicYears)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startsOn, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<AcademicYear?> watchCurrent() {
    return (_db.select(_db.academicYears)
          ..where((t) => t.isCurrent.equals(true) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<AcademicYear> createAcademicYear({
    required String label,
    required DateTime startsOn,
    required DateTime endsOn,
    bool isCurrent = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    return _db.transaction(() async {
      if (isCurrent) {
        await (_db.update(_db.academicYears)..where((t) => t.isCurrent.equals(true)))
            .write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }

      final companion = AcademicYearsCompanion(
        id: Value(id),
        label: Value(label),
        startsOn: Value(startsOn),
        endsOn: Value(endsOn),
        isCurrent: Value(isCurrent),
        version: const Value(1),
        syncStatus: const Value('pending'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _db.into(_db.academicYears).insert(companion);

      final queueId = _uuid.v4();
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion(
              id: Value(queueId),
              entityType: const Value('academic_year'),
              entityId: Value(id),
              operation: const Value('CREATE'),
              payload: Value(jsonEncode({
                'id': id,
                'label': label,
                'starts_on': startsOn.toIso8601String().split('T').first,
                'ends_on': endsOn.toIso8601String().split('T').first,
                'is_current': isCurrent,
              })),
              baseVersion: const Value(0),
              createdAt: Value(now),
              updatedAt: Value(now),
              status: const Value('pending'),
            ),
          );

      return (await (_db.select(_db.academicYears)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  Future<void> setCurrent(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.academicYears)..where((t) => t.isCurrent.equals(true)))
          .write(const AcademicYearsCompanion(isCurrent: Value(false)));

      await (_db.update(_db.academicYears)..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          isCurrent: const Value(true),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );

      final queueId = _uuid.v4();
      await _db.into(_db.syncQueue).insert(
            SyncQueueCompanion(
              id: Value(queueId),
              entityType: const Value('academic_year'),
              entityId: Value(id),
              operation: const Value('UPDATE'),
              payload: Value(jsonEncode({'is_current': true})),
              baseVersion: const Value(1),
              createdAt: Value(now),
              updatedAt: Value(now),
              status: const Value('pending'),
            ),
          );
    });
  }
}
