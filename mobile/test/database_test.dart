import 'package:flutter_test/flutter_test.dart';
import 'package:midad/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  test('sync_queue rejects invalid operation (CHECK constraint)', () async {
    final now = DateTime.now();
    expect(
      () => db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
            id: 'q1', entityType: 'student', entityId: 's1', operation: 'PATCH', payload: '{}',
            createdAt: now, updatedAt: now)),
      throwsA(isA<Exception>()),
    );
  });

  test('sync_queue accepts valid item with default status pending', () async {
    final now = DateTime.now();
    await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'q1', entityType: 'student', entityId: 's1', operation: 'CREATE', payload: '{}',
        createdAt: now, updatedAt: now));
    final row = await db.select(db.syncQueue).getSingle();
    expect(row.status, 'pending');
    expect(row.retryCount, 0);
  });
}
