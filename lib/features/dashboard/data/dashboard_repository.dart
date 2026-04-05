import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

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
}

class DashboardRepository {
  DashboardRepository(this._database);

  final AppDatabase _database;

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
    final startIso = startOfDay.toIso8601String();

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
          variables: [Variable<String>(startIso)],
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
          variables: [Variable<String>(startIso)],
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
          variables: [Variable<String>(startIso)],
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
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(appDatabaseProvider));
});
