import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
                  _KpiCard(
                    title: 'Ventas',
                    value: currency.format(report.totalSales),
                    helper: '${report.totalSalesCount} tickets',
                    icon: Icons.payments_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Utilidad estimada',
                    value: currency.format(report.estimatedProfit),
                    helper: 'Margen operativo',
                    icon: Icons.trending_up_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Compras',
                    value: currency.format(report.totalPurchases),
                    helper: 'Surtido registrado',
                    icon: Icons.shopping_basket_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Pedidos',
                    value: '${report.totalOrders}',
                    helper: 'Comandas del rango',
                    icon: Icons.receipt_long_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Ticket promedio',
                    value: currency.format(report.averageTicket),
                    helper: 'Promedio por venta',
                    icon: Icons.local_atm_rounded,
                    compact: isMobile,
                  ),
                  _KpiCard(
                    title: 'Hora pico',
                    value: report.peakHourLabel,
                    helper: 'Momento mas activo',
                    icon: Icons.schedule_rounded,
                    compact: isMobile,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportHero(report: report, currency: currency),
                    const SizedBox(height: 18),
                    if (isMobile)
                      Column(
                        children: [
                          for (final card in cards) ...[
                            card,
                            const SizedBox(height: 12),
                          ],
                        ],
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isWide ? 1.55 : 2.0,
                        ),
                        itemBuilder: (context, index) => cards[index],
                      ),
                    const SizedBox(height: 20),
                    _InsightCard(report: report, currency: currency),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _PromoReportCard(report: report)),
                          const SizedBox(width: 16),
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
                      const SizedBox(height: 16),
                      _CategoryBreakdownCard(
                        report: report,
                        currency: currency,
                      ),
                      const SizedBox(height: 16),
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
                          const SizedBox(width: 16),
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
                      const SizedBox(height: 16),
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

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report, required this.currency});

  final ReportSnapshot report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1208), Color(0xFF5A2208), Color(0xFFF28C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'REPORTE · ${report.range.label.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            currency.format(report.totalSales),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingresos del periodo con ${report.totalSalesCount} ventas cobradas y ${report.totalOrders} comandas registradas.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(label: 'Efectivo ${currency.format(report.cashSales)}'),
              _HeroPill(
                label: 'Transfer ${currency.format(report.transferSales)}',
              ),
              _HeroPill(
                label: 'Compras ${currency.format(report.totalPurchases)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.compact,
  });

  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: compact
            ? Row(
                children: [
                  _KpiIcon(icon: icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(helper),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiIcon(icon: icon),
                  const SizedBox(height: 14),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(helper),
                ],
              ),
      ),
    );
  }
}

class _KpiIcon extends StatelessWidget {
  const _KpiIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC14D), Color(0xFFF28C00)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: const Color(0xFF1A1208)),
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
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lectura rapida',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promociones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (report.promos.isEmpty)
              const Text('No se registraron promociones en este rango.')
            else
              ...report.promos.map(
                (promo) => ListTile(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categorias', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (report.categoryBreakdown.isEmpty)
              const Text('No hay categorias vendidas en este rango.')
            else
              ...report.categoryBreakdown.map(
                (category) => ListTile(
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
      padding: const EdgeInsets.only(bottom: 12),
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
