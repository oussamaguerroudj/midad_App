import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/app_database.dart';

enum SyncStatus { idle, syncing, completed, offline, error }

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.dio,
    required this.prefs,
  });

  final AppDatabase db;
  final Dio dio;
  final SharedPreferences prefs;

  static const _kCursorKey = 'midad_sync_cursor';
  static const _kDeviceIdKey = 'midad_device_id';

  String get deviceId {
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }

  Future<int> pendingMutationsCount() async {
    final count = await (db.select(db.syncQueue)
          ..where((q) => q.status.equals('pending') | q.status.equals('processing')))
        .get();
    return count.length;
  }

  Future<void> runSync() async {
    await pushPendingMutations();
    await pullServerChanges();
  }

  Future<void> pushPendingMutations() async {
    final pendingItems = await (db.select(db.syncQueue)
          ..where((q) => q.status.equals('pending') | q.status.equals('processing'))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
          ..limit(50))
        .get();

    if (pendingItems.isEmpty) return;

    final mutations = pendingItems.map((item) {
      dynamic payloadObj;
      try {
        payloadObj = jsonDecode(item.payload);
      } catch (_) {
        payloadObj = item.payload;
      }

      return {
        'mutation_id': item.id.replaceAll('sq_', '').padRight(32, '0').substring(0, 32),
        'entity_type': item.entityType,
        'entity_id': item.entityId,
        'operation': item.operation,
        'base_version': item.baseVersion,
        'payload': payloadObj,
      };
    }).toList();

    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/sync',
        data: {
          'device_id': deviceId,
          'mutations': mutations,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final outcomes = res.data!['outcomes'] as List<dynamic>? ?? [];
        final outcomeMap = {for (final o in outcomes) (o as Map<String, dynamic>)['entity_id'] as String?: o};

        for (final item in pendingItems) {
          final outcome = outcomeMap[item.entityId];
          final statusStr = outcome?['outcome'] as String? ?? 'applied';

          if (statusStr == 'applied') {
            await (db.update(db.syncQueue)..where((q) => q.id.equals(item.id))).write(
              const SyncQueueCompanion(status: Value('synced')),
            );
          } else if (statusStr == 'conflict') {
            await (db.update(db.syncQueue)..where((q) => q.id.equals(item.id))).write(
              const SyncQueueCompanion(status: Value('failed'), lastError: Value('conflict')),
            );
          } else {
            await (db.update(db.syncQueue)..where((q) => q.id.equals(item.id))).write(
              SyncQueueCompanion(
                status: const Value('failed'),
                retryCount: Value(item.retryCount + 1),
                lastError: Value(outcome?['error'] as String? ?? 'rejected'),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Network failure: items remain pending for next sync run
    }
  }

  Future<void> pullServerChanges() async {
    final cursor = prefs.getString(_kCursorKey);
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/sync/changes',
        queryParameters: cursor != null ? {'cursor': cursor} : null,
      );

      if (res.statusCode == 200 && res.data != null) {
        final newCursor = res.data!['cursor'] as String?;
        if (newCursor != null) {
          await prefs.setString(_kCursorKey, newCursor);
        }
      }
    } catch (_) {}
  }
}
