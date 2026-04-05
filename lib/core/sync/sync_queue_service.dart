import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/app_database_provider.dart';

class PendingSyncItem {
  const PendingSyncItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.retryCount,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final int retryCount;
}

class SyncQueueService {
  SyncQueueService(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final existing =
        await (_database.select(_database.syncQueueEntries)..where(
              (table) =>
                  table.entityType.equals(entityType) &
                  table.entityId.equals(entityId) &
                  table.status.isIn(const ['pending', 'failed']),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_database.update(
        _database.syncQueueEntries,
      )..where((table) => table.id.equals(existing.id))).write(
        SyncQueueEntriesCompanion(
          operationType: Value(operationType),
          payloadJson: Value(jsonEncode(payload)),
          status: const Value('pending'),
          retryCount: const Value(0),
          lastError: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return;
    }

    await _database
        .into(_database.syncQueueEntries)
        .insert(
          SyncQueueEntriesCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operationType: operationType,
            payloadJson: Value(jsonEncode(payload)),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<List<PendingSyncItem>> getPendingItems() async {
    final rows =
        await (_database.select(_database.syncQueueEntries)
              ..where(
                (table) =>
                    table.status.equals('pending') |
                    table.status.equals('failed'),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();

    return rows
        .map(
          (row) => PendingSyncItem(
            id: row.id,
            entityType: row.entityType,
            entityId: row.entityId,
            operationType: row.operationType,
            payload: (jsonDecode(row.payloadJson) as Map)
                .cast<String, dynamic>(),
            retryCount: row.retryCount,
          ),
        )
        .toList();
  }

  Future<bool> hasPendingFor(String entityType, String entityId) async {
    final row =
        await (_database.select(_database.syncQueueEntries)
              ..where(
                (table) =>
                    table.entityType.equals(entityType) &
                    table.entityId.equals(entityId) &
                    table.status.isIn(const ['pending', 'failed']),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> markDone(String queueId) async {
    await (_database.update(
      _database.syncQueueEntries,
    )..where((table) => table.id.equals(queueId))).write(
      SyncQueueEntriesCompanion(
        status: const Value('done'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markFailed(String queueId, Object error) async {
    final entry = await (_database.select(
      _database.syncQueueEntries,
    )..where((table) => table.id.equals(queueId))).getSingle();
    await (_database.update(
      _database.syncQueueEntries,
    )..where((table) => table.id.equals(queueId))).write(
      SyncQueueEntriesCompanion(
        status: const Value('failed'),
        retryCount: Value(entry.retryCount + 1),
        lastError: Value(error.toString()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService(ref.watch(appDatabaseProvider));
});
