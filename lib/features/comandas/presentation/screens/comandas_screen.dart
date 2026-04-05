import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/app_settings_controller.dart';
import '../../data/comandas_repository.dart';
import '../controllers/comandas_controller.dart';

class ComandasScreen extends ConsumerStatefulWidget {
  const ComandasScreen({super.key});

  @override
  ConsumerState<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends ConsumerState<ComandasScreen> {
  final List<OrderDraftItem> _draftItems = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _draftTotal => _draftItems.fold(
    0,
    (sum, item) => sum + (item.unitPrice * item.quantity),
  );

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(sellableProductsProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandas'),
        actions: [
          if (settings.digitalMenuUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Menu digital'),
                    content: SelectableText(settings.digitalMenuUrl),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.image_outlined),
              label: const Text('Ver menu'),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final composer = _CommandComposer(
            productsAsync: productsAsync,
            draftItems: _draftItems,
            notesController: _notesController,
            draftTotal: _draftTotal,
            currency: currency,
            onAddProduct: (product) async {
              final removedIngredients = product.productType == 'recipe'
                  ? await _showCustomizationDialog(context, ref, product)
                  : const <String>[];
              if (!mounted) return;
              setState(() {
                final index = _draftItems.indexWhere(
                  (item) =>
                      item.productId == product.id &&
                      item.removedIngredients.join('|') ==
                          removedIngredients.join('|'),
                );
                if (index >= 0) {
                  final current = _draftItems[index];
                  _draftItems[index] = OrderDraftItem(
                    productId: current.productId,
                    productName: current.productName,
                    unitPrice: current.unitPrice,
                    baseCost: current.baseCost,
                    quantity: current.quantity + 1,
                    notes: current.notes,
                    removedIngredients: current.removedIngredients,
                  );
                } else {
                  _draftItems.add(
                    OrderDraftItem(
                      productId: product.id,
                      productName: product.name,
                      unitPrice: product.salePrice,
                      baseCost: product.calculatedCost,
                      quantity: 1,
                      removedIngredients: removedIngredients,
                    ),
                  );
                }
              });
            },
            onUpdateQuantity: (index, quantity) {
              setState(() {
                if (quantity <= 0) {
                  _draftItems.removeAt(index);
                  return;
                }
                final current = _draftItems[index];
                _draftItems[index] = OrderDraftItem(
                  productId: current.productId,
                  productName: current.productName,
                  unitPrice: current.unitPrice,
                  baseCost: current.baseCost,
                  quantity: quantity,
                  notes: current.notes,
                  removedIngredients: current.removedIngredients,
                );
              });
            },
            onSaveOrder: () async {
              if (_draftItems.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(comandasRepositoryProvider)
                  .createOrder(
                    notes: _notesController.text.trim(),
                    items: List<OrderDraftItem>.from(_draftItems),
                  );
              if (!mounted) return;
              setState(() {
                _draftItems.clear();
                _notesController.clear();
              });
              messenger.showSnackBar(
                const SnackBar(content: Text('Comanda creada.')),
              );
            },
          );

          final queue = _OrdersQueue(
            currency: currency,
            ordersAsync: ordersAsync,
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 6, child: composer),
                const VerticalDivider(width: 1),
                Expanded(flex: 5, child: queue),
              ],
            );
          }

          return ListView(
            children: [
              SizedBox(height: 700, child: composer),
              const Divider(height: 1),
              SizedBox(height: 700, child: queue),
            ],
          );
        },
      ),
    );
  }
}

class _CommandComposer extends StatelessWidget {
  const _CommandComposer({
    required this.productsAsync,
    required this.draftItems,
    required this.notesController,
    required this.draftTotal,
    required this.currency,
    required this.onAddProduct,
    required this.onUpdateQuantity,
    required this.onSaveOrder,
  });

