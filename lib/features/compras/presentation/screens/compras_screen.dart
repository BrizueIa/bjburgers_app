import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Chip(
                avatar: Icon(
                  admin.enabled
                      ? Icons.shopping_cart_checkout_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  admin.enabled ? 'Registro habilitado' : 'Bloqueado por admin',
                ),
              ),
            ),
          ),
        ],
      ),
      body: purchases.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavia no hay compras registradas. Empieza cargando una compra para actualizar costos actuales.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final totalSpent = items.fold<double>(
            0,
            (sum, item) => sum + item.purchase.totalCost,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(label: Text('Compras: ${items.length}')),
                      Chip(
                        label: Text(
                          'Invertido: ${currency.format(totalSpent)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      title: Text(item.ingredientName),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
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
    final previewQuantity =
        double.tryParse(_quantityController.text.trim()) ?? 0;
    final previewTotal = double.tryParse(_totalController.text.trim()) ?? 0;
    final unitCost = previewQuantity > 0 ? previewTotal / previewQuantity : 0;
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return AlertDialog(
      title: const Text('Registrar compra'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _ingredientId,
              decoration: const InputDecoration(labelText: 'Ingrediente'),
              items: widget.ingredients
                  .map<DropdownMenuItem<String>>(
                    (ingredient) => DropdownMenuItem<String>(
                      value: ingredient.id,
                      child: Text(ingredient.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _ingredientId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Cantidad comprada'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo total pagado',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Nota opcional'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Costo unitario calculado: ${currency.format(unitCost)}',
              ),
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
