import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
            onCheckoutComplete: (saleId) {
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

class _ReadyOrdersList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return readyOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Text('No hay comandas listas para cobrar.'),
          );
        }

        final dateFormat = DateFormat('dd/MM HH:mm');

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.schedule_rounded,
                            label: dateFormat.format(order.createdAt),
                          ),
                          _InfoChip(
                            icon: Icons.check_circle_rounded,
                            label: 'Lista para cobrar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Consumer(
                        builder: (context, ref, child) {
                          final itemsAsync = ref.watch(
                            posOrderItemsProvider(order.id),
                          );
                          return itemsAsync.when(
                            data: (items) {
                              if (items.isEmpty) return const SizedBox.shrink();
                              final preview = items.take(3).toList();
                              final remaining = items.length - preview.length;
                              return Column(
                                children: [
                                  ...preview.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${item.quantity}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item.productName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (remaining > 0)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '+$remaining producto(s) mas',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => Text(
                              'Cargando productos...',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            error: (error, stackTrace) => Text(
                              'Error al cargar productos',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          );
                        },
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
  final ValueChanged<String> onCheckoutComplete;

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

    Future<void> showSpinCodeDialog(BuildContext context, String code) async {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Codigo de spin'),
          content: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Codigo copiado.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );
    }

    Future<void> showPostCheckoutDialog(
      BuildContext context,
      String saleId,
    ) async {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Venta registrada'),
          content: const Text(
            'Quieres generar un codigo de spin para este cliente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final code = await ref
                      .read(posRepositoryProvider)
                      .createSpinCode(remainingSpins: 1, saleId: saleId);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  await showSpinCodeDialog(context, code);
                } catch (error) {
                  debugPrint('Error creating spin code: $error');
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error al crear codigo: $error')),
                  );
                }
              },
              icon: const Icon(Icons.confirmation_number_rounded),
              label: const Text('Generar codigo'),
            ),
          ],
        ),
      );
    }

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
                                final messenger = ScaffoldMessenger.of(context);
                                final saleId = await ref
                                    .read(posRepositoryProvider)
                                    .checkoutOrder(
                                      order: order,
                                      paymentMethod: paymentMethod,
                                      paidAmount: received,
                                    );
                                if (!context.mounted) return;
                                paidController.clear();
                                onCheckoutComplete(saleId);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Venta registrada.'),
                                  ),
                                );
                                await showPostCheckoutDialog(context, saleId);
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

enum InfoTone { primary, muted, success, error }

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.tone,
    this.trailing,
  });

  final String label;
  final String value;
  final InfoTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? valueColor;
    switch (tone) {
      case InfoTone.primary:
        valueColor = scheme.onSurface;
        break;
      case InfoTone.success:
        valueColor = Colors.green;
        break;
      case InfoTone.error:
        valueColor = scheme.error;
        break;
      case InfoTone.muted:
        valueColor = scheme.onSurfaceVariant;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
                fontWeight: tone == InfoTone.primary ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SalesHistory extends ConsumerWidget {
  const _SalesHistory({required this.currency, required this.salesAsync});

  final NumberFormat currency;
  final AsyncValue<List<SaleSummary>> salesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    return salesAsync.when(
      data: (sales) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesHistoryProvider);
          for (final sale in sales) {
            ref.invalidate(spinCodeBySaleProvider(sale.id));
          }
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: ListView(
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
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                sale.saleNumber,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                currency.format(sale.totalAmount),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _InfoChip(
                                icon: sale.paymentMethod == 'cash'
                                    ? Icons.payments_rounded
                                    : Icons.account_balance_rounded,
                                label: sale.paymentMethod == 'cash'
                                    ? 'Efectivo'
                                    : 'Transferencia',
                              ),
                              _InfoChip(
                                icon: Icons.schedule_rounded,
                                label: dateFormat.format(sale.soldAt),
                              ),
                              _InfoChip(
                                icon: Icons.shopping_bag_rounded,
                                label: '${sale.totalUnits} items',
                              ),
                            ],
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          const Divider(height: 20),
                          Consumer(
                            builder: (context, ref, child) {
                              final spinAsync = ref.watch(
                                spinCodeBySaleProvider(sale.id),
                              );
                              return spinAsync.when(
                                data: (spin) {
                                  if (spin == null) {
                                    return const _InfoRow(
                                      label: 'Ruleta',
                                      value: 'Sin codigo',
                                      tone: InfoTone.muted,
                                    );
                                  }
                                  final status = spin.isConsumed
                                      ? 'Premio aplicado'
                                      : 'Codigo activo';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        label: 'Ruleta',
                                        value: spin.code,
                                        tone: InfoTone.primary,
                                        trailing: TextButton.icon(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: spin.code),
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Codigo copiado.',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Copiar'),
                                        ),
                                      ),
                                      _InfoRow(
                                        label: 'Estado',
                                        value: status,
                                        tone: spin.isConsumed
                                            ? InfoTone.success
                                            : InfoTone.muted,
                                      ),
                                      if (spin.isConsumed)
                                        _InfoRow(
                                          label: 'Premio',
                                          value: spin.prizeLabel ?? '-',
                                          tone: InfoTone.primary,
                                        ),
                                    ],
                                  );
                                },
                                loading: () => const _InfoRow(
                                  label: 'Ruleta',
                                  value: 'Cargando...',
                                  tone: InfoTone.muted,
                                ),
                                error: (error, stackTrace) => const _InfoRow(
                                  label: 'Ruleta',
                                  value: 'Error al cargar',
                                  tone: InfoTone.error,
                                ),
                              );
                            },
                          ),
                          if (sale.itemsSummary != null &&
                              sale.itemsSummary!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Detalle',
                              value: sale.itemsSummary!,
                              tone: InfoTone.muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}
