import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../comandas/data/comandas_repository.dart';
import '../../data/pos_repository.dart';
import '../controllers/pos_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String? _selectedOrderId;
  String _paymentMethod = 'cash';
  final TextEditingController _paidController = TextEditingController();

  @override
  void dispose() {
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

          return ListView(
            children: [
              SizedBox(height: 420, child: queue),
              const Divider(height: 1),
              SizedBox(height: 520, child: checkout),
              const Divider(height: 1),
              SizedBox(height: 420, child: sales),
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
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final selected = order.id == selectedOrderId;
            return Card(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                title: Text(order.orderNumber),
                subtitle: Text(
                  '${order.itemCount} productos · ${currency.format(order.totalEstimated)}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => onSelect(order.id),
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
  });

  final String? selectedOrderId;
  final String paymentMethod;
  final TextEditingController paidController;
  final NumberFormat currency;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onPaidChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedOrderId == null) {
      return const Center(
        child: Text('Selecciona una comanda lista para cobrar.'),
      );
    }

    final readyOrders =
        ref.watch(readyOrdersProvider).valueOrNull ?? const <OrderSummary>[];
    final order = readyOrders.firstWhere((item) => item.id == selectedOrderId);
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
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              order.orderNumber,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.quantity} x ${item.productName}'),
                subtitle: item.removedIngredients.isEmpty
                    ? null
                    : Text('Sin: ${item.removedIngredients.join(', ')}'),
                trailing: Text(currency.format(item.lineTotal)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${currency.format(total)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    Text('Cambio: ${currency.format(change < 0 ? 0 : change)}'),
                    if (paymentMethod == 'cash' && received < total)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('El monto recibido aun no cubre el total.'),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Venta registrada.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('Cobrar pedido'),
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

class _SalesHistory extends StatelessWidget {
  const _SalesHistory({required this.currency, required this.salesAsync});

  final NumberFormat currency;
  final AsyncValue<List<SaleSummary>> salesAsync;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    return salesAsync.when(
      data: (sales) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Ventas recientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (sales.isEmpty)
            const Text('Aun no hay ventas registradas.')
          else
            ...sales
                .take(12)
                .map(
                  (sale) => Card(
                    child: ListTile(
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
