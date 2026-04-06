import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1000;
    final gridCount = width >= 1100
        ? 3
        : width >= 650
        ? 2
        : 1;

    Future<void> refreshData() async {
      ref.invalidate(reportSnapshotProvider);
      await ref.read(syncStatusProvider.notifier).synchronize();
      ref.invalidate(reportSnapshotProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            SegmentedButton<ReportRangePreset>(
              segments: const [
                ButtonSegment(
                  value: ReportRangePreset.today,
                  label: Text('Hoy'),
                ),
                ButtonSegment(
                  value: ReportRangePreset.yesterday,
                  label: Text('Ayer'),
                ),
                ButtonSegment(
                  value: ReportRangePreset.week,
                  label: Text('Semana'),
                ),
                ButtonSegment(
                  value: ReportRangePreset.month,
                  label: Text('Mes'),
                ),
              ],
              selected: {selectedRange},
              onSelectionChanged: (selection) {
                ref.read(reportRangeProvider.notifier).state = selection.first;
              },
            ),
            const SizedBox(height: 20),
            reportAsync.when(
              data: (report) {
                final cards = [
                  _ReportMetricCard(
                    title: 'Ventas',
                    value: currency.format(report.totalSales),
                    icon: Icons.payments_rounded,
                  ),
                  _ReportMetricCard(
                    title: 'Utilidad estimada',
                    value: currency.format(report.estimatedProfit),
                    icon: Icons.trending_up_rounded,
                  ),
                  _ReportMetricCard(
                    title: 'Compras',
                    value: currency.format(report.totalPurchases),
                    icon: Icons.shopping_basket_rounded,
                  ),
                  _ReportMetricCard(
                    title: 'Pedidos',
                    value: '${report.totalOrders}',
                    icon: Icons.receipt_long_rounded,
                  ),
                  _ReportMetricCard(
                    title: 'Ventas cobradas',
                    value: '${report.totalSalesCount}',
                    icon: Icons.point_of_sale_rounded,
                  ),
                  _ReportMetricCard(
                    title: 'Transferencias',
                    value: currency.format(report.transferSales),
                    icon: Icons.account_balance_rounded,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de ${report.range.label}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: width >= 650 ? 1.7 : 2.2,
                      ),
                      itemBuilder: (context, index) => cards[index],
                    ),
                    const SizedBox(height: 20),
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: _CashSessionsReportCard(
                              report: report,
                              currency: currency,
                              dateFormat: dateFormat,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _ProductsReportCard(report: report, currency: currency),
                      const SizedBox(height: 16),
                      _CashSessionsReportCard(
                        report: report,
                        currency: currency,
                        dateFormat: dateFormat,
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

class _ProductsReportCard extends StatelessWidget {
  const _ProductsReportCard({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productos mas vendidos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (report.topProducts.isEmpty)
              const Text('No hay ventas en este rango.')
            else
              ...report.topProducts.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.productName),
                  subtitle: Text('${product.quantity} unidades'),
                  trailing: Text(currency.format(product.salesAmount)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashSessionsReportCard extends StatelessWidget {
  const _CashSessionsReportCard({
    required this.report,
    required this.currency,
    required this.dateFormat,
  });

  final ReportSnapshot report;
  final NumberFormat currency;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesiones de caja',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (report.cashSessions.isEmpty)
              const Text('No hay sesiones de caja en este rango.')
            else
              ...report.cashSessions.map(
                (session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    session.status == 'open' ? 'Caja abierta' : 'Caja cerrada',
                  ),
                  subtitle: Text(dateFormat.format(session.openedAt)),
                  trailing: Text(currency.format(session.expectedCash)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(title),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
