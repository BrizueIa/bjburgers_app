import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/database/app_database.dart';
import '../../data/purchases_repository.dart';
import '../../../inventario/presentation/controllers/inventory_controller.dart';
import '../controllers/purchases_controller.dart';

class ComprasScreen extends ConsumerWidget {
  const ComprasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);
    final ingredients = ref.watch(ingredientsProvider);
    final admin = ref.watch(adminModeProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(
                admin.enabled
                    ? Icons.shopping_cart_checkout_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: purchases.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Icon(Icons.shopping_basket_rounded, size: 36),
            );
          }

          final totalSpent = items.fold<double>(
            0,
            (sum, item) => sum + item.purchase.totalCost,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppMiniStatCard(
                      label: 'Compras',
                      value: '${items.length}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppMiniStatCard(
                      label: 'Invertido',
                      value: currency.format(totalSpent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      title: Text(item.ingredientName),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                'Cantidad: ${item.purchase.purchasedQuantity}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Total: ${currency.format(item.purchase.totalCost)}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Unitario: ${currency.format(item.purchase.unitCost)}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                dateFormat.format(item.purchase.purchasedAt),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: item.purchase.note == null
                          ? null
                          : Tooltip(
                              message: item.purchase.note!,
                              child: const Icon(Icons.sticky_note_2_outlined),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!admin.enabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Activa el modo admin para registrar compras.'),
              ),
            );
            return;
          }

          final data = ingredients.valueOrNull ?? const [];
          showDialog<void>(
            context: context,
            builder: (_) => _PurchaseDialog(ingredients: data),
          );
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Registrar compra'),
      ),
    );
  }
}

class _PurchaseDialog extends ConsumerStatefulWidget {
  const _PurchaseDialog({required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  ConsumerState<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<_PurchaseDialog> {
  String? _ingredientId;
  final _quantityController = TextEditingController();
  final _totalController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIngredient = widget.ingredients
        .where((ingredient) => ingredient.id == _ingredientId)
        .firstOrNull;
    final previewQuantity =
        double.tryParse(_quantityController.text.trim()) ?? 0;
    final previewTotal = double.tryParse(_totalController.text.trim()) ?? 0;
    final unitCost = previewQuantity > 0 ? previewTotal / previewQuantity : 0;
    final currentStock = selectedIngredient?.stockQuantity ?? 0;
    final nextStock = currentStock + previewQuantity;
    final nextAverageCost = selectedIngredient == null || previewQuantity <= 0
        ? 0
        : currentStock <= 0
        ? unitCost
        : ((currentStock * selectedIngredient.currentUnitCost) + previewTotal) /
              nextStock;
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return AlertDialog(
      title: const Text('Registrar compra'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IngredientSelectorField(
                selectedIngredient: selectedIngredient,
                onTap: () async {
                  final selected = await showModalBottomSheet<Ingredient>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _IngredientSelectionSheet(
                      ingredients: widget.ingredients,
                      selectedIngredientId: _ingredientId,
                    ),
                  );
                  if (!mounted || selected == null) return;
                  setState(() => _ingredientId = selected.id);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: selectedIngredient == null
                            ? 'Cantidad'
                            : 'Cantidad (${selectedIngredient.unitName})',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _totalController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Costo total',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Nota opcional'),
              ),
              const SizedBox(height: 14),
              AppSectionCard(
                title: 'Impacto',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppMiniStatCard(
                            label: 'Costo compra',
                            value: currency.format(unitCost),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppMiniStatCard(
                            label: 'Costo promedio nuevo',
                            value: currency.format(nextAverageCost),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppMiniStatCard(
                            label: 'Stock actual',
                            value: selectedIngredient == null
                                ? '-'
                                : currentStock.toStringAsFixed(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppMiniStatCard(
                            label: 'Stock despues',
                            value: selectedIngredient == null
                                ? '-'
                                : nextStock.toStringAsFixed(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Esta compra afecta costos futuros. No recalcula ventas pasadas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final quantity =
                double.tryParse(_quantityController.text.trim()) ?? 0;
            final total = double.tryParse(_totalController.text.trim()) ?? 0;
            if (_ingredientId == null || quantity <= 0 || total <= 0) {
              return;
            }

            await ref
                .read(purchasesRepositoryProvider)
                .createPurchase(
                  ingredientId: _ingredientId!,
                  quantity: quantity,
                  totalCost: total,
                  note: _noteController.text.trim(),
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Guardar compra'),
        ),
      ],
    );
  }
}

class _IngredientSelectorField extends StatelessWidget {
  const _IngredientSelectorField({
    required this.selectedIngredient,
    required this.onTap,
  });

  final Ingredient? selectedIngredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.inventory_2_rounded,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingrediente',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedIngredient?.name ?? 'Seleccionar ingrediente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _IngredientSelectionSheet extends StatefulWidget {
  const _IngredientSelectionSheet({
    required this.ingredients,
    required this.selectedIngredientId,
  });

  final List<Ingredient> ingredients;
  final String? selectedIngredientId;

  @override
  State<_IngredientSelectionSheet> createState() =>
      _IngredientSelectionSheetState();
}

class _IngredientSelectionSheetState extends State<_IngredientSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.ingredients.where((ingredient) {
      if (query.isEmpty) return true;
      return ingredient.name.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar ingrediente',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final ingredient = filtered[index];
                  final selected = ingredient.id == widget.selectedIngredientId;

                  return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text(ingredient.name),
                      subtitle: Text(ingredient.unitName),
                      trailing: selected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(ingredient),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
