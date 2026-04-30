import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1000;
    final isMobile = width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.businessName),
        actions: isMobile
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        admin.enabled
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        sync.isOnline
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ]
            : [
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
                        label: Text(
                          admin.enabled ? 'Admin activo' : 'Admin apagado',
                        ),
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
              compact: isMobile,
            ),
            _MetricCard(
              title: 'Utilidad estimada',
              value: currency.format(snapshot.estimatedProfitToday),
              icon: Icons.trending_up_rounded,
              compact: isMobile,
            ),
            _MetricCard(
              title: 'Efectivo hoy',
              value: currency.format(snapshot.cashSalesToday),
              icon: Icons.payments_rounded,
              compact: isMobile,
            ),
            _MetricCard(
              title: 'Transferencias hoy',
              value: currency.format(snapshot.transferSalesToday),
              icon: Icons.account_balance_rounded,
              compact: isMobile,
            ),
            _MetricCard(
              title: 'Compras hoy',
              value: currency.format(snapshot.purchasesToday),
              icon: Icons.shopping_cart_rounded,
              compact: isMobile,
            ),
            _MetricCard(
              title: 'Pedidos hoy',
              value: '${snapshot.ordersToday}',
              icon: Icons.receipt_long_rounded,
              compact: isMobile,
            ),
            if (isMobile) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoBadge(
                      icon: admin.enabled
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      label: admin.enabled ? 'Admin activo' : 'Admin apagado',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoBadge(
                      icon: sync.isOnline
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      label: sync.statusLabel,
                    ),
                  ),
                ],
              ),
            ],
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusPill(
                    icon: admin.enabled
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    label: admin.enabled ? 'Admin' : 'Lectura',
                  ),
                  _StatusPill(
                    icon: sync.isOnline
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    label: sync.isOnline ? 'Sync' : 'Offline',
                  ),
                  _StatusPill(
                    icon: snapshot.hasOpenCashSession
                        ? Icons.payments_rounded
                        : Icons.payments_outlined,
                    label: snapshot.hasOpenCashSession
                        ? 'Caja abierta'
                        : 'Caja cerrada',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isMobile)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.28,
                  ),
                  itemBuilder: (context, index) => cards[index],
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.95 : 1.75,
                  ),
                  itemBuilder: (context, index) => cards[index],
                ),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _SummaryCard(
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
                const SizedBox(height: 10),
                _SummaryCard(
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
              ] else
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
                    const SizedBox(width: 12),
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
    this.compact = false,
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
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
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
    return AppSectionCard(
      title: title,
      padding: const EdgeInsets.all(18),
      gap: 12,
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2C6A2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7A2E12)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
