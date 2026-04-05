import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

class RecipeDraftItem {
  const RecipeDraftItem({
    required this.ingredientId,
    required this.quantityUsed,
    this.isOptional = false,
  });

  final String ingredientId;
  final double quantityUsed;
  final bool isOptional;
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.productType,
    required this.salePrice,
    required this.directCost,
    required this.isActive,
    required this.calculatedCost,
    required this.margin,
    required this.recipeLines,
  });

  final String id;
  final String name;
  final String? categoryName;
  final String productType;
  final double salePrice;
  final double directCost;
  final bool isActive;
  final double calculatedCost;
  final double margin;
  final int recipeLines;
}

class RecipeLineSummary {
  const RecipeLineSummary({required this.item, required this.ingredient});

  final ProductRecipeItem item;
  final Ingredient ingredient;
}

class InventoryRepository {
  InventoryRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<Ingredient>> watchIngredients() {
    final query = _database.select(_database.ingredients)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Stream<List<ProductSummary>> watchProductSummaries() {
    const sql = '''
      SELECT
        p.id,
        p.name,
        p.category_name,
        p.product_type,
        p.sale_price,
        p.direct_cost,
        p.is_active,
        CASE
          WHEN p.product_type = 'simple' THEN p.direct_cost
          ELSE COALESCE(SUM(r.quantity_used * i.current_unit_cost), 0)
        END AS calculated_cost,
        COUNT(r.id) AS recipe_lines
      FROM products p
      LEFT JOIN product_recipe_items r ON r.product_id = p.id
      LEFT JOIN ingredients i ON i.id = r.ingredient_id
      GROUP BY p.id
      ORDER BY p.display_order ASC, p.name ASC
    ''';

    return _database
        .customSelect(
          sql,
          readsFrom: {
            _database.products,
            _database.productRecipeItems,
            _database.ingredients,
          },
        )
        .watch()
        .map(
          (rows) => rows.map((row) {
            final calculatedCost = row.read<double>('calculated_cost');
            final salePrice = row.read<double>('sale_price');
            return ProductSummary(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              categoryName: row.read<String?>('category_name'),
              productType: row.read<String>('product_type'),
              salePrice: salePrice,
              directCost: row.read<double>('direct_cost'),
              isActive: row.read<bool>('is_active'),
              calculatedCost: calculatedCost,
              margin: salePrice - calculatedCost,
              recipeLines: row.read<int>('recipe_lines'),
            );
          }).toList(),
        );
  }

  Stream<List<RecipeLineSummary>> watchRecipe(String productId) {
    final query = _database.select(_database.productRecipeItems).join([
      innerJoin(
        _database.ingredients,
        _database.ingredients.id.equalsExp(
          _database.productRecipeItems.ingredientId,
        ),
      ),
    ])..where(_database.productRecipeItems.productId.equals(productId));

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => RecipeLineSummary(
              item: row.readTable(_database.productRecipeItems),
              ingredient: row.readTable(_database.ingredients),
            ),
          )
          .toList(),
    );
  }

  Future<List<RecipeDraftItem>> fetchRecipeDraft(String productId) async {
    final rows = await (_database.select(
      _database.productRecipeItems,
    )..where((table) => table.productId.equals(productId))).get();

    return rows
        .map(
          (row) => RecipeDraftItem(
            ingredientId: row.ingredientId,
            quantityUsed: row.quantityUsed,
            isOptional: row.isOptional,
          ),
        )
        .toList();
  }

  Future<void> saveIngredient({
    String? id,
    required String name,
    required String unitName,
    required double currentUnitCost,
    required bool isActive,
  }) async {
    final now = DateTime.now();
    await _database
        .into(_database.ingredients)
        .insertOnConflictUpdate(
          IngredientsCompanion(
            id: Value(id ?? _uuid.v4()),
            name: Value(name),
            unitName: Value(unitName),
            currentUnitCost: Value(currentUnitCost),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> saveProduct({
    String? id,
    required String name,
    required String? categoryName,
    required String productType,
    required double salePrice,
    required double directCost,
    required bool isActive,
    required List<RecipeDraftItem> recipeItems,
  }) async {
    final productId = id ?? _uuid.v4();
    final now = DateTime.now();

    await _database.transaction(() async {
      await _database
          .into(_database.products)
          .insertOnConflictUpdate(
            ProductsCompanion(
              id: Value(productId),
              name: Value(name),
              categoryName: Value(
                categoryName?.isEmpty ?? true ? null : categoryName,
              ),
              productType: Value(productType),
              salePrice: Value(salePrice),
              directCost: Value(directCost),
              isActive: Value(isActive),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await (_database.delete(
        _database.productRecipeItems,
      )..where((table) => table.productId.equals(productId))).go();

      if (productType == 'recipe') {
        for (final item in recipeItems) {
          await _database
              .into(_database.productRecipeItems)
              .insert(
                ProductRecipeItemsCompanion.insert(
                  id: _uuid.v4(),
                  productId: productId,
                  ingredientId: item.ingredientId,
                  quantityUsed: item.quantityUsed,
                  isOptional: Value(item.isOptional),
                ),
              );
        }
      }
    });
  }

  Future<void> toggleIngredientActive(Ingredient ingredient) async {
    await (_database.update(
      _database.ingredients,
    )..where((t) => t.id.equals(ingredient.id))).write(
      IngredientsCompanion(
        isActive: Value(!ingredient.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> toggleProductActive(ProductSummary product) async {
    await (_database.update(
      _database.products,
    )..where((t) => t.id.equals(product.id))).write(
      ProductsCompanion(
        isActive: Value(!product.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(appDatabaseProvider));
});
