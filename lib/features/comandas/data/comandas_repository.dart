import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../inventario/data/inventory_repository.dart';

class OrderDraftItem {
  const OrderDraftItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.baseCost,
    required this.quantity,
    this.notes,
    this.comboLabel,
    this.removedIngredients = const [],
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final double baseCost;
  final int quantity;
  final String? notes;
  final String? comboLabel;
  final List<String> removedIngredients;
}

class OrderItemSummary {
  const OrderItemSummary({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.baseCost,
    required this.quantity,
    required this.notes,
    required this.removedIngredients,
  });

  final String id;
  final String? productId;
  final String productName;
  final double unitPrice;
  final double baseCost;
  final int quantity;
  final String? notes;
  final List<String> removedIngredients;

  double get lineTotal => unitPrice * quantity;
  double get lineCost => baseCost * quantity;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.notes,
    required this.totalEstimated,
    required this.createdAt,
    required this.itemCount,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String? notes;
  final double totalEstimated;
  final DateTime createdAt;
  final int itemCount;

  bool get isReadyForCheckout => status == 'ready';
}

class ComandasRepository {
  ComandasRepository(this._database, this._syncQueueService);

  final AppDatabase _database;
  final SyncQueueService _syncQueueService;
  final Uuid _uuid = const Uuid();

  Stream<List<OrderSummary>> watchOrders() {
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
      GROUP BY o.id
      ORDER BY o.created_at DESC
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

  Stream<List<OrderSummary>> watchTodayOrders() {
    return Stream.multi((controller) {
      var latestOrders = const <OrderSummary>[];

      void emitTodayOrders() {
        final now = DateTime.now();
        controller.add(
          latestOrders
              .where((order) => _isSameLocalDate(order.createdAt, now))
              .toList(),
        );
      }

      final subscription = watchOrders().listen((orders) {
        latestOrders = orders;
        emitTodayOrders();
      }, onError: controller.addError);

      final timer = Timer.periodic(const Duration(minutes: 1), (_) {
        emitTodayOrders();
      });

      controller
        ..onPause = subscription.pause
        ..onResume = subscription.resume
        ..onCancel = () async {
          timer.cancel();
          await subscription.cancel();
        };
    });
  }

  Stream<List<OrderItemSummary>> watchOrderItems(String orderId) {
    final query = _database.select(_database.orderItems)
      ..where((table) => table.orderId.equals(orderId))
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);

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
              removedIngredients:
                  (jsonDecode(row.removedIngredientsJson) as List<dynamic>)
                      .map((item) => item.toString())
                      .toList(),
            ),
          )
          .toList(),
    );
  }

  Future<void> createOrder({
    required String? notes,
    required List<OrderDraftItem> items,
  }) async {
    if (items.isEmpty) return;

    final now = DateTime.now();
    final orderId = _uuid.v4();
    final orderNumber =
        'CMD-${now.microsecondsSinceEpoch.toString().substring(6)}';
    final totalEstimated = items.fold<double>(
      0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    await _database.transaction(() async {
      await _database
          .into(_database.orders)
          .insert(
            OrdersCompanion.insert(
              id: orderId,
              orderNumber: orderNumber,
              status: const Value('pending'),
              notes: Value(notes?.isEmpty ?? true ? null : notes),
              totalEstimated: Value(totalEstimated),
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final item in items) {
        final itemId = _uuid.v4();
        await _database
            .into(_database.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: itemId,
                orderId: orderId,
                productId: Value(item.productId),
                productNameSnapshot: item.productName,
                unitPriceSnapshot: item.unitPrice,
                baseCostSnapshot: Value(item.baseCost),
                quantity: Value(item.quantity),
                notes: Value(item.notes?.isEmpty ?? true ? null : item.notes),
                removedIngredientsJson: Value(
                  jsonEncode(item.removedIngredients),
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _syncQueueService.enqueue(
          entityType: 'order_items',
          entityId: itemId,
          operationType: 'upsert',
          payload: {
            'id': itemId,
            'order_id': orderId,
            'product_id': item.productId,
            'product_name_snapshot': item.productName,
            'unit_price_snapshot': item.unitPrice,
            'base_cost_snapshot': item.baseCost,
            'quantity': item.quantity,
            'notes': item.notes?.isEmpty ?? true ? null : item.notes,
            'removed_ingredients_json': jsonEncode(item.removedIngredients),
            'created_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
          },
        );
      }
    });

    await _syncQueueService.enqueue(
      entityType: 'orders',
      entityId: orderId,
      operationType: 'upsert',
      payload: {
        'id': orderId,
        'order_number': orderNumber,
        'status': 'pending',
        'notes': notes?.isEmpty ?? true ? null : notes,
        'total_estimated': totalEstimated,
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final now = DateTime.now();
    await (_database.update(_database.orders)
          ..where((table) => table.id.equals(orderId)))
        .write(OrdersCompanion(status: Value(status), updatedAt: Value(now)));
    final order = await (_database.select(
      _database.orders,
    )..where((table) => table.id.equals(orderId))).getSingle();
    await _syncQueueService.enqueue(
      entityType: 'orders',
      entityId: orderId,
      operationType: 'upsert',
      payload: {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': status,
        'notes': order.notes,
        'total_estimated': order.totalEstimated,
        'created_at': order.createdAt.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, 'cancelled');
  }

  Future<List<String>> fetchRecipeIngredientNames(String productId) async {
    final query = _database.select(_database.productRecipeItems).join([
      innerJoin(
        _database.ingredients,
        _database.ingredients.id.equalsExp(
          _database.productRecipeItems.ingredientId,
        ),
      ),
    ])..where(_database.productRecipeItems.productId.equals(productId));

    final rows = await query.get();
    return rows
        .map((row) => row.readTable(_database.ingredients).name)
        .toList();
  }

  Stream<List<ProductSummary>> watchSellableProducts() {
    const sql = '''
      SELECT
        p.id,
        p.name,
        p.category_name,
        p.product_type,
        p.sale_price,
        p.direct_cost,
        p.stock_quantity,
        p.track_stock,
        p.is_active,
        CASE
          WHEN p.product_type = 'simple' THEN p.direct_cost
          ELSE COALESCE(SUM(r.quantity_used * i.current_unit_cost), 0)
        END AS calculated_cost,
        COUNT(r.id) AS recipe_lines,
        CASE
          WHEN p.product_type = 'simple' THEN 1
          WHEN COUNT(r.id) = 0 THEN 1
          WHEN MIN(CASE
            WHEN i.stock_quantity IS NULL THEN 999999
            WHEN r.quantity_used <= 0 THEN 999999
            ELSE i.stock_quantity / r.quantity_used
          END) >= 1 THEN 1
          ELSE 0
        END AS is_in_stock
      FROM products p
      LEFT JOIN product_recipe_items r ON r.product_id = p.id
      LEFT JOIN ingredients i ON i.id = r.ingredient_id
      WHERE p.is_active = 1 AND p.deleted_at IS NULL
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
              stockQuantity: row.read<double?>('stock_quantity'),
              trackStock: row.read<bool>('track_stock'),
              isActive: row.read<bool>('is_active'),
              calculatedCost: calculatedCost,
              margin: salePrice - calculatedCost,
              recipeLines: row.read<int>('recipe_lines'),
              isInStock: row.read<int>('is_in_stock') == 1,
            );
          }).toList(),
        );
  }
}

bool _isSameLocalDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

final comandasRepositoryProvider = Provider<ComandasRepository>((ref) {
  return ComandasRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueServiceProvider),
  );
});