  final AsyncValue<List<dynamic>> productsAsync;
  final List<OrderDraftItem> draftItems;
  final TextEditingController notesController;
  final double draftTotal;
  final NumberFormat currency;
  final Future<void> Function(dynamic product) onAddProduct;
  final void Function(int index, int quantity) onUpdateQuantity;
  final Future<void> Function() onSaveOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text('Nueva comanda', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        productsAsync.when(
          data: (products) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final product in products)
                SizedBox(
                  width: 200,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => onAddProduct(product),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.productType == 'simple'
                                  ? 'Simple'
                                  : 'Con receta',
                            ),
                            const SizedBox(height: 8),
                            Text(currency.format(product.salePrice)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('$error'),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (draftItems.isEmpty)
                  const Text('Agrega productos para formar la comanda.')
                else
                  ...draftItems.asMap().entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value.productName),
                      subtitle: Text(
                        entry.value.removedIngredients.isEmpty
                            ? 'Sin cambios'
                            : 'Sin: ${entry.value.removedIngredients.join(', ')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onUpdateQuantity(
                              entry.key,
                              entry.value.quantity - 1,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${entry.value.quantity}'),
                          IconButton(
                            onPressed: () => onUpdateQuantity(
                              entry.key,
                              entry.value.quantity + 1,
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas generales de la comanda',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Total estimado: ${currency.format(draftTotal)}'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: draftItems.isEmpty ? null : onSaveOrder,
                  icon: const Icon(Icons.playlist_add_check_circle_rounded),
                  label: const Text('Guardar comanda'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdersQueue extends ConsumerWidget {
  const _OrdersQueue({required this.currency, required this.ordersAsync});

  final NumberFormat currency;
  final AsyncValue<List<OrderSummary>> ordersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Text('No hay comandas registradas todavia.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              child: ExpansionTile(
                title: Text(order.orderNumber),
                subtitle: Text(
                  '${order.itemCount} productos · ${currency.format(order.totalEstimated)}',
                ),
                trailing: Chip(label: Text(_statusLabel(order.status))),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (order.notes != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(order.notes!),
                    ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final itemsAsync = ref.watch(
                        orderItemsProvider(order.id),
                      );
                      return itemsAsync.when(
                        data: (items) => Column(
                          children: items
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${item.quantity} x ${item.productName}',
                                  ),
                                  subtitle: item.removedIngredients.isEmpty
                                      ? null
                                      : Text(
                                          'Sin: ${item.removedIngredients.join(', ')}',
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (error, stackTrace) => Text('$error'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (order.status == 'pending')
                        OutlinedButton(
                          onPressed: () => ref
                              .read(comandasRepositoryProvider)
                              .updateOrderStatus(order.id, 'preparing'),
                          child: const Text('Preparando'),
                        ),
                      if (order.status == 'preparing')
                        FilledButton(
                          onPressed: () => ref
                              .read(comandasRepositoryProvider)
                              .updateOrderStatus(order.id, 'ready'),
                          child: const Text('Pasar a POS'),
                        ),
                      if (order.status != 'delivered' &&
                          order.status != 'cancelled')
                        TextButton(
                          onPressed: () => ref
                              .read(comandasRepositoryProvider)
                              .cancelOrder(order.id),
                          child: const Text('Cancelar'),
                        ),
                    ],
                  ),
                ],
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

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pendiente';
    case 'preparing':
      return 'Preparando';
    case 'ready':
      return 'Lista para POS';
    case 'delivered':
      return 'Cobrada';
    case 'cancelled':
      return 'Cancelada';
    default:
      return status;
  }
}

Future<List<String>> _showCustomizationDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic product,
) async {
  final ingredientNames = await ref
      .read(comandasRepositoryProvider)
      .fetchRecipeIngredientNames(product.id);
  if (!context.mounted || ingredientNames.isEmpty) {
    return const [];
  }

  final selected = <String>{};
  final result = await showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Personalizar ${product.name}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ingredientNames
                .map(
                  (name) => CheckboxListTile(
                    value: selected.contains(name),
                    title: Text('Quitar $name'),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          selected.add(name);
                        } else {
                          selected.remove(name);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(const <String>[]),
            child: const Text('Con todo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected.toList()),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    ),
  );
  return result ?? const <String>[];
}
