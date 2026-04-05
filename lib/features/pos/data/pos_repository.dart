import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
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
  });

  final String id;
  final String saleNumber;
  final double totalAmount;
  final String paymentMethod;
  final DateTime soldAt;
  final String? sourceOrderId;
}

class PosRepository {
  PosRepository(this._database, this._cajaRepository, this._syncQueueService);

  final AppDatabase _database;
  final CajaRepository _cajaRepository;
  final SyncQueueService _syncQueueService;
  final Uuid _uuid = const Uuid();

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
    final query = _database.select(_database.sales)
      ..orderBy([(table) => OrderingTerm.desc(table.soldAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SaleSummary(
              id: row.id,
              saleNumber: row.saleNumber,
              totalAmount: row.totalAmount,
              paymentMethod: row.paymentMethod,
              soldAt: row.soldAt,
              sourceOrderId: row.sourceOrderId,
            ),
          )
          .toList(),
    );
  }

  Future<void> checkoutOrder({
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
  }
}

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(cajaRepositoryProvider),
    ref.watch(syncQueueServiceProvider),
  );
});
