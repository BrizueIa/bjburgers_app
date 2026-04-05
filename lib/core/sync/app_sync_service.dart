import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_client_provider.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../storage/local_settings_store.dart';
import 'sync_queue_service.dart';

class SyncSummary {
  const SyncSummary({required this.success, required this.message});

  final bool success;
  final String message;
}

class AppSyncService {
  AppSyncService(
    this._database,
    this._localSettingsStore,
    this._client,
    this._syncQueueService,
  );

  final AppDatabase _database;
  final LocalSettingsStore _localSettingsStore;
  final SupabaseClient? _client;
  final SyncQueueService _syncQueueService;

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
      await _pushLocalOperations();
      await _pullRemoteInventory();
      await _pullRemoteOperations();
      await _localSettingsStore.setLastSyncNow();

      return const SyncSummary(
        success: true,
        message: 'Sincronizacion completada.',
      );
    } catch (error) {
      debugPrint('Error durante sincronizacion: $error');
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
      final inserted = await _insertSettingsWithFallback(
        client,
        _settingsPayload(local, local.remoteSettingsId),
      );
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
        stockTrackingEnabled: _readRemoteStockTracking(remote),
        updatedAt: remoteUpdatedAt,
        remoteSettingsId: remote['id'] as String,
      );
      return;
    }

    await _upsertSettingsWithFallback(
      client,
      _settingsPayload(local, remote['id'] as String),
    );
    await _localSettingsStore.setRemoteSettingsId(remote['id'] as String);
  }

  bool _readRemoteStockTracking(Map<String, dynamic> remote) {
    try {
      return remote['stock_tracking_enabled'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _insertSettingsWithFallback(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await client.from('settings').insert(payload).select().single();
    } on PostgrestException catch (error) {
      if (_isMissingStockTrackingColumn(error)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('stock_tracking_enabled');
        return await client.from('settings').insert(fallback).select().single();
      }
      rethrow;
    }
  }

  Future<void> _upsertSettingsWithFallback(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    try {
      await client.from('settings').upsert(payload, onConflict: 'id');
    } on PostgrestException catch (error) {
      if (_isMissingStockTrackingColumn(error)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('stock_tracking_enabled');
        await client.from('settings').upsert(fallback, onConflict: 'id');
        return;
      }
      rethrow;
    }
  }

  bool _isMissingStockTrackingColumn(PostgrestException error) {
    return error.code == 'PGRST204' &&
        error.message.contains('stock_tracking_enabled');
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
      'stock_tracking_enabled': local.stockTrackingEnabled,
      'digital_menu_image_url': local.digitalMenuUrl.isEmpty
          ? null
          : local.digitalMenuUrl,
      'updated_at': local.settingsUpdatedAt.toIso8601String(),
    };
  }

  Future<void> _pushLocalInventory() async {
    await _processPendingQueue();
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
      for (final row in ingredientsData) {
        if (await _syncQueueService.hasPendingFor(
          'ingredients',
          row['id'] as String,
        )) {
          continue;
        }
        if (row['deleted_at'] != null) {
          await (_database.delete(
            _database.ingredients,
          )..where((table) => table.id.equals(row['id'] as String))).go();
          continue;
        }
        await _database
            .into(_database.ingredients)
            .insertOnConflictUpdate(
              IngredientsCompanion(
                id: Value(row['id'] as String),
                name: Value(row['name'] as String),
                unitName: Value(row['unit_name'] as String? ?? 'unidad'),
                currentUnitCost: Value(
                  (row['current_unit_cost'] as num?)?.toDouble() ?? 0,
                ),
                stockQuantity: Value(
                  (row['stock_quantity'] as num?)?.toDouble(),
                ),
                isActive: Value(row['is_active'] as bool? ?? true),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
                deletedAt: const Value(null),
              ),
            );
      }

      for (final row in productsData) {
        if (await _syncQueueService.hasPendingFor(
          'products',
          row['id'] as String,
        )) {
          continue;
        }
        if (row['deleted_at'] != null) {
          await (_database.delete(
            _database.products,
          )..where((table) => table.id.equals(row['id'] as String))).go();
          continue;
        }
        await _database
            .into(_database.products)
            .insertOnConflictUpdate(
              ProductsCompanion(
                id: Value(row['id'] as String),
                name: Value(row['name'] as String),
                categoryName: Value(row['category_name'] as String?),
                productType: Value(row['product_type'] as String),
                salePrice: Value((row['sale_price'] as num).toDouble()),
                directCost: Value(
                  (row['direct_cost'] as num?)?.toDouble() ?? 0,
                ),
                stockQuantity: Value(
                  (row['stock_quantity'] as num?)?.toDouble(),
                ),
                trackStock: Value(row['track_stock'] as bool? ?? false),
                displayOrder: Value(row['display_order'] as int? ?? 0),
                isActive: Value(row['is_active'] as bool? ?? true),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
                deletedAt: const Value(null),
              ),
            );
      }

      for (final row in recipeData) {
        await _database
            .into(_database.productRecipeItems)
            .insertOnConflictUpdate(
              ProductRecipeItemsCompanion(
                id: Value(row['id'] as String),
                productId: Value(row['product_id'] as String),
                ingredientId: Value(row['ingredient_id'] as String),
                quantityUsed: Value((row['quantity_used'] as num).toDouble()),
                isOptional: Value(row['is_optional'] as bool? ?? false),
              ),
            );
      }

      for (final row in purchasesData) {
        if (await _syncQueueService.hasPendingFor(
          'ingredient_purchases',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.ingredientPurchases)
            .insertOnConflictUpdate(
              IngredientPurchasesCompanion(
                id: Value(row['id'] as String),
                ingredientId: Value(row['ingredient_id'] as String),
                purchasedQuantity: Value(
                  (row['purchased_quantity'] as num).toDouble(),
                ),
                totalCost: Value((row['total_cost'] as num).toDouble()),
                unitCost: Value((row['unit_cost'] as num).toDouble()),
                note: Value(row['note'] as String?),
                purchasedAt: Value(
                  DateTime.parse(row['purchased_at'] as String).toLocal(),
                ),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
              ),
            );
      }
    });
  }

  Future<void> _pushLocalOperations() async {
    return;
  }

  Future<void> _processPendingQueue() async {
    final client = _client;
    if (client == null) return;

    final items = await _syncQueueService.getPendingItems();
    for (final item in items) {
      try {
        await _upsertQueueItem(client, item);
        await _syncQueueService.markDone(item.id);
      } catch (error) {
        await _syncQueueService.markFailed(item.id, error);
      }
    }
  }

  Future<void> _upsertQueueItem(
    SupabaseClient client,
    PendingSyncItem item,
  ) async {
    switch (item.entityType) {
      case 'ingredients':
      case 'products':
      case 'ingredient_purchases':
      case 'cash_sessions':
      case 'cash_movements':
        await client
            .from(item.entityType)
            .upsert(item.payload, onConflict: 'id');
        if (item.entityType == 'products' && item.operationType != 'delete') {
          await _syncRemoteProductRecipe(client, item.entityId);
        }
        break;
      case 'orders':
        await client.from('orders').upsert(item.payload, onConflict: 'id');
        await _syncRemoteOrderItems(client, item.entityId);
        break;
      case 'sales':
        await client.from('sales').upsert(item.payload, onConflict: 'id');
        await _syncRemoteSaleItems(client, item.entityId);
        break;
      case 'order_items':
        await client.from('order_items').upsert(item.payload, onConflict: 'id');
        break;
      default:
        break;
    }
  }

  Future<void> _syncRemoteProductRecipe(
    SupabaseClient client,
    String productId,
  ) async {
    final rows = await (_database.select(
      _database.productRecipeItems,
    )..where((table) => table.productId.equals(productId))).get();
    await client
        .from('product_recipe_items')
        .delete()
        .eq('product_id', productId);
    if (rows.isNotEmpty) {
      await client
          .from('product_recipe_items')
          .insert(
            rows
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
  }

  Future<void> _syncRemoteOrderItems(
    SupabaseClient client,
    String orderId,
  ) async {
    final rows = await (_database.select(
      _database.orderItems,
    )..where((table) => table.orderId.equals(orderId))).get();
    await client.from('order_items').delete().eq('order_id', orderId);
    if (rows.isNotEmpty) {
      await client
          .from('order_items')
          .insert(
            rows
                .map(
                  (row) => {
                    'id': row.id,
                    'order_id': row.orderId,
                    'product_id': row.productId,
                    'product_name_snapshot': row.productNameSnapshot,
                    'unit_price_snapshot': row.unitPriceSnapshot,
                    'base_cost_snapshot': row.baseCostSnapshot,
                    'quantity': row.quantity,
                    'notes': row.notes,
                    'removed_ingredients_json': row.removedIngredientsJson,
                    'created_at': row.createdAt.toUtc().toIso8601String(),
                    'updated_at': row.updatedAt.toUtc().toIso8601String(),
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> _syncRemoteSaleItems(
    SupabaseClient client,
    String saleId,
  ) async {
    final rows = await (_database.select(
      _database.saleItems,
    )..where((table) => table.saleId.equals(saleId))).get();
    await client.from('sale_items').delete().eq('sale_id', saleId);
    if (rows.isNotEmpty) {
      await client
          .from('sale_items')
          .insert(
            rows
                .map(
                  (row) => {
                    'id': row.id,
                    'sale_id': row.saleId,
                    'product_id': row.productId,
                    'product_name_snapshot': row.productNameSnapshot,
                    'unit_price_snapshot': row.unitPriceSnapshot,
                    'unit_cost_snapshot': row.unitCostSnapshot,
                    'quantity': row.quantity,
                    'line_total': row.lineTotal,
                    'line_cost_total': row.lineCostTotal,
                    'created_at': row.createdAt.toUtc().toIso8601String(),
                    'updated_at': row.createdAt.toUtc().toIso8601String(),
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> _pullRemoteOperations() async {
    final client = _client;
    if (client == null) return;

    final ordersData = await client.from('orders').select().order('created_at');
    final orderItemsData = await client
        .from('order_items')
        .select()
        .order('created_at');
    final salesData = await client.from('sales').select().order('sold_at');
    final saleItemsData = await client
        .from('sale_items')
        .select()
        .order('created_at');
    final cashSessionsData = await client
        .from('cash_sessions')
        .select()
        .order('opened_at');
    final cashMovementsData = await client
        .from('cash_movements')
        .select()
        .order('created_at');

    await _database.transaction(() async {
      for (final row in ordersData) {
        if (await _syncQueueService.hasPendingFor(
          'orders',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.orders)
            .insertOnConflictUpdate(
              OrdersCompanion(
                id: Value(row['id'] as String),
                orderNumber: Value(row['order_number'] as String),
                status: Value(row['status'] as String? ?? 'pending'),
                notes: Value(row['notes'] as String?),
                totalEstimated: Value(
                  (row['total_estimated'] as num?)?.toDouble() ?? 0,
                ),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
              ),
            );
      }

      for (final row in orderItemsData) {
        if (await _syncQueueService.hasPendingFor(
          'order_items',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.orderItems)
            .insertOnConflictUpdate(
              OrderItemsCompanion(
                id: Value(row['id'] as String),
                orderId: Value(row['order_id'] as String),
                productId: Value(row['product_id'] as String?),
                productNameSnapshot: Value(
                  row['product_name_snapshot'] as String,
                ),
                unitPriceSnapshot: Value(
                  (row['unit_price_snapshot'] as num).toDouble(),
                ),
                baseCostSnapshot: Value(
                  (row['base_cost_snapshot'] as num?)?.toDouble() ?? 0,
                ),
                quantity: Value(row['quantity'] as int? ?? 1),
                notes: Value(row['notes'] as String?),
                removedIngredientsJson: Value(
                  (row['removed_ingredients_json'] ?? '[]').toString(),
                ),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
              ),
            );
      }

      for (final row in salesData) {
        if (await _syncQueueService.hasPendingFor(
          'sales',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.sales)
            .insertOnConflictUpdate(
              SalesCompanion(
                id: Value(row['id'] as String),
                saleNumber: Value(row['sale_number'] as String),
                sourceOrderId: Value(row['source_order_id'] as String?),
                totalAmount: Value((row['total_amount'] as num).toDouble()),
                estimatedCost: Value(
                  (row['estimated_cost'] as num?)?.toDouble() ?? 0,
                ),
                estimatedProfit: Value(
                  (row['estimated_profit'] as num?)?.toDouble() ?? 0,
                ),
                paymentMethod: Value(row['payment_method'] as String),
                paidAmount: Value(
                  (row['paid_amount'] as num?)?.toDouble() ?? 0,
                ),
                changeAmount: Value(
                  (row['change_amount'] as num?)?.toDouble() ?? 0,
                ),
                soldAt: Value(
                  DateTime.parse(row['sold_at'] as String).toLocal(),
                ),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
              ),
            );
      }

      for (final row in saleItemsData) {
        if (await _syncQueueService.hasPendingFor(
          'sale_items',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.saleItems)
            .insertOnConflictUpdate(
              SaleItemsCompanion(
                id: Value(row['id'] as String),
                saleId: Value(row['sale_id'] as String),
                productId: Value(row['product_id'] as String?),
                productNameSnapshot: Value(
                  row['product_name_snapshot'] as String,
                ),
                unitPriceSnapshot: Value(
                  (row['unit_price_snapshot'] as num).toDouble(),
                ),
                unitCostSnapshot: Value(
                  (row['unit_cost_snapshot'] as num?)?.toDouble() ?? 0,
                ),
                quantity: Value(row['quantity'] as int? ?? 1),
                lineTotal: Value((row['line_total'] as num?)?.toDouble() ?? 0),
                lineCostTotal: Value(
                  (row['line_cost_total'] as num?)?.toDouble() ?? 0,
                ),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
              ),
            );
      }

      for (final row in cashSessionsData) {
        if (await _syncQueueService.hasPendingFor(
          'cash_sessions',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.cashSessions)
            .insertOnConflictUpdate(
              CashSessionsCompanion(
                id: Value(row['id'] as String),
                openedAt: Value(
                  DateTime.parse(row['opened_at'] as String).toLocal(),
                ),
                openingAmount: Value(
                  (row['opening_amount'] as num?)?.toDouble() ?? 0,
                ),
                closedAt: Value(
                  row['closed_at'] == null
                      ? null
                      : DateTime.parse(row['closed_at'] as String).toLocal(),
                ),
                closingExpectedCash: Value(
                  (row['closing_expected_cash'] as num?)?.toDouble(),
                ),
                closingRealCash: Value(
                  (row['closing_real_cash'] as num?)?.toDouble(),
                ),
                transferTotal: Value(
                  (row['transfer_total'] as num?)?.toDouble() ?? 0,
                ),
                differenceAmount: Value(
                  (row['difference_amount'] as num?)?.toDouble(),
                ),
                status: Value(row['status'] as String? ?? 'open'),
                note: Value(row['note'] as String?),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
              ),
            );
      }

      for (final row in cashMovementsData) {
        if (await _syncQueueService.hasPendingFor(
          'cash_movements',
          row['id'] as String,
        )) {
          continue;
        }
        await _database
            .into(_database.cashMovements)
            .insertOnConflictUpdate(
              CashMovementsCompanion(
                id: Value(row['id'] as String),
                cashSessionId: Value(row['cash_session_id'] as String),
                movementType: Value(row['movement_type'] as String),
                paymentMethod: Value(row['payment_method'] as String?),
                amount: Value((row['amount'] as num?)?.toDouble() ?? 0),
                note: Value(row['note'] as String?),
                referenceType: Value(row['reference_type'] as String?),
                referenceId: Value(row['reference_id'] as String?),
                createdAt: Value(
                  DateTime.parse(row['created_at'] as String).toLocal(),
                ),
                updatedAt: Value(
                  DateTime.parse(row['updated_at'] as String).toLocal(),
                ),
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
    ref.watch(syncQueueServiceProvider),
  );
});
