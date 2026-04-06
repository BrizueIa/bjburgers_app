import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../../data/comandas_repository.dart';
import '../controllers/comandas_controller.dart';

class _PromoPreset {
  const _PromoPreset({
    required this.title,
    required this.dayLabel,
    required this.totalPrice,
    required this.description,
    required this.count,
    this.fixedProductName,
    this.selectableProductNames = const [],
  });

  final String title;
  final String dayLabel;
  final double totalPrice;
  final String description;
  final int count;
  final String? fixedProductName;
  final List<String> selectableProductNames;

  bool get needsSelection => selectableProductNames.isNotEmpty;
}

const _promoPresets = [
  _PromoPreset(
    title: 'Promo Jueves',
    dayLabel: 'Jueves',
    totalPrice: 100,
    description: '2 Clasicas por 100',
    count: 2,
    fixedProductName: 'Clasica',
  ),
  _PromoPreset(
    title: 'Promo Viernes',
    dayLabel: 'Viernes',
    totalPrice: 100,
    description: '2 hot dogs a eleccion por 100',
    count: 2,
    selectableProductNames: [
      'Hot Dog Clasico',
      'Salchi-Dog',
      'Hot Dog Jack Daniels',
    ],
  ),
  _PromoPreset(
    title: 'Promo Sabado',
    dayLabel: 'Sabado',
    totalPrice: 69,
    description: 'Salchiburger a precio de Clasica',
    count: 1,
    fixedProductName: 'Salchiburger',
  ),
  _PromoPreset(
    title: 'Promo Domingo',
    dayLabel: 'Domingo',
    totalPrice: 125,
    description: '2 Hawaianas por 125',
    count: 2,
    fixedProductName: 'Hawaiana',
  ),
];

class ComandasScreen extends ConsumerStatefulWidget {
  const ComandasScreen({super.key});

