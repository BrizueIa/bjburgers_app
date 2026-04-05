import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminModeProvider);
    final settings = ref.watch(appSettingsProvider);
    final sync = ref.watch(syncStatusProvider);
    final snapshotAsync = ref.watch(dashboardSnapshotProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.businessName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    admin.enabled
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                  ),
                  label: Text(admin.enabled ? 'Admin activo' : 'Admin apagado'),
                ),
                Chip(
                  avatar: Icon(
                    sync.isOnline
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 18,
                  ),
                  label: Text(sync.statusLabel),
                ),
              ],
            ),
          ),
        ],
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final cards = [
            _MetricCard(
              title: 'Ventas hoy',
              value: currency.format(snapshot.totalSalesToday),
              icon: Icons.point_of_sale_rounded,
            ),
            _MetricCard(
              title: 'Utilidad estimada',
              value: currency.format(snapshot.estimatedProfitToday),
              icon: Icons.trending_up_rounded,
            ),
            _MetricCard(
              title: 'Efectivo hoy',
              value: currency.format(snapshot.cashSalesToday),
              icon: Icons.payments_rounded,
            ),
            _MetricCard(
              title: 'Transferencias hoy',
              value: currency.format(snapshot.transferSalesToday),
              icon: Icons.account_balance_rounded,
            ),
            _MetricCard(
              title: 'Compras hoy',
              value: currency.format(snapshot.purchasesToday),
              icon: Icons.shopping_cart_rounded,
            ),
            _MetricCard(
              title: 'Pedidos hoy',
              value: '${snapshot.ordersToday}',
              icon: Icons.receipt_long_rounded,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8F2E15), Color(0xFFD57C2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operacion del dia',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.hasOpenCashSession
                          ? 'Caja activa con efectivo esperado de ${currency.format(snapshot.activeCashExpected)} y digital acumulado de ${currency.format(snapshot.activeCashTransfer)}.'
                          : 'No hay caja abierta. Abre una sesion para registrar ingresos y cortes.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatusPill(
                          label: 'Pendientes: ${snapshot.pendingOrders}',
                        ),
                        _StatusPill(
                          label: 'Listas para POS: ${snapshot.readyOrders}',
                        ),
                        _StatusPill(
                          label: snapshot.hasOpenCashSession
                              ? 'Caja abierta'
                              : 'Caja cerrada',
                        ),
                        if (snapshot.stockTrackingEnabled)
                          _StatusPill(
                            label: 'Stock bajo: ${snapshot.lowStockCount}',
                          ),
                        if (snapshot.stockTrackingEnabled)
                          _StatusPill(
                            label: 'Sin stock: ${snapshot.outOfStockCount}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 1.7 : 1.4,
                ),
                itemBuilder: (context, index) => cards[index],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Comandas',
                      rows: [
                        _SummaryRow(
                          label: 'Pendientes / preparando',
                          value: '${snapshot.pendingOrders}',
                        ),
                        _SummaryRow(
                          label: 'Listas para cobrar',
                          value: '${snapshot.readyOrders}',
                        ),
                        _SummaryRow(
                          label: 'Totales del dia',
                          value: '${snapshot.ordersToday}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Caja',
                      rows: [
                        _SummaryRow(
                          label: 'Efectivo esperado',
                          value: currency.format(snapshot.activeCashExpected),
                        ),
                        _SummaryRow(
                          label: 'Digital acumulado',
                          value: currency.format(snapshot.activeCashTransfer),
                        ),
                        _SummaryRow(
                          label: 'Estado',
                          value: snapshot.hasOpenCashSession
                              ? 'Abierta'
                              : 'Sin abrir',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows});

  final String title;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(row.label), Text(row.value)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
