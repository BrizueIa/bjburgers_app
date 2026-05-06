import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

enum ReportRangePreset { today, week, month }

class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  factory ReportDateRange.fromPreset(
    ReportRangePreset preset, {
    int offset = 0,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case ReportRangePreset.today:
        final targetStart = todayStart.subtract(Duration(days: offset));
        final targetEnd = targetStart.add(const Duration(days: 1));
        final isCurrentDay = offset == 0;
        return ReportDateRange(
          start: targetStart,
          end: isCurrentDay
              ? now
              : targetEnd.subtract(const Duration(milliseconds: 1)),
          label: isCurrentDay ? 'Hoy' : 'Hace $offset dia(s)',
        );
      case ReportRangePreset.week:
        final currentWeekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        final weekStart = currentWeekStart.subtract(Duration(days: 7 * offset));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final isCurrentWeek = offset == 0;
        return ReportDateRange(
          start: weekStart,
          end: isCurrentWeek
              ? now
              : weekEnd.subtract(const Duration(milliseconds: 1)),
          label: isCurrentWeek ? 'Esta semana' : 'Semana -$offset',
        );
      case ReportRangePreset.month:
        final monthStart = DateTime(now.year, now.month - offset, 1);
        final nextMonthStart = DateTime(
          monthStart.year,
          monthStart.month + 1,
          1,
        );
        final isCurrentMonth = offset == 0;
        return ReportDateRange(
          start: monthStart,
          end: isCurrentMonth
              ? now
              : nextMonthStart.subtract(const Duration(milliseconds: 1)),
          label: isCurrentMonth
              ? 'Este mes'
              : '${monthStart.month.toString().padLeft(2, '0')}/${monthStart.year}',
        );
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

class CategoryReportRow {
  const CategoryReportRow({
    required this.categoryName,
    required this.quantity,
    required this.salesAmount,
  });

  final String categoryName;
  final int quantity;
  final double salesAmount;
}

class PromoReportRow {
  const PromoReportRow({required this.promoName, required this.timesUsed});

  final String promoName;
  final int timesUsed;
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

class SaleDetailReportRow {
  const SaleDetailReportRow({
    required this.saleNumber,
    required this.paymentMethod,
    required this.soldAt,
    required this.totalAmount,
    required this.estimatedProfit,
    required this.totalUnits,
    required this.itemsSummary,
  });

  final String saleNumber;
  final String paymentMethod;
  final DateTime soldAt;
  final double totalAmount;
  final double estimatedProfit;
  final int totalUnits;
  final List<String> itemsSummary;
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
    required this.averageTicket,
    required this.peakHourLabel,
    required this.favoriteCategory,
    required this.favoritePromo,
    required this.topProducts,
    required this.categoryBreakdown,
    required this.promos,
    required this.cashSessions,
    required this.salesDetails,
    required this.ahorroTotal,
    required this.guardaditoTotal,
    required this.transferNetSales,
    required this.cashNetSales,
  });

  final ReportDateRange range;
  final double totalSales;
  final double cashSales;
  final double transferSales;
  final double totalPurchases;
  final double estimatedProfit;
  final int totalOrders;
  final int totalSalesCount;
  final double averageTicket;
  final String peakHourLabel;
  final String? favoriteCategory;
  final PromoReportRow? favoritePromo;
  final List<ProductReportRow> topProducts;
  final List<CategoryReportRow> categoryBreakdown;
  final List<PromoReportRow> promos;
  final List<CashReportRow> cashSessions;
  final List<SaleDetailReportRow> salesDetails;
  final double ahorroTotal;
  final double guardaditoTotal;
  final double transferNetSales;
  final double cashNetSales;
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

    final categoryRows = await _database
        .customSelect(
          '''
      SELECT
        COALESCE(p.category_name, 'Sin categoria') AS category_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.line_total) AS total_sales
      FROM sale_items si
      LEFT JOIN products p ON p.id = si.product_id
      WHERE si.created_at >= ? AND si.created_at <= ?
      GROUP BY COALESCE(p.category_name, 'Sin categoria')
      ORDER BY total_sales DESC, total_quantity DESC
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.saleItems, _database.products},
        )
        .get();

    final promoRows = await _database
        .customSelect(
          '''
      SELECT
        notes AS promo_name,
        COUNT(*) AS times_used
      FROM order_items
      WHERE created_at >= ? AND created_at <= ?
        AND notes IS NOT NULL
        AND notes LIKE 'Promo %'
      GROUP BY notes
      ORDER BY times_used DESC, promo_name ASC
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.orderItems},
        )
        .get();

    final peakHourRow = await _database
        .customSelect(
          '''
      SELECT
        strftime('%H:00', sold_at) AS hour_label,
        COUNT(*) AS hour_count
      FROM sales
      WHERE sold_at >= ? AND sold_at <= ?
      GROUP BY strftime('%H:00', sold_at)
      ORDER BY hour_count DESC, hour_label ASC
      LIMIT 1
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.sales},
        )
        .getSingleOrNull();

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

    final salesDetailsRows = await _database
        .customSelect(
          '''
      SELECT
        s.sale_number,
        s.payment_method,
        s.sold_at,
        s.total_amount,
        s.estimated_profit,
        COALESCE(SUM(si.quantity), 0) AS total_units,
        GROUP_CONCAT(si.product_name_snapshot || ' x' || si.quantity, ' · ') AS items_summary
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      WHERE s.sold_at >= ? AND s.sold_at <= ?
      GROUP BY s.id
      ORDER BY s.sold_at DESC
      ''',
          variables: [
            Variable<DateTime>(range.start),
            Variable<DateTime>(range.end),
          ],
          readsFrom: {_database.sales, _database.saleItems},
        )
        .get();

    final totalSalesCount = salesRow.read<int>('total_sales_count');
    final cashSales = salesRow.read<double>('cash_sales');
    final transferSales = salesRow.read<double>('transfer_sales');
    final ahorroTotal = (totalSalesCount * 50).toDouble();
    final guardaditoTotal = (totalSalesCount * 10).toDouble();
    final savingsTotal = ahorroTotal + guardaditoTotal;
    final transferNetSales = (transferSales - savingsTotal)
        .clamp(0, transferSales)
        .toDouble();
    final cashSavingsNeeded = (savingsTotal - transferSales)
        .clamp(0, savingsTotal)
        .toDouble();
    final cashNetSales = (cashSales - cashSavingsNeeded)
        .clamp(0, cashSales)
        .toDouble();

    return ReportSnapshot(
      range: range,
      totalSales: salesRow.read<double>('total_sales'),
      cashSales: cashSales,
      transferSales: transferSales,
      totalPurchases: purchasesRow.read<double>('total_purchases'),
      estimatedProfit: salesRow.read<double>('estimated_profit'),
      totalOrders: ordersRow.read<int>('total_orders'),
      totalSalesCount: totalSalesCount,
      averageTicket: totalSalesCount == 0
          ? 0
          : salesRow.read<double>('total_sales') / totalSalesCount,
      peakHourLabel: peakHourRow == null
          ? 'Sin datos'
          : _readString(peakHourRow, 'hour_label'),
      favoriteCategory: categoryRows.isEmpty
          ? null
          : _readString(categoryRows.first, 'category_name'),
      favoritePromo: promoRows.isEmpty
          ? null
          : PromoReportRow(
              promoName: _readString(promoRows.first, 'promo_name'),
              timesUsed: promoRows.first.read<int>('times_used'),
            ),
      topProducts: productsRows
          .map(
            (row) => ProductReportRow(
              productName: _readString(row, 'product_name_snapshot'),
              quantity: row.read<int>('total_quantity'),
              salesAmount: row.read<double>('total_sales'),
              costAmount: row.read<double>('total_cost'),
              estimatedProfit: row.read<double>('estimated_profit'),
            ),
          )
          .toList(),
      categoryBreakdown: categoryRows
          .map(
            (row) => CategoryReportRow(
              categoryName: _readString(row, 'category_name'),
              quantity: row.read<int>('total_quantity'),
              salesAmount: row.read<double>('total_sales'),
            ),
          )
          .toList(),
      promos: promoRows
          .map(
            (row) => PromoReportRow(
              promoName: _readString(row, 'promo_name'),
              timesUsed: row.read<int>('times_used'),
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
              status: _readString(row, 'status', fallback: 'unknown'),
            ),
          )
          .toList(),
      salesDetails: salesDetailsRows
          .map(
            (row) => SaleDetailReportRow(
              saleNumber: _readString(row, 'sale_number'),
              paymentMethod: _readString(
                row,
                'payment_method',
                fallback: 'cash',
              ),
              soldAt: row.read<DateTime>('sold_at'),
              totalAmount: row.read<double>('total_amount'),
              estimatedProfit: row.read<double>('estimated_profit'),
              totalUnits: row.read<int>('total_units'),
              itemsSummary: (_readString(
                row,
                'items_summary',
                fallback: '',
              )).split(' · ').where((item) => item.trim().isNotEmpty).toList(),
            ),
          )
          .toList(),
      ahorroTotal: ahorroTotal,
      guardaditoTotal: guardaditoTotal,
      transferNetSales: transferNetSales,
      cashNetSales: cashNetSales,
    );
  }
}

String _readString(
  QueryRow row,
  String column, {
  String fallback = 'Sin dato',
}) {
  final value = row.read<String?>(column)?.trim();
  if (value == null || value.isEmpty) return fallback;
  return value;
}

final reportesRepositoryProvider = Provider<ReportesRepository>((ref) {
  return ReportesRepository(ref.watch(appDatabaseProvider));
});
