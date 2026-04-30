import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/widgets/ui_cards.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../../data/reportes_repository.dart';
import '../controllers/reportes_controller.dart';

class ReportesScreen extends ConsumerWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(reportRangeProvider);
    final reportAsync = ref.watch(reportSnapshotProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1000;
    final isMobile = width < 700;

    Future<void> refreshData() async {
      ref.invalidate(reportSnapshotProvider);
      await ref.read(syncStatusProvider.notifier).synchronize();
      ref.invalidate(reportSnapshotProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          if (reportAsync.hasValue)
            IconButton(
              tooltip: 'Compartir',
              onPressed: () async {
                final report = reportAsync.value;
                if (report == null) return;
                await Share.share(
                  _buildReportShareText(report, currency),
                  subject: 'Reporte ${report.range.label} - BJ Burguers',
                );
              },
              icon: const Icon(Icons.share_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _ReportRangeSelector(
              selectedRange: selectedRange,
              onChanged: (selection) {
                ref.read(reportRangeProvider.notifier).state = selection;
              },
            ),
            const SizedBox(height: 14),
            reportAsync.when(
              data: (report) {
                final cards = [
                  _KpiCard(
                    title: 'Ventas',
                    value: currency.format(report.totalSales),
                    icon: Icons.payments_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Utilidad estimada',
                    value: currency.format(report.estimatedProfit),
                    icon: Icons.trending_up_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Compras',
                    value: currency.format(report.totalPurchases),
                    icon: Icons.shopping_basket_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Pedidos',
                    value: '${report.totalOrders}',
                    icon: Icons.receipt_long_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Ticket promedio',
                    value: currency.format(report.averageTicket),
                    icon: Icons.local_atm_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Hora pico',
                    value: report.peakHourLabel,
                    icon: Icons.schedule_rounded,
                    compact: isMobile,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportTopStrip(report: report, currency: currency),
                    const SizedBox(height: 14),
                    if (isMobile)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.18,
                            ),
                        itemBuilder: (context, index) => cards[index],
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isWide ? 1.55 : 2.0,
                        ),
                        itemBuilder: (context, index) => cards[index],
                      ),
                    const SizedBox(height: 14),
                    _InsightCard(report: report, currency: currency),
                    const SizedBox(height: 12),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _PromoReportCard(report: report)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CategoryBreakdownCard(
                              report: report,
                              currency: currency,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _PromoReportCard(report: report),
                      const SizedBox(height: 12),
                      _CategoryBreakdownCard(
                        report: report,
                        currency: currency,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ProductsReportCard(
                              report: report,
                              currency: currency,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CashSessionsReportCard(
                              report: report,
                              currency: currency,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _ProductsReportCard(report: report, currency: currency),
                      const SizedBox(height: 12),
                      _CashSessionsReportCard(
                        report: report,
                        currency: currency,
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => Center(child: Text('$error')),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.compact,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: scheme.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final top = report.topProducts.isEmpty ? null : report.topProducts.first;
    final net = report.totalSales - report.totalPurchases;
    final favoritePromo = report.favoritePromo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _InsightRow(
              label: 'Ingreso neto vs compras',
              value: currency.format(net),
            ),
            _InsightRow(
              label: 'Metodo mas fuerte',
              value: report.cashSales >= report.transferSales
                  ? 'Efectivo'
                  : 'Transferencia',
            ),
            _InsightRow(
              label: 'Producto lider',
              value: top == null
                  ? 'Sin ventas'
                  : '${top.productName} · ${top.quantity} uds',
            ),
            _InsightRow(
              label: 'Categoria dominante',
              value: report.favoriteCategory ?? 'Sin datos',
            ),
            _InsightRow(
              label: 'Promo favorita',
              value: favoritePromo == null
                  ? 'Sin promos registradas'
                  : '${favoritePromo.promoName} · ${favoritePromo.timesUsed} usos',
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoReportCard extends StatelessWidget {
  const _PromoReportCard({required this.report});

  final ReportSnapshot report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promociones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (report.promos.isEmpty)
              const SizedBox.shrink()
            else
              ...report.promos.map(
                (promo) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_offer_rounded),
                  title: Text(promo.promoName),
                  trailing: Text('${promo.timesUsed} usos'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categorias', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (report.categoryBreakdown.isEmpty)
              const Text('No hay categorias vendidas en este rango.')
            else
              ...report.categoryBreakdown.map(
                (category) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(category.categoryName),
                  subtitle: Text('${category.quantity} unidades'),
                  trailing: Text(currency.format(category.salesAmount)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRangeSelector extends StatelessWidget {
  const _ReportRangeSelector({
    required this.selectedRange,
    required this.onChanged,
  });

  final ReportRangePreset selectedRange;
  final ValueChanged<ReportRangePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final range in const [
            ReportRangePreset.today,
            ReportRangePreset.yesterday,
            ReportRangePreset.week,
            ReportRangePreset.month,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_rangeLabel(range)),
                selected: selectedRange == range,
                onSelected: (_) => onChanged(range),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportTopStrip extends StatelessWidget {
  const _ReportTopStrip({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppMiniStatCard(label: 'Rango', value: report.range.label),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppMiniStatCard(
            label: 'Ventas',
            value: '${report.totalSalesCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppMiniStatCard(
            label: 'Caja',
            value: currency.format(report.cashSales),
          ),
        ),
      ],
    );
  }
}

String _rangeLabel(ReportRangePreset range) {
  switch (range) {
    case ReportRangePreset.today:
      return 'Hoy';
    case ReportRangePreset.yesterday:
      return 'Ayer';
    case ReportRangePreset.week:
      return 'Semana';
    case ReportRangePreset.month:
      return 'Mes';
  }
}

class _ProductsReportCard extends StatelessWidget {
  const _ProductsReportCard({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productos mas vendidos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (report.topProducts.isEmpty)
              const Text('No hay ventas en este rango.')
            else
              ...report.topProducts.map(
                (product) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.productName),
                  subtitle: Text(
                    '${product.quantity} unidades · costo ${currency.format(product.costAmount)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(product.salesAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('Util. ${currency.format(product.estimatedProfit)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashSessionsReportCard extends StatelessWidget {
  const _CashSessionsReportCard({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesiones de caja',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (report.cashSessions.isEmpty)
              const Text('No hay sesiones de caja en este rango.')
            else
              ...report.cashSessions.map(
                (session) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    session.status == 'open' ? 'Caja abierta' : 'Caja cerrada',
                  ),
                  subtitle: Text(dateFormat.format(session.openedAt)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(session.expectedCash),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('Transf. ${currency.format(session.transferTotal)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _buildReportShareText(ReportSnapshot report, NumberFormat currency) {
  final top = report.topProducts.isEmpty ? null : report.topProducts.first;
  final lines = <String>[
    'BJ BURGUERS',
    'Reporte ${report.range.label}',
    '',
    'Ventas: ${currency.format(report.totalSales)}',
    'Utilidad estimada: ${currency.format(report.estimatedProfit)}',
    'Efectivo: ${currency.format(report.cashSales)}',
    'Transferencias: ${currency.format(report.transferSales)}',
    'Compras: ${currency.format(report.totalPurchases)}',
    'Pedidos: ${report.totalOrders}',
    'Ventas cobradas: ${report.totalSalesCount}',
  ];

  if (top != null) {
    lines.add('Producto lider: ${top.productName} (${top.quantity} uds)');
  }

  if (report.favoriteCategory != null) {
    lines.add('Categoria dominante: ${report.favoriteCategory}');
  }

  if (report.favoritePromo != null) {
    lines.add(
      'Promo favorita: ${report.favoritePromo!.promoName} (${report.favoritePromo!.timesUsed} usos)',
    );
  }

  lines.add('Ticket promedio: ${currency.format(report.averageTicket)}');
  lines.add('Hora pico: ${report.peakHourLabel}');

  if (report.cashSessions.isNotEmpty) {
    final latest = report.cashSessions.first;
    lines.add(
      'Caja: ${latest.status == 'open' ? 'Abierta' : 'Cerrada'} · efectivo ${currency.format(latest.expectedCash)}',
    );
  }

  return lines.join('\n');
}
