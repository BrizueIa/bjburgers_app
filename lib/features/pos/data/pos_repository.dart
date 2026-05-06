import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/config/supabase_client_provider.dart';
import '../../../core/storage/local_settings_store.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../comandas/data/order_item_notes.dart';
import '../../caja/data/caja_repository.dart';
import '../../comandas/data/comandas_repository.dart';

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.saleNumber,
    required this.totalAmount,
    required this.paymentMethod,
    required this.soldAt,
    required this.sourceOrderId,
    required this.itemsSummary,
    required this.totalUnits,
  });

  final String id;
  final String saleNumber;
  final double totalAmount;
  final String paymentMethod;
  final DateTime soldAt;
  final String? sourceOrderId;
  final String? itemsSummary;
  final int totalUnits;
}

class PosRepository {
  PosRepository(
    this._database,
    this._cajaRepository,
    this._syncQueueService,
    this._localSettingsStore,
    this._supabaseClient,
  );

  final AppDatabase _database;
  final CajaRepository _cajaRepository;
  final SyncQueueService _syncQueueService;
  final LocalSettingsStore _localSettingsStore;
  final SupabaseClient? _supabaseClient;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();

  Stream<List<OrderSummary>> watchReadyOrders() {
    const sql = '''
      SELECT
        o.id,
        o.order_number,
        o.status,
        o.notes,
        o.total_estimated,
        o.created_at,
        COUNT(oi.id) AS item_count
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.status = 'ready'
      GROUP BY o.id
      ORDER BY o.created_at ASC
    ''';

    return _database
        .customSelect(sql, readsFrom: {_database.orders, _database.orderItems})
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => OrderSummary(
                  id: row.read<String>('id'),
                  orderNumber: row.read<String>('order_number'),
                  status: row.read<String>('status'),
                  notes: row.read<String?>('notes'),
                  totalEstimated: row.read<double>('total_estimated'),
                  createdAt: row.read<DateTime>('created_at'),
                  itemCount: row.read<int>('item_count'),
                ),
              )
              .toList(),
        );
  }

  Stream<List<OrderItemSummary>> watchOrderItems(String orderId) {
    final query = _database.select(_database.orderItems)
      ..where((table) => table.orderId.equals(orderId));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => OrderItemSummary(
              id: row.id,
              productId: row.productId,
              productName: row.productNameSnapshot,
              unitPrice: row.unitPriceSnapshot,
              baseCost: row.baseCostSnapshot,
              quantity: row.quantity,
              notes: row.notes,
              removedIngredients: const [],
            ),
          )
          .toList(),
    );
  }

  Stream<List<SaleSummary>> watchSales() {
    const sql = '''
      SELECT
        s.id,
        s.sale_number,
        s.total_amount,
        s.payment_method,
        s.sold_at,
        s.source_order_id,
        COALESCE(SUM(si.quantity), 0) AS total_units,
        GROUP_CONCAT(
          si.product_name_snapshot || ' x' || si.quantity,
          ' · '
        ) AS items_summary
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      GROUP BY s.id
      ORDER BY s.sold_at DESC
    ''';

    return _database
        .customSelect(sql, readsFrom: {_database.sales, _database.saleItems})
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => SaleSummary(
                  id: row.read<String>('id'),
                  saleNumber: row.read<String>('sale_number'),
                  totalAmount: row.read<double>('total_amount'),
                  paymentMethod: row.read<String>('payment_method'),
                  soldAt: row.read<DateTime>('sold_at'),
                  sourceOrderId: row.read<String?>('source_order_id'),
                  itemsSummary: row.read<String?>('items_summary'),
                  totalUnits: row.read<int>('total_units'),
                ),
              )
              .toList(),
        );
  }

  Future<String> checkoutOrder({
    required OrderSummary order,
    required String paymentMethod,
    required double paidAmount,
  }) async {
    final items = await (_database.select(
      _database.orderItems,
    )..where((table) => table.orderId.equals(order.id))).get();
    final now = DateTime.now();
    final total = items.fold<double>(
      0,
      (sum, item) => sum + (item.unitPriceSnapshot * item.quantity),
    );
    final estimatedCost = items.fold<double>(
      0,
      (sum, item) => sum + (item.baseCostSnapshot * item.quantity),
    );
    final saleId = _uuid.v4();
    final saleNumber =
        'VTA-${now.microsecondsSinceEpoch.toString().substring(6)}';
    final safePaid = paymentMethod == 'cash' ? paidAmount : total;
    final changeAmount = paymentMethod == 'cash'
        ? (safePaid - total).toDouble()
        : 0.0;

    await _database.transaction(() async {
      await _database
          .into(_database.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              saleNumber: saleNumber,
              sourceOrderId: Value(order.id),
              totalAmount: total,
              estimatedCost: Value(estimatedCost),
              estimatedProfit: Value(total - estimatedCost),
              paymentMethod: paymentMethod,
              paidAmount: Value(safePaid),
              changeAmount: Value(changeAmount),
              soldAt: now,
              createdAt: now,
            ),
          );

      for (final item in items) {
        await _database
            .into(_database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                id: _uuid.v4(),
                saleId: saleId,
                productId: Value(item.productId),
                productNameSnapshot: item.productNameSnapshot,
                unitPriceSnapshot: item.unitPriceSnapshot,
                unitCostSnapshot: Value(item.baseCostSnapshot),
                quantity: Value(item.quantity),
                lineTotal: Value(item.unitPriceSnapshot * item.quantity),
                lineCostTotal: Value(item.baseCostSnapshot * item.quantity),
                createdAt: now,
              ),
            );
      }

      await (_database.update(
        _database.orders,
      )..where((table) => table.id.equals(order.id))).write(
        OrdersCompanion(
          status: const Value('delivered'),
          updatedAt: Value(now),
        ),
      );

      await _cajaRepository.recordSaleMovement(
        paymentMethod: paymentMethod,
        amount: total,
        saleId: saleId,
      );

      await _applyStockConsumption(items, now);
    });

    await _syncQueueService.enqueue(
      entityType: 'sales',
      entityId: saleId,
      operationType: 'upsert',
      payload: {
        'id': saleId,
        'sale_number': saleNumber,
        'source_order_id': order.id,
        'total_amount': total,
        'estimated_cost': estimatedCost,
        'estimated_profit': total - estimatedCost,
        'payment_method': paymentMethod,
        'paid_amount': safePaid,
        'change_amount': changeAmount,
        'sold_at': now.toUtc().toIso8601String(),
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );

    await _syncQueueService.enqueue(
      entityType: 'orders',
      entityId: order.id,
      operationType: 'upsert',
      payload: {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': 'delivered',
        'notes': order.notes,
        'total_estimated': order.totalEstimated,
        'created_at': order.createdAt.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );

    return saleId;
  }

  Future<String> createSpinCode({
    int remainingSpins = 1,
    String? saleId,
  }) async {
    final client = _supabaseClient;
    if (client == null) {
      throw StateError('Supabase no configurado.');
    }

    for (var attempt = 0; attempt < 5; attempt += 1) {
      final code = _buildSpinCode();
      try {
        final response = await client
            .from('spin_codes')
            .insert({
              'code': code,
              'remaining_spins': remainingSpins,
              'is_active': true,
              if (saleId != null) 'sale_id': saleId,
            })
            .select('code')
            .single();
        return response['code'] as String;
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          continue;
        }
        if (error.code == '23503' && saleId != null) {
          final response = await client
              .from('spin_codes')
              .insert({
                'code': code,
                'remaining_spins': remainingSpins,
                'is_active': true,
              })
              .select('code')
              .single();
          return response['code'] as String;
        }
        rethrow;
      }
    }

    throw StateError('No se pudo generar el codigo.');
  }

  String _buildSpinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i += 1) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<void> _applyStockConsumption(
    List<OrderItem> items,
    DateTime now,
  ) async {
    if (!_localSettingsStore.read().stockTrackingEnabled) {
      return;
    }

    for (final item in items) {
      if (item.productId == null) continue;

      final product = await (_database.select(
        _database.products,
      )..where((table) => table.id.equals(item.productId!))).getSingleOrNull();
      if (product == null || product.deletedAt != null) continue;

      if (product.productType == 'simple' && product.trackStock) {
        final nextStock = ((product.stockQuantity ?? 0) - item.quantity)
            .clamp(0, 9999999)
            .toDouble();
        await (_database.update(
          _database.products,
        )..where((table) => table.id.equals(product.id))).write(
          ProductsCompanion(
            stockQuantity: Value(nextStock),
            updatedAt: Value(now),
          ),
        );
        await _syncQueueService.enqueue(
          entityType: 'products',
          entityId: product.id,
          operationType: 'upsert',
          payload: {
            'id': product.id,
            'name': product.name,
            'category_name': product.categoryName,
            'product_type': product.productType,
            'sale_price': product.salePrice,
            'direct_cost': product.directCost,
            'stock_quantity': nextStock,
            'track_stock': product.trackStock,
            'display_order': product.displayOrder,
            'is_active': product.isActive,
            'created_at': product.createdAt.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
            'deleted_at': product.deletedAt?.toUtc().toIso8601String(),
          },
        );
        continue;
      }

      if (product.productType == 'recipe') {
        final removedIngredientNames =
            (jsonDecode(item.removedIngredientsJson) as List<dynamic>)
                .map((entry) => entry.toString())
                .toSet();
        final recipeRows =
            await (_database.select(_database.productRecipeItems).join([
                  innerJoin(
                    _database.ingredients,
                    _database.ingredients.id.equalsExp(
                      _database.productRecipeItems.ingredientId,
                    ),
                  ),
                ])..where(
                  _database.productRecipeItems.productId.equals(product.id),
                ))
                .get();

        for (final row in recipeRows) {
          final recipeItem = row.readTable(_database.productRecipeItems);
          final ingredient = row.readTable(_database.ingredients);
          if (ingredient.deletedAt != null ||
              removedIngredientNames.contains(ingredient.name)) {
            continue;
          }
          if (ingredient.stockQuantity == null) {
            continue;
          }

          final consumed = recipeItem.quantityUsed * item.quantity;
          final nextStock = (ingredient.stockQuantity! - consumed)
              .clamp(0, 9999999)
              .toDouble();
          await (_database.update(
            _database.ingredients,
          )..where((table) => table.id.equals(ingredient.id))).write(
            IngredientsCompanion(
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
              'current_unit_cost': ingredient.currentUnitCost,
              'stock_quantity': nextStock,
              'is_active': ingredient.isActive,
              'created_at': ingredient.createdAt.toUtc().toIso8601String(),
              'updated_at': now.toUtc().toIso8601String(),
              'deleted_at': ingredient.deletedAt?.toUtc().toIso8601String(),
            },
          );
        }
      }

      await _consumeExtraStock(item, now);
    }
  }

  Future<void> _consumeExtraStock(OrderItem item, DateTime now) async {
    final extraProductIds = extractExtraProductIds(item.notes);
    if (extraProductIds.isEmpty) return;

    for (final extraProductId in extraProductIds) {
      if (extraProductId.isEmpty) continue;

      final extraProduct = await (_database.select(
        _database.products,
      )..where((table) => table.id.equals(extraProductId))).getSingleOrNull();
      if (extraProduct == null || extraProduct.deletedAt != null) continue;
      if (extraProduct.productType != 'simple' || !extraProduct.trackStock) {
        continue;
      }

      final nextStock = ((extraProduct.stockQuantity ?? 0) - item.quantity)
          .clamp(0, 9999999)
          .toDouble();
      await (_database.update(
        _database.products,
      )..where((table) => table.id.equals(extraProduct.id))).write(
        ProductsCompanion(
          stockQuantity: Value(nextStock),
          updatedAt: Value(now),
        ),
      );
      await _syncQueueService.enqueue(
        entityType: 'products',
        entityId: extraProduct.id,
        operationType: 'upsert',
        payload: {
          'id': extraProduct.id,
          'name': extraProduct.name,
          'category_name': extraProduct.categoryName,
          'product_type': extraProduct.productType,
          'sale_price': extraProduct.salePrice,
          'direct_cost': extraProduct.directCost,
          'stock_quantity': nextStock,
          'track_stock': extraProduct.trackStock,
          'display_order': extraProduct.displayOrder,
          'is_active': extraProduct.isActive,
          'created_at': extraProduct.createdAt.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
          'deleted_at': extraProduct.deletedAt?.toUtc().toIso8601String(),
        },
      );
    }
  }
}

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(cajaRepositoryProvider),
    ref.watch(syncQueueServiceProvider),
    ref.watch(localSettingsStoreProvider),
    ref.watch(supabaseClientProvider),
  );
});
