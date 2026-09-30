import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueAt,
    this.completedAt,
    this.version = 1,
    this.syncStatus = 'pending',
  });

  final String id;
  final String title;
  final String? description;
  final String priority; // low | medium | high
  final DateTime? dueAt;
  final DateTime? completedAt;
  final int version;
  final String syncStatus;

  bool get isCompleted => completedAt != null;
}

class TasksRepository {
  TasksRepository({
    required this.db,
    required this.dio,
  });

  final AppDatabase db;
  final Dio dio;
  static const _uuid = Uuid();

  Stream<List<TaskItem>> watchTasks({bool? completed}) {
    final query = db.select(db.tasks)
      ..where((t) {
        var pred = t.deletedAt.isNull();
        if (completed == true) {
          pred = pred & t.completedAt.isNotNull();
        } else if (completed == false) {
          pred = pred & t.completedAt.isNull();
        }
        return pred;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.dueAt), (t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) {
      return rows
          .map((t) => TaskItem(
                id: t.id,
                title: t.title,
                description: t.description,
                priority: t.priority,
                dueAt: t.dueAt,
                completedAt: t.completedAt,
                version: t.version,
                syncStatus: t.syncStatus,
              ))
          .toList();
    });
  }

  Future<String> createTask({
    required String title,
    String? description,
    String priority = 'medium',
    DateTime? dueAt,
  }) async {
    final taskId = _uuid.v4();
    final now = DateTime.now();

    await db.transaction(() async {
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: taskId,
              title: title.trim(),
              description: Value(description),
              priority: Value(priority),
              dueAt: Value(dueAt),
              version: const Value(1),
              syncStatus: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.auditEntries).insert(
            AuditEntriesCompanion.insert(
              id: _uuid.v4(),
              action: 'create_task',
              entityType: 'task',
              entityId: Value(taskId),
              afterJson: Value(jsonEncode({'title': title, 'priority': priority})),
              occurredAt: now,
            ),
          );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_tsk_${now.millisecondsSinceEpoch}',
              entityType: 'task',
              entityId: taskId,
              operation: 'CREATE',
              payload: jsonEncode({
                'id': taskId,
                'title': title,
                'description': description,
                'priority': priority,
                'due_at': dueAt?.toIso8601String(),
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return taskId;
  }

  Future<void> toggleTask(String taskId, bool isCompleted) async {
    final now = DateTime.now();
    final existing = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (existing == null) return;

    await db.transaction(() async {
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          completedAt: Value(isCompleted ? now : null),
          version: Value(existing.version + 1),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq_tsk_tgl_${now.millisecondsSinceEpoch}',
              entityType: 'task',
              entityId: taskId,
              operation: 'UPDATE',
              baseVersion: Value(existing.version),
              payload: jsonEncode({
                'completed': isCompleted,
                'base_version': existing.version,
              }),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
}
