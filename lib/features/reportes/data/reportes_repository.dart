import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

enum ReportRangePreset { today, yesterday, week, month }

class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  factory ReportDateRange.fromPreset(ReportRangePreset preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case ReportRangePreset.today:
        return ReportDateRange(start: todayStart, end: now, label: 'Hoy');
      case ReportRangePreset.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        return ReportDateRange(
          start: yesterdayStart,
          end: todayStart.subtract(const Duration(milliseconds: 1)),
          label: 'Ayer',
        );
      case ReportRangePreset.week:
        final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        return ReportDateRange(
          start: weekStart,
          end: now,
          label: 'Esta semana',
        );
      case ReportRangePreset.month:
        final monthStart = DateTime(now.year, now.month, 1);
        return ReportDateRange(start: monthStart, end: now, label: 'Este mes');
    }
  }
}

class ProductReportRow {
  const ProductReportRow({
    required this.productName,
    required this.quantity,
    required this.salesAmount,
    required this.costAmount,
    required this.estimatedProfit,
  });

  final String productName;
  final int quantity;
  final double salesAmount;
  final double costAmount;
  final double estimatedProfit;
}

class CashReportRow {
  const CashReportRow({
    required this.openedAt,
    required this.closedAt,
    required this.expectedCash,
    required this.realCash,
    required this.difference,
    required this.transferTotal,
    required this.status,
  });

  final DateTime openedAt;
  final DateTime? closedAt;
  final double expectedCash;
  final double? realCash;
  final double? difference;
  final double transferTotal;
  final String status;
}

class ReportSnapshot {
  const ReportSnapshot({
    required this.range,
    required this.totalSales,
    required this.cashSales,
    required this.transferSales,
    required this.totalPurchases,
    required this.estimatedProfit,
    required this.totalOrders,
    required this.totalSalesCount,
    required this.topProducts,
    required this.cashSessions,
  });

  final ReportDateRange range;
  final double totalSales;
  final double cashSales;
  final double transferSales;
  final double totalPurchases;
  final double estimatedProfit;
  final int totalOrders;
  final int totalSalesCount;
  final List<ProductReportRow> topProducts;
  final List<CashReportRow> cashSessions;
}

class ReportesRepository {
  ReportesRepository(this._database);

  final AppDatabase _database;

  Future<ReportSnapshot> fetchReport(ReportDateRange range) async {
    final salesRow = await _database
        .customSelect(
          '''
      SELECT
        COUNT(*) AS total_sales_count,
        COALESCE(SUM(total_amount), 0) AS total_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total_amount ELSE 0 END), 0) AS cash_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total_amount ELSE 0 END), 0) AS transfer_sales,
        COALESCE(SUM(estimated_profit), 0) AS estimated_profit
      FROM sales
      WHERE sold_at >= ? AND sold_at <= ?
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.sales},
        )
        .getSingle();

    final ordersRow = await _database
        .customSelect(
          '''
      SELECT COUNT(*) AS total_orders
      FROM orders
      WHERE created_at >= ? AND created_at <= ?
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.orders},
        )
        .getSingle();

    final purchasesRow = await _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(total_cost), 0) AS total_purchases
      FROM ingredient_purchases
      WHERE purchased_at >= ? AND purchased_at <= ?
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.ingredientPurchases},
        )
        .getSingle();

    final productsRows = await _database
        .customSelect(
          '''
      SELECT
        product_name_snapshot,
        SUM(quantity) AS total_quantity,
        SUM(line_total) AS total_sales,
        SUM(line_cost_total) AS total_cost,
        SUM(line_total - line_cost_total) AS estimated_profit
      FROM sale_items
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY product_name_snapshot
      ORDER BY total_quantity DESC, total_sales DESC
      LIMIT 10
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.saleItems},
        )
        .get();

    final cashRows = await _database
        .customSelect(
          '''
      SELECT
        opened_at,
        closed_at,
        closing_expected_cash,
        closing_real_cash,
        difference_amount,
        transfer_total,
        status
      FROM cash_sessions
      WHERE opened_at >= ? AND opened_at <= ?
      ORDER BY opened_at DESC
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.cashSessions},
        )
        .get();

    return ReportSnapshot(
      range: range,
      totalSales: salesRow.read<double>('total_sales'),
      cashSales: salesRow.read<double>('cash_sales'),
      transferSales: salesRow.read<double>('transfer_sales'),
      totalPurchases: purchasesRow.read<double>('total_purchases'),
      estimatedProfit: salesRow.read<double>('estimated_profit'),
      totalOrders: ordersRow.read<int>('total_orders'),
      totalSalesCount: salesRow.read<int>('total_sales_count'),
      topProducts: productsRows
          .map(
            (row) => ProductReportRow(
              productName: row.read<String>('product_name_snapshot'),
              quantity: row.read<int>('total_quantity'),
              salesAmount: row.read<double>('total_sales'),
              costAmount: row.read<double>('total_cost'),
              estimatedProfit: row.read<double>('estimated_profit'),
            ),
          )
          .toList(),
      cashSessions: cashRows
          .map(
            (row) => CashReportRow(
              openedAt: row.read<DateTime>('opened_at'),
              closedAt: row.read<DateTime?>('closed_at'),
              expectedCash: row.read<double?>('closing_expected_cash') ?? 0,
              realCash: row.read<double?>('closing_real_cash'),
              difference: row.read<double?>('difference_amount'),
              transferTotal: row.read<double>('transfer_total'),
              status: row.read<String>('status'),
            ),
          )
          .toList(),
    );
  }
}

final reportesRepositoryProvider = Provider<ReportesRepository>((ref) {
  return ReportesRepository(ref.watch(appDatabaseProvider));
});
