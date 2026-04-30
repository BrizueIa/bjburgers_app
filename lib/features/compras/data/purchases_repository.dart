import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_queue_service.dart';

class PurchaseSummary {
  const PurchaseSummary({required this.purchase, required this.ingredientName});

  final IngredientPurchase purchase;
  final String ingredientName;
}

class PurchasesRepository {
  PurchasesRepository(this._database, this._syncQueueService);

  final AppDatabase _database;
  final SyncQueueService _syncQueueService;
  final Uuid _uuid = const Uuid();

  Stream<List<PurchaseSummary>> watchPurchases() {
    final query = _database.select(_database.ingredientPurchases).join([
      innerJoin(
        _database.ingredients,
        _database.ingredients.id.equalsExp(
          _database.ingredientPurchases.ingredientId,
        ),
      ),
    ])..orderBy([OrderingTerm.desc(_database.ingredientPurchases.purchasedAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => PurchaseSummary(
              purchase: row.readTable(_database.ingredientPurchases),
              ingredientName: row.readTable(_database.ingredients).name,
            ),
          )
          .toList(),
    );
  }

  Future<void> createPurchase({
    required String ingredientId,
    required double quantity,
    required double totalCost,
    required String? note,
  }) async {
    final now = DateTime.now();
    final purchaseId = _uuid.v4();

    await _database.transaction(() async {
      final ingredient = await (_database.select(
        _database.ingredients,
      )..where((table) => table.id.equals(ingredientId))).getSingle();

      final unitCost = totalCost / quantity;
      final currentStock = ingredient.stockQuantity ?? 0;
      final nextStock = currentStock + quantity;
      final weightedUnitCost = currentStock <= 0
          ? unitCost
          : ((currentStock * ingredient.currentUnitCost) + totalCost) /
                nextStock;

      await _database
          .into(_database.ingredientPurchases)
          .insert(
            IngredientPurchasesCompanion.insert(
              id: purchaseId,
              ingredientId: ingredientId,
              purchasedQuantity: quantity,
              totalCost: totalCost,
              unitCost: unitCost,
              note: Value(note?.isEmpty ?? true ? null : note),
              purchasedAt: now,
              createdAt: now,
            ),
          );

      await (_database.update(
        _database.ingredients,
      )..where((table) => table.id.equals(ingredientId))).write(
        IngredientsCompanion(
          currentUnitCost: Value(weightedUnitCost),
          stockQuantity: Value(nextStock),
          updatedAt: Value(now),
        ),
      );

      await _syncQueueService.enqueue(
        entityType: 'ingredients',
        entityId: ingredient.id,
        operationType: 'upsert',
        payload: {
          'id': ingredient.id,
          'name': ingredient.name,
          'unit_name': ingredient.unitName,
          'current_unit_cost': weightedUnitCost,
          'stock_quantity': nextStock,
          'is_active': ingredient.isActive,
          'created_at': ingredient.createdAt.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
          'deleted_at': ingredient.deletedAt?.toUtc().toIso8601String(),
        },
      );

      await _syncQueueService.enqueue(
        entityType: 'ingredient_purchases',
        entityId: purchaseId,
        operationType: 'upsert',
        payload: {
          'id': purchaseId,
          'ingredient_id': ingredientId,
          'purchased_quantity': quantity,
          'total_cost': totalCost,
          'unit_cost': unitCost,
          'note': note?.isEmpty ?? true ? null : note,
          'purchased_at': now.toUtc().toIso8601String(),
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
        },
      );
    });
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueServiceProvider),
  );
});
