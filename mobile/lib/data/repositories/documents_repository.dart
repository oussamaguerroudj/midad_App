import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class DocumentsRepository {
  DocumentsRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<DocumentFolder>> watchFolders() {
    return (_db.select(_db.documentFolders)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Stream<List<Document>> watchDocuments({String? folderId}) {
    final query = _db.select(_db.documents)..where((t) => t.deletedAt.isNull());
    if (folderId != null) {
      query.where((t) => t.folderId.equals(folderId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<DocumentFolder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final companion = DocumentFoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: Value(parentId),
      version: const Value(1),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.into(_db.documentFolders).insert(companion);

    final queueId = _uuid.v4();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion(
            id: Value(queueId),
            entityType: const Value('document_folder'),
            entityId: Value(id),
            operation: const Value('CREATE'),
            payload: Value(jsonEncode({
              'id': id,
              'name': name,
              'parent_id': parentId,
            })),
            baseVersion: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
            status: const Value('pending'),
          ),
        );

    return (await (_db.select(_db.documentFolders)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<Document> createDocument({
    String? folderId,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required String storageKey,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final companion = DocumentsCompanion(
      id: Value(id),
      folderId: Value(folderId),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      storageKey: Value(storageKey),
      version: const Value(1),
      syncStatus: const Value('pending'),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _db.into(_db.documents).insert(companion);

    final queueId = _uuid.v4();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion(
            id: Value(queueId),
            entityType: const Value('document'),
            entityId: Value(id),
            operation: const Value('CREATE'),
            payload: Value(jsonEncode({
              'id': id,
              'folder_id': folderId,
              'file_name': fileName,
              'mime_type': mimeType,
              'size_bytes': sizeBytes,
              'storage_key': storageKey,
            })),
            baseVersion: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
            status: const Value('pending'),
          ),
        );

    return (await (_db.select(_db.documents)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> deleteDocument(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    final queueId = _uuid.v4();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion(
            id: Value(queueId),
            entityType: const Value('document'),
            entityId: Value(id),
            operation: const Value('DELETE'),
            payload: Value(jsonEncode({'id': id})),
            baseVersion: const Value(1),
            createdAt: Value(now),
            updatedAt: Value(now),
            status: const Value('pending'),
          ),
        );
  }
}
