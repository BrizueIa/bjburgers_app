import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
import '../../../../core/storage/promo_config.dart';
import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../../data/comandas_repository.dart';
import '../../data/order_item_notes.dart';
import '../controllers/comandas_controller.dart';

class ComandasScreen extends ConsumerStatefulWidget {
  const ComandasScreen({super.key});

  @override
  ConsumerState<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends ConsumerState<ComandasScreen> {
  final List<OrderDraftItem> _draftItems = [];
  final TextEditingController _notesController = TextEditingController();

  Future<void> _addProductDraft(
    dynamic product,
    List<dynamic> products, {
    String? comboLabel,
    String? draftNote,
    double? overrideUnitPrice,
  }) async {
    final removedIngredients = await _showCustomizationDialog(
      context,
      ref,
      product,
      comboLabel: comboLabel,
    );
    if (removedIngredients == null) return;
    if (!mounted) return;

    final availableExtras = products.where((item) {
      if (item.productType != 'simple' || item.id == product.id) {
        return false;
      }
      final categoryName = item.categoryName?.toString() ?? '';
      return item.trackStock || categoryName == 'Extras';
    }).toList();
    final selectedExtras = await _showExtrasSelectionDialog(
      context,
      availableExtras,
      productName: product.name,
      comboLabel: comboLabel,
    );
    if (selectedExtras == null) return;

    if (!mounted) return;

    setState(() {
      _draftItems.add(
        OrderDraftItem(
          productId: product.id,
          productName: product.name,
          unitPrice:
              (overrideUnitPrice ?? product.salePrice) +
              selectedExtras.fold<double>(
                0,
                (sum, extra) => sum + (extra.salePrice as double? ?? 0),
              ),
          baseCost:
              product.calculatedCost +
              selectedExtras.fold<double>(
                0,
                (sum, extra) => sum + (extra.calculatedCost as double? ?? 0),
              ),
          quantity: 1,
          comboLabel: comboLabel,
          notes: buildOrderItemNotes(
            baseNotes: draftNote ?? comboLabel,
            extras: selectedExtras
                .map<OrderExtraNote>(
                  (extra) => OrderExtraNote(
                    id: extra.id as String,
                    name: extra.name as String,
                  ),
                )
                .toList(),
          ),
          removedIngredients: removedIngredients,
        ),
      );
    });
  }

  Future<void> _addPromotion(PromoConfig promo, List<dynamic> products) async {
    final selectedProducts = <dynamic>[];

    for (final slot in promo.slots) {
      if (slot.needsSelection) {
        final result = await _showPromoSelectionDialog(
          context,
          promo,
          slot,
          products,
        );
        if (!mounted || result == null) return;
        selectedProducts.add(result);
        continue;
      }

      final product = products
          .where((item) => item.name == slot.fixedProductName)
          .firstOrNull;
      if (product == null) return;
      selectedProducts.add(product);
    }

    if (selectedProducts.isEmpty) return;

    final unitPrice = promo.totalPrice / selectedProducts.length;
    for (var i = 0; i < selectedProducts.length; i++) {
      final itemLabel = selectedProducts.length > 1
          ? '${promo.title} · ${i + 1}/${selectedProducts.length}'
          : promo.title;
      await _addProductDraft(
        selectedProducts[i],
        products,
        comboLabel: itemLabel,
        draftNote: 'Promo ${promo.title} · ${i + 1}/${selectedProducts.length}',
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
    final ordersAsync = ref.watch(todaysOrdersProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    Future<void> refreshData() async {
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(todaysOrdersProvider);
      await ref.read(syncStatusProvider.notifier).synchronize();
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(todaysOrdersProvider);
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
            promoPresets: settings.promoConfigs,
            onAddProduct: (product, products) async {
              await _addProductDraft(product, products);
            },
            onAddPromo: (promo, products) => _addPromotion(promo, products),
            onSaveOrder: () async {
              if (_draftItems.isEmpty) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => _ConfirmOrderDialog(
                  draftItems: _draftItems,
                  notesController: _notesController,
                  onRemoveItem: (index) {
                    if (index < 0 || index >= _draftItems.length) return;
                    setState(() {
                      _draftItems.removeAt(index);
                    });
                  },
                  onCancelOrder: () {
                    setState(() {
                      _draftItems.clear();
                      _notesController.clear();
                    });
                  },
                ),
              );
              if (!mounted || confirmed != true) return;

              await ref
                  .read(comandasRepositoryProvider)
                  .createOrder(
                    notes: _notesController.text.trim(),
                    items: List<OrderDraftItem>.from(_draftItems),
                  );
              if (!context.mounted) return;
              setState(() {
                _draftItems.clear();
                _notesController.clear();
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Comanda creada.')));
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
            child: Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Nueva'),
                          Tab(text: 'Preparacion'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: refreshData,
                            child: _CommandComposer(
                              productsAsync: productsAsync,
                              draftItems: _draftItems,
                              notesController: _notesController,
                              draftTotal: _draftTotal,
                              currency: currency,
                              compact: true,
                              promoPresets: settings.promoConfigs,
                              onAddProduct: _addProductDraft,
                              onAddPromo: (promo, products) =>
                                  _addPromotion(promo, products),
                              onSaveOrder: () async {
                                if (_draftItems.isEmpty) return;
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => _ConfirmOrderDialog(
                                    draftItems: _draftItems,
                                    notesController: _notesController,
                                    onRemoveItem: (index) {
                                      if (index < 0 ||
                                          index >= _draftItems.length) {
                                        return;
                                      }
                                      setState(() {
                                        _draftItems.removeAt(index);
                                      });
                                    },
                                    onCancelOrder: () {
                                      setState(() {
                                        _draftItems.clear();
                                        _notesController.clear();
                                      });
                                    },
                                  ),
                                );
                                if (!mounted || confirmed != true) return;

                                await ref
                                    .read(comandasRepositoryProvider)
                                    .createOrder(
                                      notes: _notesController.text.trim(),
                                      items: List<OrderDraftItem>.from(
                                        _draftItems,
                                      ),
                                    );
                                if (!context.mounted) return;
                                setState(() {
                                  _draftItems.clear();
                                  _notesController.clear();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Comanda creada.'),
                                  ),
                                );
                                tabController.animateTo(1);
                              },
                            ),
                          ),
                          RefreshIndicator(
                            onRefresh: refreshData,
                            child: queue,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
    required this.onSaveOrder,
  });

  final AsyncValue<List<dynamic>> productsAsync;
  final List<OrderDraftItem> draftItems;
  final TextEditingController notesController;
  final double draftTotal;
  final NumberFormat currency;
  final bool compact;
  final List<PromoConfig> promoPresets;
  final Future<void> Function(dynamic product, List<dynamic> products)
  onAddProduct;
  final Future<void> Function(PromoConfig promo, List<dynamic> products)
  onAddPromo;
  final Future<void> Function() onSaveOrder;

  @override
  Widget build(BuildContext context) {
    final totalItems = draftItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    Widget buildCatalog(List<dynamic> products) {
      final scheme = Theme.of(context).colorScheme;
      final todaysPromos = promoPresets
          .where((promo) => _matchesToday(promo.dayLabel))
          .toList();
      final simpleProducts = products
          .where((item) => item.productType == 'simple')
          .toList();
      final recipeProducts = products
          .where((item) => item.productType != 'simple')
          .toList();

      Widget buildQuickProductList(
        String title,
        List<dynamic> items,
        IconData icon,
        Color color,
      ) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final product in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onAddProduct(product, products),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: color,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              icon,
                              size: 20,
                              color: color == scheme.secondaryContainer
                                  ? scheme.onSecondaryContainer
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            currency.format(product.salePrice),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.add_circle_outline_rounded,
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Promociones',
            child: todaysPromos.isEmpty
                ? const Text('Sin promo hoy')
                : compact
                ? SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: todaysPromos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final promo = todaysPromos[index];
                        return SizedBox(
                          width: 168,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => onAddPromo(promo, products),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      promo.dayLabel.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      promo.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currency.format(promo.totalPrice),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final promo in todaysPromos)
                        SizedBox(
                          width: 240,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => onAddPromo(promo, products),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFFF6D3A3),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.local_offer_rounded,
                                        color: Color(0xFF7A2E12),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
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
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Productos',
            child: compact
                ? Column(
                    children: [
                      buildQuickProductList(
                        'Con receta',
                        recipeProducts,
                        Icons.lunch_dining_rounded,
                        scheme.secondaryContainer,
                      ),
                      buildQuickProductList(
                        'Simples',
                        simpleProducts,
                        Icons.local_drink_rounded,
                        scheme.primaryContainer,
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
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onAddProduct(product, products),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFFFFE2B0),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        product.productType == 'simple'
                                            ? Icons.local_drink_rounded
                                            : Icons.lunch_dining_rounded,
                                        color: const Color(0xFF1A1208),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
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
          ),
        ],
      );
    }

    return productsAsync.when(
      data: (products) {
        if (compact) {
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                children: [buildCatalog(products)],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _SaveOrderBar(
                  totalItems: totalItems,
                  draftTotal: draftTotal,
                  currency: currency,
                  onSaveOrder: draftItems.isEmpty ? null : onSaveOrder,
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Text(
              'Nueva comanda',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: buildCatalog(products)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _SaveOrderBar(
                    totalItems: totalItems,
                    draftTotal: draftTotal,
                    currency: currency,
                    onSaveOrder: draftItems.isEmpty ? null : onSaveOrder,
                    compact: false,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.draftItems,
    required this.notesController,
    required this.currency,
    required this.compact,
    this.onRemoveItem,
  });

  final List<OrderDraftItem> draftItems;
  final TextEditingController notesController;
  final NumberFormat currency;
  final bool compact;
  final void Function(int index)? onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final draftTotal = draftItems.fold<double>(
      0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draftItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Agrega productos para formar la comanda.'),
            )
          else
            ...draftItems.asMap().entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      child: Text('${entry.value.quantity}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.productName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (entry.value.comboLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry.value.comboLabel!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (displayOrderItemNotes(entry.value.notes) !=
                              null) ...[
                            const SizedBox(height: 4),
                            Text(displayOrderItemNotes(entry.value.notes)!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${entry.value.quantity}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (onRemoveItem != null) ...[
                          const SizedBox(height: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                            ),
                            tooltip: 'Quitar producto',
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => onRemoveItem?.call(entry.key),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (draftItems.isNotEmpty) const SizedBox(height: 10),
          TextField(
            controller: notesController,
            minLines: compact ? 2 : 3,
            maxLines: compact ? 3 : 4,
            decoration: const InputDecoration(
              labelText: 'Notas generales de la comanda',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveOrderBar extends StatelessWidget {
  const _SaveOrderBar({
    required this.totalItems,
    required this.draftTotal,
    required this.currency,
    required this.onSaveOrder,
    this.compact = true,
  });

  final int totalItems;
  final double draftTotal;
  final NumberFormat currency;
  final Future<void> Function()? onSaveOrder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bar = Material(
      elevation: compact ? 8 : 0,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onSaveOrder,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalItems item(s)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(draftTotal),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onSaveOrder,
                icon: const Icon(Icons.playlist_add_check_circle_rounded),
                label: const Text('Guardar comanda'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!compact) return bar;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: bar,
      ),
    );
  }
}

class _ConfirmOrderDialog extends StatelessWidget {
  const _ConfirmOrderDialog({
    required this.draftItems,
    required this.notesController,
    this.onRemoveItem,
    this.onCancelOrder,
  });

  final List<OrderDraftItem> draftItems;
  final TextEditingController notesController;
  final void Function(int index)? onRemoveItem;
  final VoidCallback? onCancelOrder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comanda',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${draftItems.length} item(s)',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Column(
                      children: [
                        if (draftItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Agrega productos para formar la comanda.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          )
                        else
                          ...draftItems.asMap().entries.map((entry) {
                            final note = displayOrderItemNotes(
                              entry.value.notes,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('${entry.value.quantity}'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.value.productName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        if (entry.value.comboLabel != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.value.comboLabel!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                        if (note != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            note,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (onRemoveItem != null)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                      ),
                                      tooltip: 'Quitar producto',
                                      color: scheme.error,
                                      onPressed: () {
                                        onRemoveItem?.call(entry.key);
                                        setState(() {});
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                        TextField(
                          controller: notesController,
                          minLines: 1,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Notas (opcional)',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          onCancelOrder?.call();
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('Limpiar'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Guardar comanda'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<dynamic> _showPromoSelectionDialog(
  BuildContext context,
  PromoConfig promo,
  PromoProductSlotConfig slot,
  List<dynamic> products,
) async {
  final selectable = products
      .where((product) => slot.selectableProductNames.contains(product.name))
      .toList();
  if (selectable.isEmpty) return null;

  dynamic selected = selectable.first;
  return showDialog<dynamic>(
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
              DropdownButtonFormField<dynamic>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: selectable
                    .map<DropdownMenuItem<dynamic>>(
                      (product) => DropdownMenuItem<dynamic>(
                        value: product,
                        child: Text(product.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => selected = value);
                },
              ),
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
              if (selected == null) return;
              Navigator.of(context).pop(selected);
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
    String formatDuration(Duration duration) {
      if (duration.isNegative) duration = Duration.zero;
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    Widget buildPrepTimer(DateTime startTime) {
      return StreamBuilder<DateTime>(
        stream: Stream.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final elapsed = now.difference(startTime);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                formatDuration(elapsed),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          );
        },
      );
    }

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('No hay comandas registradas hoy.'));
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final accent = _statusAccent(order.status);
            final scheme = Theme.of(context).colorScheme;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 50,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Chip(label: Text(_statusLabel(order.status))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.itemCount} productos · ${currency.format(order.totalEstimated)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (order.status == 'preparing') ...[
                                const SizedBox(height: 6),
                                buildPrepTimer(order.updatedAt),
                              ],
                              if (order.notes != null) ...[
                                const SizedBox(height: 10),
                                Text(order.notes!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: scheme.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: scheme.surface,
                                          foregroundColor: scheme.onSurface,
                                          child: Text('${item.quantity}'),
                                        ),
                                        const SizedBox(width: 10),
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
                                              if (displayOrderItemNotes(
                                                    item.notes,
                                                  ) !=
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    displayOrderItemNotes(
                                                      item.notes,
                                                    )!,
                                                    style: TextStyle(
                                                      color: scheme
                                                          .onPrimaryContainer,
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
                                                    style: TextStyle(
                                                      color: scheme
                                                          .onPrimaryContainer,
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
                    const SizedBox(height: 6),
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
                            onPressed: () async {
                              await ref
                                  .read(comandasRepositoryProvider)
                                  .updateOrderStatus(order.id, 'ready');
                              if (!context.mounted) return;
                              context.go('/pos');
                            },
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

bool _matchesToday(String dayLabel) {
  const weekdayLabels = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miercoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sabado',
    7: 'Domingo',
  };

  final now = DateTime.now();
  final effectiveDay = now.hour < 2
      ? now.subtract(const Duration(days: 1))
      : now;
  return weekdayLabels[effectiveDay.weekday] == dayLabel;
}

Future<List<String>?> _showCustomizationDialog(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quitar ingredientes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ingredientNames.map((name) {
                  final removed = selected.contains(name);
                  return FilterChip(
                    label: Text(
                      name,
                      style: TextStyle(
                        decoration: removed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        fontWeight: removed ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    avatar: Icon(
                      removed
                          ? Icons.remove_circle_outline_rounded
                          : Icons.add_task_rounded,
                      size: 16,
                    ),
                    selected: removed,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selected.add(name);
                        } else {
                          selected.remove(name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(const <String>[]),
                    child: const Text('Con todo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(selected.toList()),
                    child: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result;
}

Future<List<dynamic>?> _showExtrasSelectionDialog(
  BuildContext context,
  List<dynamic> extras, {
  required String productName,
  String? comboLabel,
}) async {
  if (extras.isEmpty) return const [];

  final selected = <dynamic>{};
  final result = await showDialog<List<dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          comboLabel == null
              ? 'Extras para $productName'
              : '$comboLabel · Extras',
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona extras',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Sin extras'),
                    avatar: Icon(
                      selected.isEmpty
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 16,
                    ),
                    selected: selected.isEmpty,
                    onSelected: (_) => setState(() => selected.clear()),
                  ),
                  ...extras.map((extra) {
                    final isSelected = selected.contains(extra);
                    return FilterChip(
                      label: Text('${extra.name}'),
                      avatar: Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                      ),
                      selected: isSelected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            selected.add(extra);
                          } else {
                            selected.remove(extra);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                    ),
                    onPressed: () => Navigator.of(context).pop(const []),
                    child: const Text('Omitir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(selected.toList()),
                    child: const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result;
}
