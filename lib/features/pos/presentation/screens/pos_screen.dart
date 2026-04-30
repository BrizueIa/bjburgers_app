import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
import '../../../comandas/data/comandas_repository.dart';
import '../../data/pos_repository.dart';
import '../controllers/pos_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedOrderId;
  String _paymentMethod = 'cash';
  final TextEditingController _paidController = TextEditingController();
  late final TabController _mobileTabController;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyOrdersAsync = ref.watch(readyOrdersProvider);
    final salesAsync = ref.watch(salesHistoryProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final checkout = _CheckoutPanel(
            selectedOrderId: _selectedOrderId,
            paymentMethod: _paymentMethod,
            paidController: _paidController,
            currency: currency,
            onPaymentMethodChanged: (value) {
              setState(() => _paymentMethod = value);
            },
            onPaidChanged: () => setState(() {}),
            onCheckoutComplete: () {
              setState(() {
                _selectedOrderId = null;
                _paymentMethod = 'cash';
              });
            },
          );

          final queue = _ReadyOrdersList(
            currency: currency,
            readyOrdersAsync: readyOrdersAsync,
            selectedOrderId: _selectedOrderId,
            onSelect: (orderId) {
              setState(() {
                _selectedOrderId = orderId;
                _paidController.clear();
                _paymentMethod = 'cash';
              });
              if (!isWide) {
                _mobileTabController.animateTo(1);
              }
            },
          );

          final sales = _SalesHistory(
            currency: currency,
            salesAsync: salesAsync,
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 4, child: queue),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: checkout),
                const VerticalDivider(width: 1),
                Expanded(flex: 3, child: sales),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: AppMiniStatCard(
                        label: 'Listas',
                        value: '${readyOrdersAsync.valueOrNull?.length ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppMiniStatCard(
                        label: 'Seleccion',
                        value: _selectedOrderId == null ? '-' : 'Activa',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppMiniStatCard(
                        label: 'Pago',
                        value: _paymentMethod == 'cash'
                            ? 'Efectivo'
                            : 'Transfer',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TabBar(
                  controller: _mobileTabController,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Cola'),
                    Tab(text: 'Cobro'),
                    Tab(text: 'Ventas'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _mobileTabController,
                  children: [queue, checkout, sales],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadyOrdersList extends StatelessWidget {
  const _ReadyOrdersList({
    required this.currency,
    required this.readyOrdersAsync,
    required this.selectedOrderId,
    required this.onSelect,
  });

  final NumberFormat currency;
  final AsyncValue<List<OrderSummary>> readyOrdersAsync;
  final String? selectedOrderId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return readyOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Text('No hay comandas listas para cobrar.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final selected = order.id == selectedOrderId;
            final scheme = Theme.of(context).colorScheme;
            return Card(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(order.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.onPrimaryContainer.withValues(
                                  alpha: 0.08,
                                )
                              : scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${order.itemCount}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(order.totalEstimated),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _CheckoutPanel extends ConsumerWidget {
  const _CheckoutPanel({
    required this.selectedOrderId,
    required this.paymentMethod,
    required this.paidController,
    required this.currency,
    required this.onPaymentMethodChanged,
    required this.onPaidChanged,
    required this.onCheckoutComplete,
  });

  final String? selectedOrderId;
  final String paymentMethod;
  final TextEditingController paidController;
  final NumberFormat currency;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onPaidChanged;
  final VoidCallback onCheckoutComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedOrderId == null) {
      return const Center(child: Icon(Icons.point_of_sale_rounded, size: 36));
    }

    final readyOrders =
        ref.watch(readyOrdersProvider).valueOrNull ?? const <OrderSummary>[];
    final order = readyOrders
        .where((item) => item.id == selectedOrderId)
        .firstOrNull;
    if (order == null) {
      return const Center(child: Text('Comanda no disponible.'));
    }
    final itemsAsync = ref.watch(posOrderItemsProvider(selectedOrderId!));

    return itemsAsync.when(
      data: (items) {
        final total = items.fold<double>(
          0,
          (sum, item) => sum + item.lineTotal,
        );
        final received = paymentMethod == 'cash'
            ? (double.tryParse(paidController.text.trim()) ?? 0)
            : total;
        final change = paymentMethod == 'cash' ? (received - total) : 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _CheckoutHeader(order: order, total: total, currency: currency),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${item.quantity}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName),
                                    if (item.removedIngredients.isNotEmpty)
                                      Text(
                                        'Sin: ${item.removedIngredients.join(', ')}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(currency.format(item.lineTotal)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'cash',
                          label: Text('Efectivo'),
                          icon: Icon(Icons.payments_rounded),
                        ),
                        ButtonSegment(
                          value: 'transfer',
                          label: Text('Transferencia'),
                          icon: Icon(Icons.account_balance_rounded),
                        ),
                      ],
                      selected: {paymentMethod},
                      onSelectionChanged: (selection) =>
                          onPaymentMethodChanged(selection.first),
                    ),
                    const SizedBox(height: 12),
                    if (paymentMethod == 'cash')
                      TextField(
                        controller: paidController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monto recibido',
                        ),
                        onChanged: (_) => onPaidChanged(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cambio'),
                        Text(currency.format(change < 0 ? 0 : change)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: paymentMethod == 'cash' && received < total
                            ? null
                            : () async {
                                await ref
                                    .read(posRepositoryProvider)
                                    .checkoutOrder(
                                      order: order,
                                      paymentMethod: paymentMethod,
                                      paidAmount: received,
                                    );
                                if (!context.mounted) return;
                                paidController.clear();
                                onCheckoutComplete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Venta registrada.'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.point_of_sale_rounded),
                        label: Text(
                          paymentMethod == 'cash'
                              ? 'Cobrar ${currency.format(total)}'
                              : 'Confirmar ${currency.format(total)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({
    required this.order,
    required this.total,
    required this.currency,
  });

  final OrderSummary order;
  final double total;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text('${order.itemCount} productos'),
                ],
              ),
            ),
            Text(
              currency.format(total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesHistory extends StatelessWidget {
  const _SalesHistory({required this.currency, required this.salesAsync});

  final NumberFormat currency;
  final AsyncValue<List<SaleSummary>> salesAsync;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    return salesAsync.when(
      data: (sales) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Ventas recientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (sales.isEmpty)
            const SizedBox.shrink()
          else
            ...sales
                .take(12)
                .map(
                  (sale) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(sale.saleNumber),
                      subtitle: Text(
                        '${sale.paymentMethod == 'cash' ? 'Efectivo' : 'Transferencia'} · ${dateFormat.format(sale.soldAt)}',
                      ),
                      trailing: Text(currency.format(sale.totalAmount)),
                    ),
                  ),
                ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}
