import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/storage/local_settings_store.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalSalesToday,
    required this.cashSalesToday,
    required this.transferSalesToday,
    required this.estimatedProfitToday,
    required this.ordersToday,
    required this.readyOrders,
    required this.pendingOrders,
    required this.purchasesToday,
    required this.activeCashExpected,
    required this.activeCashTransfer,
    required this.hasOpenCashSession,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockTrackingEnabled,
  });

  final double totalSalesToday;
  final double cashSalesToday;
  final double transferSalesToday;
  final double estimatedProfitToday;
  final int ordersToday;
  final int readyOrders;
  final int pendingOrders;
  final double purchasesToday;
  final double activeCashExpected;
  final double activeCashTransfer;
  final bool hasOpenCashSession;
  final int lowStockCount;
  final int outOfStockCount;
  final bool stockTrackingEnabled;
}

class DashboardRepository {
  DashboardRepository(this._database, this._localSettingsStore);

  final AppDatabase _database;
  final LocalSettingsStore _localSettingsStore;

  Stream<DashboardSnapshot> watchSnapshot() {
    return Stream<DashboardSnapshot>.multi((controller) async {
      controller.add(await fetchSnapshot());
      await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
        if (controller.isClosed) {
          break;
        }
        controller.add(await fetchSnapshot());
      }
    });
  }

  Future<DashboardSnapshot> fetchSnapshot() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final salesRow = await _database
        .customSelect(
          '''
      SELECT
        COALESCE(SUM(total_amount), 0) AS total_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0) AS cash_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0) AS transfer_sales,
        COALESCE(SUM(estimated_profit), 0) AS estimated_profit
      FROM sales
      WHERE sold_at >= ?
      ''',
          variables: [Variable<DateTime>(startOfDay)],
          readsFrom: {_database.sales},
        )
        .getSingle();

    final ordersRow = await _database
        .customSelect(
          '''
      SELECT
        COUNT(*) AS total_orders,
        COALESCE(SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END), 0) AS ready_orders,
        COALESCE(SUM(CASE WHEN status IN ('pending', 'preparing') THEN 1 ELSE 0 END), 0) AS pending_orders
      FROM orders
      WHERE created_at >= ?
      ''',
          variables: [Variable<DateTime>(startOfDay)],
          readsFrom: {_database.orders},
        )
        .getSingle();

    final purchasesRow = await _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(total_cost), 0) AS purchases_total
      FROM ingredient_purchases
      WHERE purchased_at >= ?
      ''',
          variables: [Variable<DateTime>(startOfDay)],
          readsFrom: {_database.ingredientPurchases},
        )
        .getSingle();

    final cashRows = await _database
        .customSelect(
          '''
      SELECT
        cs.id,
        cs.opening_amount,
        cs.transfer_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'sale' AND cm.payment_method = 'cash' THEN cm.amount ELSE 0 END), 0) AS cash_sales_total,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'deposit' THEN cm.amount ELSE 0 END), 0) AS manual_deposits,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'withdrawal' THEN cm.amount ELSE 0 END), 0) AS manual_withdrawals,
        COALESCE(SUM(CASE WHEN cm.movement_type = 'adjustment' THEN cm.amount ELSE 0 END), 0) AS manual_adjustments
      FROM cash_sessions cs
      LEFT JOIN cash_movements cm ON cm.cash_session_id = cs.id
      WHERE cs.status = 'open'
      GROUP BY cs.id
      LIMIT 1
      ''',
          readsFrom: {_database.cashSessions, _database.cashMovements},
        )
        .get();

    double activeCashExpected = 0;
    double activeCashTransfer = 0;
    bool hasOpenCashSession = false;
    final stockTrackingEnabled = _localSettingsStore
        .read()
        .stockTrackingEnabled;
    var lowStockCount = 0;
    var outOfStockCount = 0;

    if (cashRows.isNotEmpty) {
      final row = cashRows.first;
      hasOpenCashSession = true;
      activeCashTransfer = row.read<double>('transfer_total');
      activeCashExpected =
          row.read<double>('opening_amount') +
          row.read<double>('cash_sales_total') +
          row.read<double>('manual_deposits') +
          row.read<double>('manual_adjustments') -
          row.read<double>('manual_withdrawals');
    }

    if (stockTrackingEnabled) {
      final lowIngredients = await _database
          .customSelect(
            '''
        SELECT
          COALESCE(SUM(CASE WHEN stock_quantity > 0 AND stock_quantity <= 5 THEN 1 ELSE 0 END), 0) AS low_count,
          COALESCE(SUM(CASE WHEN stock_quantity <= 0 THEN 1 ELSE 0 END), 0) AS out_count
        FROM ingredients
        WHERE deleted_at IS NULL AND is_active = 1 AND stock_quantity IS NOT NULL
        ''',
            readsFrom: {_database.ingredients},
          )
          .getSingle();

      final lowProducts = await _database
          .customSelect(
            '''
        SELECT
          COALESCE(SUM(CASE WHEN track_stock = 1 AND stock_quantity > 0 AND stock_quantity <= 5 THEN 1 ELSE 0 END), 0) AS low_count,
          COALESCE(SUM(CASE WHEN track_stock = 1 AND stock_quantity <= 0 THEN 1 ELSE 0 END), 0) AS out_count
        FROM products
        WHERE deleted_at IS NULL AND is_active = 1
        ''',
            readsFrom: {_database.products},
          )
          .getSingle();

      lowStockCount =
          lowIngredients.read<int>('low_count') +
          lowProducts.read<int>('low_count');
      outOfStockCount =
          lowIngredients.read<int>('out_count') +
          lowProducts.read<int>('out_count');
    }

    return DashboardSnapshot(
      totalSalesToday: salesRow.read<double>('total_sales'),
      cashSalesToday: salesRow.read<double>('cash_sales'),
      transferSalesToday: salesRow.read<double>('transfer_sales'),
      estimatedProfitToday: salesRow.read<double>('estimated_profit'),
      ordersToday: ordersRow.read<int>('total_orders'),
      readyOrders: ordersRow.read<int>('ready_orders'),
      pendingOrders: ordersRow.read<int>('pending_orders'),
      purchasesToday: purchasesRow.read<double>('purchases_total'),
      activeCashExpected: activeCashExpected,
      activeCashTransfer: activeCashTransfer,
      hasOpenCashSession: hasOpenCashSession,
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      stockTrackingEnabled: stockTrackingEnabled,
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(localSettingsStoreProvider),
  );
});