  @override
  ConsumerState<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends ConsumerState<ComandasScreen> {
  final List<OrderDraftItem> _draftItems = [];
  final TextEditingController _notesController = TextEditingController();

  Future<void> _addProductDraft(
    dynamic product, {
    String? comboLabel,
    double? overrideUnitPrice,
  }) async {
    final removedIngredients = product.productType == 'recipe'
        ? await _showCustomizationDialog(
            context,
            ref,
            product,
            comboLabel: comboLabel,
          )
        : const <String>[];
    if (!mounted) return;

    setState(() {
      _draftItems.add(
        OrderDraftItem(
          productId: product.id,
          productName: product.name,
          unitPrice: overrideUnitPrice ?? product.salePrice,
          baseCost: product.calculatedCost,
          quantity: 1,
          comboLabel: comboLabel,
          notes: comboLabel,
          removedIngredients: removedIngredients,
        ),
      );
    });
  }

  Future<void> _addPromotion(_PromoPreset promo, List<dynamic> products) async {
    final selectedProducts = <dynamic>[];

    if (promo.needsSelection) {
      final result = await _showPromoSelectionDialog(context, promo, products);
      if (!mounted || result == null || result.length != promo.count) return;
      selectedProducts.addAll(result);
    } else {
      final product = products
          .where((item) => item.name == promo.fixedProductName)
          .firstOrNull;
      if (product == null) return;
      for (var i = 0; i < promo.count; i++) {
        selectedProducts.add(product);
      }
    }

    final unitPrice = promo.totalPrice / promo.count;
    for (var i = 0; i < selectedProducts.length; i++) {
      final itemLabel = selectedProducts.length > 1
          ? '${promo.title} · ${i + 1}/${selectedProducts.length}'
          : promo.title;
      await _addProductDraft(
        selectedProducts[i],
        comboLabel: itemLabel,
        overrideUnitPrice: unitPrice,
      );
    }
  }

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

    Future<void> refreshData() async {
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(ordersProvider);
      await ref.read(syncStatusProvider.notifier).synchronize();
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(ordersProvider);
    }

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
            compact: !isWide,
            promoPresets: _promoPresets,
            onAddProduct: (product) async {
              await _addProductDraft(product);
            },
            onAddPromo: (promo, products) => _addPromotion(promo, products),
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
                  comboLabel: current.comboLabel,
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
                Expanded(
                  flex: 6,
                  child: RefreshIndicator(
                    onRefresh: refreshData,
                    child: composer,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 5,
                  child: RefreshIndicator(onRefresh: refreshData, child: queue),
                ),
              ],
            );
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Nueva'),
                      Tab(text: 'Preparacion'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      RefreshIndicator(onRefresh: refreshData, child: composer),
                      RefreshIndicator(onRefresh: refreshData, child: queue),
                    ],
                  ),
                ),
              ],
            ),
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
    required this.compact,
    required this.promoPresets,
    required this.onAddProduct,
    required this.onAddPromo,
    required this.onUpdateQuantity,
    required this.onSaveOrder,
  });

  final AsyncValue<List<dynamic>> productsAsync;
  final List<OrderDraftItem> draftItems;
  final TextEditingController notesController;
  final double draftTotal;
  final NumberFormat currency;
  final bool compact;
  final List<_PromoPreset> promoPresets;
  final Future<void> Function(dynamic product) onAddProduct;
  final Future<void> Function(_PromoPreset promo, List<dynamic> products)
  onAddPromo;
  final void Function(int index, int quantity) onUpdateQuantity;
  final Future<void> Function() onSaveOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text('Nueva comanda', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        productsAsync.when(
          data: (products) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Promociones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (compact)
                Column(
                  children: [
                    for (final promo in promoPresets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7A2E12),
                                    Color(0xFFF28C00),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.local_offer_rounded,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(promo.title),
                            subtitle: Text(
                              '${promo.description} · ${promo.dayLabel}',
                            ),
                            trailing: Text(
                              currency.format(promo.totalPrice),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF7A2E12),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            onTap: () => onAddPromo(promo, products),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final promo in promoPresets)
                      SizedBox(
                        width: 240,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onAddPromo(promo, products),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF7A2E12),
                                          Color(0xFFF28C00),
                                        ],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.local_offer_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    promo.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(promo.description),
                                  const SizedBox(height: 10),
                                  Text(
                                    currency.format(promo.totalPrice),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: const Color(0xFF7A2E12),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              Text('Productos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              compact
                  ? Column(
                      children: [
                        for (final product in products)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => onAddProduct(product),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFC14D),
                                        Color(0xFFF28C00),
                                      ],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    product.productType == 'simple'
                                        ? Icons.local_drink_rounded
                                        : Icons.lunch_dining_rounded,
                                    color: const Color(0xFF1A1208),
                                  ),
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  product.productType == 'simple'
                                      ? 'Simple'
                                      : 'Con receta',
                                ),
                                trailing: Text(
                                  currency.format(product.salePrice),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: const Color(0xFF7A2E12),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final product in products)
                          SizedBox(
                            width: 200,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => onAddProduct(product),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFC14D),
                                              Color(0xFFF28C00),
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          product.productType == 'simple'
                                              ? Icons.local_drink_rounded
                                              : Icons.lunch_dining_rounded,
                                          color: const Color(0xFF1A1208),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        product.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.productType == 'simple'
                                            ? 'Simple'
                                            : 'Con receta',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        currency.format(product.salePrice),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: const Color(0xFF7A2E12),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('$error'),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entry.value.comboLabel != null)
                            Text(
                              entry.value.comboLabel!,
                              style: const TextStyle(
                                color: Color(0xFF7A2E12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            entry.value.removedIngredients.isEmpty
                                ? 'Sin cambios'
                                : 'Sin: ${entry.value.removedIngredients.join(', ')}',
                          ),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFD27A),
                        foregroundColor: const Color(0xFF1A1208),
                        child: Text('${entry.value.quantity}'),
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
                if (compact) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Tip: usa la pestaña Preparacion para ver la cola completa mientras cocinas.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<List<dynamic>?> _showPromoSelectionDialog(
  BuildContext context,
  _PromoPreset promo,
  List<dynamic> products,
) async {
  final selectable = products
      .where((product) => promo.selectableProductNames.contains(product.name))
      .toList();
  if (selectable.isEmpty) return null;

  final selected = List<dynamic>.filled(promo.count, selectable.first);
  return showDialog<List<dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(promo.title),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(promo.description),
              const SizedBox(height: 16),
              for (var i = 0; i < promo.count; i++) ...[
                DropdownButtonFormField<dynamic>(
                  initialValue: selected[i],
                  decoration: InputDecoration(labelText: 'Producto ${i + 1}'),
                  items: selectable
                      .map<DropdownMenuItem<dynamic>>(
                        (product) => DropdownMenuItem<dynamic>(
                          value: product,
                          child: Text(product.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => selected[i] = value);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (selected.any((item) => item == null)) return;
              Navigator.of(context).pop(selected.cast<dynamic>());
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final accent = _statusAccent(order.status);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 12,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.orderNumber,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  Chip(label: Text(_statusLabel(order.status))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${order.itemCount} productos · ${currency.format(order.totalEstimated)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (order.notes != null) ...[
                                const SizedBox(height: 10),
                                Text(order.notes!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Consumer(
                      builder: (context, ref, child) {
                        final itemsAsync = ref.watch(
                          orderItemsProvider(order.id),
                        );
                        return itemsAsync.when(
                          data: (items) => Column(
                            children: items
                                .map(
                                  (item) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF6EA),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFEACBA4),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(
                                            0xFFFFC14D,
                                          ),
                                          foregroundColor: const Color(
                                            0xFF1A1208,
                                          ),
                                          child: Text('${item.quantity}'),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (item.notes != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    item.notes!,
                                                    style: const TextStyle(
                                                      color: Color(0xFF7A2E12),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              if (item
                                                  .removedIngredients
                                                  .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    'Sin: ${item.removedIngredients.join(', ')}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF7A2E12),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stackTrace) => Text('$error'),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
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

Color _statusAccent(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFF28C00);
    case 'preparing':
      return const Color(0xFFCF5F0A);
    case 'ready':
      return const Color(0xFF3E9B47);
    case 'delivered':
      return const Color(0xFF455A64);
    case 'cancelled':
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFF7A2E12);
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
  dynamic product, {
  String? comboLabel,
}) async {
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
        title: Text(
          comboLabel == null
              ? 'Personalizar ${product.name}'
              : '$comboLabel · ${product.name}',
        ),
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
