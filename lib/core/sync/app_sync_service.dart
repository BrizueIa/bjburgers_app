import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_client_provider.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../storage/local_settings_store.dart';

class SyncSummary {
  const SyncSummary({required this.success, required this.message});

  final bool success;
  final String message;
}

class AppSyncService {
  AppSyncService(this._database, this._localSettingsStore, this._client);

  final AppDatabase _database;
  final LocalSettingsStore _localSettingsStore;
  final SupabaseClient? _client;

  Future<SyncSummary> synchronizeAll() async {
    if (_client == null) {
      return const SyncSummary(
        success: false,
        message: 'Falta configurar Supabase en la app.',
      );
    }

    try {
      await _syncSettings();
      await _pushLocalInventory();
      await _pullRemoteInventory();
      await _localSettingsStore.setLastSyncNow();

      return const SyncSummary(
        success: true,
        message: 'Sincronizacion completada.',
      );
    } catch (error) {
      return SyncSummary(
        success: false,
        message: 'Error de sincronizacion: $error',
      );
    }
  }

  Future<void> _syncSettings() async {
    final client = _client;
    if (client == null) return;

    final local = _localSettingsStore.read();
    final remoteList = await client
        .from('settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1);

    if (remoteList.isEmpty) {
      final inserted = await client
          .from('settings')
          .insert(_settingsPayload(local, local.remoteSettingsId))
          .select()
          .single();
      await _localSettingsStore.setRemoteSettingsId(inserted['id'] as String);
      return;
    }

    final remote = remoteList.first;
    final remoteUpdatedAt = DateTime.parse(
      remote['updated_at'] as String,
    ).toUtc();
    final localUpdatedAt = local.settingsUpdatedAt.toUtc();

    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      await _localSettingsStore.replaceFromRemote(
        businessName: remote['business_name'] as String? ?? 'BJ Burguers',
        digitalMenuUrl: remote['digital_menu_image_url'] as String? ?? '',
        adminPin: remote['admin_pin'] as String? ?? '1234',
        adminModeEnabled: remote['admin_mode_enabled'] as bool? ?? false,
        updatedAt: remoteUpdatedAt,
        remoteSettingsId: remote['id'] as String,
      );
      return;
    }

    await client
        .from('settings')
        .upsert(
          _settingsPayload(local, remote['id'] as String),
          onConflict: 'id',
        );
    await _localSettingsStore.setRemoteSettingsId(remote['id'] as String);
  }

  Map<String, dynamic> _settingsPayload(
    LocalSettingsSnapshot local,
    String? id,
  ) {
    return {
      if (id != null) 'id': id,
      'business_name': local.businessName,
      'admin_pin': local.adminPin,
      'admin_mode_enabled': local.adminModeEnabled,
      'digital_menu_image_url': local.digitalMenuUrl.isEmpty
          ? null
          : local.digitalMenuUrl,
      'updated_at': local.settingsUpdatedAt.toIso8601String(),
    };
  }

  Future<void> _pushLocalInventory() async {
    final client = _client;
    if (client == null) return;

    final ingredients = await _database.select(_database.ingredients).get();
    final products = await _database.select(_database.products).get();
    final recipeItems = await _database
        .select(_database.productRecipeItems)
        .get();
    final purchases = await _database
        .select(_database.ingredientPurchases)
        .get();

    if (ingredients.isNotEmpty) {
      await client
          .from('ingredients')
          .upsert(
            ingredients
                .map(
                  (row) => {
                    'id': row.id,
                    'name': row.name,
                    'unit_name': row.unitName,
                    'current_unit_cost': row.currentUnitCost,
                    'is_active': row.isActive,
                    'created_at': row.createdAt.toUtc().toIso8601String(),
                    'updated_at': row.updatedAt.toUtc().toIso8601String(),
                  },
                )
                .toList(),
            onConflict: 'id',
          );
    }

    if (products.isNotEmpty) {
      await client
          .from('products')
          .upsert(
            products
                .map(
                  (row) => {
                    'id': row.id,
                    'name': row.name,
                    'category_name': row.categoryName,
                    'product_type': row.productType,
                    'sale_price': row.salePrice,
                    'direct_cost': row.directCost,
                    'display_order': row.displayOrder,
                    'is_active': row.isActive,
                    'created_at': row.createdAt.toUtc().toIso8601String(),
                    'updated_at': row.updatedAt.toUtc().toIso8601String(),
                  },
                )
                .toList(),
            onConflict: 'id',
          );
    }

    await client
        .from('product_recipe_items')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    if (recipeItems.isNotEmpty) {
      await client
          .from('product_recipe_items')
          .insert(
            recipeItems
                .map(
                  (row) => {
                    'id': row.id,
                    'product_id': row.productId,
                    'ingredient_id': row.ingredientId,
                    'quantity_used': row.quantityUsed,
                    'is_optional': row.isOptional,
                  },
                )
                .toList(),
          );
    }

    if (purchases.isNotEmpty) {
      await client
          .from('ingredient_purchases')
          .upsert(
            purchases
                .map(
                  (row) => {
                    'id': row.id,
                    'ingredient_id': row.ingredientId,
                    'purchased_quantity': row.purchasedQuantity,
                    'total_cost': row.totalCost,
                    'unit_cost': row.unitCost,
                    'note': row.note,
                    'purchased_at': row.purchasedAt.toUtc().toIso8601String(),
                    'created_at': row.createdAt.toUtc().toIso8601String(),
                    'updated_at': row.createdAt.toUtc().toIso8601String(),
                  },
                )
                .toList(),
            onConflict: 'id',
          );
    }
  }

