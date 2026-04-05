import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          SegmentedButton<ReportRangePreset>(
            segments: const [
              ButtonSegment(value: ReportRangePreset.today, label: Text('Hoy')),
              ButtonSegment(
                value: ReportRangePreset.yesterday,
                label: Text('Ayer'),
              ),
              ButtonSegment(
                value: ReportRangePreset.week,
                label: Text('Semana'),
              ),
              ButtonSegment(value: ReportRangePreset.month, label: Text('Mes')),
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.7,
                        ),
                    itemBuilder: (context, index) => cards[index],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
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
                                      subtitle: Text(
                                        '${product.quantity} unidades',
                                      ),
                                      trailing: Text(
                                        currency.format(product.salesAmount),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
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
                                  const Text(
                                    'No hay sesiones de caja en este rango.',
                                  )
                                else
                                  ...report.cashSessions.map(
                                    (session) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        session.status == 'open'
                                            ? 'Caja abierta'
                                            : 'Caja cerrada',
                                      ),
                                      subtitle: Text(
                                        dateFormat.format(session.openedAt),
                                      ),
                                      trailing: Text(
                                        currency.format(session.expectedCash),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
