import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

class PurchaseSummary {
  const PurchaseSummary({required this.purchase, required this.ingredientName});

  final IngredientPurchase purchase;
  final String ingredientName;
}

class PurchasesRepository {
  PurchasesRepository(this._database);

  final AppDatabase _database;
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
    final unitCost = totalCost / quantity;

    await _database.transaction(() async {
      await _database
          .into(_database.ingredientPurchases)
          .insert(
            IngredientPurchasesCompanion.insert(
              id: _uuid.v4(),
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
          currentUnitCost: Value(unitCost),
          updatedAt: Value(now),
        ),
      );
    });
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(appDatabaseProvider));
});