  Future<void> _pullRemoteInventory() async {
    final client = _client;
    if (client == null) return;

    final ingredientsData = await client
        .from('ingredients')
        .select()
        .order('name');
    final productsData = await client
        .from('products')
        .select()
        .order('display_order');
    final recipeData = await client.from('product_recipe_items').select();
    final purchasesData = await client
        .from('ingredient_purchases')
        .select()
        .order('purchased_at');

    await _database.transaction(() async {
      await _database.delete(_database.productRecipeItems).go();
      await _database.delete(_database.ingredientPurchases).go();
      await _database.delete(_database.products).go();
      await _database.delete(_database.ingredients).go();

      for (final row in ingredientsData) {
        await _database
            .into(_database.ingredients)
            .insert(
              IngredientsCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                unitName: Value(row['unit_name'] as String? ?? 'unidad'),
                currentUnitCost: Value(
                  (row['current_unit_cost'] as num?)?.toDouble() ?? 0,
                ),
                isActive: Value(row['is_active'] as bool? ?? true),
                createdAt: DateTime.parse(
                  row['created_at'] as String,
                ).toLocal(),
                updatedAt: DateTime.parse(
                  row['updated_at'] as String,
                ).toLocal(),
              ),
            );
      }

      for (final row in productsData) {
        await _database
            .into(_database.products)
            .insert(
              ProductsCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                categoryName: Value(row['category_name'] as String?),
                productType: row['product_type'] as String,
                salePrice: (row['sale_price'] as num).toDouble(),
                directCost: Value(
                  (row['direct_cost'] as num?)?.toDouble() ?? 0,
                ),
                displayOrder: Value(row['display_order'] as int? ?? 0),
                isActive: Value(row['is_active'] as bool? ?? true),
                createdAt: DateTime.parse(
                  row['created_at'] as String,
                ).toLocal(),
                updatedAt: DateTime.parse(
                  row['updated_at'] as String,
                ).toLocal(),
              ),
            );
      }

      for (final row in recipeData) {
        await _database
            .into(_database.productRecipeItems)
            .insert(
              ProductRecipeItemsCompanion.insert(
                id: row['id'] as String,
                productId: row['product_id'] as String,
                ingredientId: row['ingredient_id'] as String,
                quantityUsed: (row['quantity_used'] as num).toDouble(),
                isOptional: Value(row['is_optional'] as bool? ?? false),
              ),
            );
      }

      for (final row in purchasesData) {
        await _database
            .into(_database.ingredientPurchases)
            .insert(
              IngredientPurchasesCompanion.insert(
                id: row['id'] as String,
                ingredientId: row['ingredient_id'] as String,
                purchasedQuantity: (row['purchased_quantity'] as num)
                    .toDouble(),
                totalCost: (row['total_cost'] as num).toDouble(),
                unitCost: (row['unit_cost'] as num).toDouble(),
                note: Value(row['note'] as String?),
                purchasedAt: DateTime.parse(
                  row['purchased_at'] as String,
                ).toLocal(),
                createdAt: DateTime.parse(
                  row['created_at'] as String,
                ).toLocal(),
              ),
            );
      }
    });
  }
}

final appSyncServiceProvider = Provider<AppSyncService>((ref) {
  return AppSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(localSettingsStoreProvider),
    ref.watch(supabaseClientProvider),
  );
});
