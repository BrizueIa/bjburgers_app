import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/database/app_database.dart';
import '../../data/inventory_repository.dart';
import '../controllers/inventory_controller.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Chip(
                avatar: Icon(
                  admin.enabled
                      ? Icons.admin_panel_settings_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
                label: Text(admin.enabled ? 'Edicion activa' : 'Solo consulta'),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ingredientes'),
            Tab(text: 'Productos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_IngredientsTab(), _ProductsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!admin.enabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Activa el modo admin para modificar inventario.',
                ),
              ),
            );
            return;
          }

          if (_tabController.index == 0) {
            _showIngredientDialog(context, ref);
          } else {
            _showProductDialog(context, ref);
          }
        },
        icon: Icon(
          _tabController.index == 0
              ? Icons.add_box_rounded
              : Icons.add_business_rounded,
        ),
        label: Text(
          _tabController.index == 0 ? 'Nuevo ingrediente' : 'Nuevo producto',
        ),
      ),
    );
  }
}

class _IngredientsTab extends ConsumerWidget {
  const _IngredientsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(ingredientsProvider);
    final admin = ref.watch(adminModeProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return ingredients.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.inventory_2_rounded,
            title: 'Todavia no hay ingredientes',
            message:
                'Agrega insumos como carne, pan, queso o verduras para construir recetas.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemBuilder: (context, index) {
            final ingredient = items[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                title: Text(ingredient.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Unidad: ${ingredient.unitName}')),
                      Chip(
                        label: Text(
                          'Costo actual: ${currency.format(ingredient.currentUnitCost)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          ingredient.isActive ? 'Activo' : 'Inactivo',
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  enabled: admin.enabled,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showIngredientDialog(
                        context,
                        ref,
                        ingredient: ingredient,
                      );
                      return;
                    }

                    if (value == 'archive') {
                      await ref
                          .read(inventoryRepositoryProvider)
                          .archiveIngredient(ingredient);
                      return;
                    }

                    await ref
                        .read(inventoryRepositoryProvider)
                        .toggleIngredientActive(ingredient);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        ingredient.isActive ? 'Desactivar' : 'Activar',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archivar'),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorState(message: '$error'),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productSummariesProvider);
    final admin = ref.watch(adminModeProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return products.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.fastfood_rounded,
            title: 'Todavia no hay productos',
            message:
                'Aqui crearas refrescos simples y hamburguesas con receta por ingrediente.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemBuilder: (context, index) {
            final product = items[index];
            return Card(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(product.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          product.productType == 'simple'
                              ? 'Simple'
                              : 'Con receta',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Venta: ${currency.format(product.salePrice)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Costo: ${currency.format(product.calculatedCost)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Margen: ${currency.format(product.margin)}',
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  enabled: admin.enabled,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final recipeDraft = await ref
                          .read(inventoryRepositoryProvider)
                          .fetchRecipeDraft(product.id);
                      if (!context.mounted) return;
                      _showProductDialog(
                        context,
                        ref,
                        product: product,
                        recipeDraft: recipeDraft,
                      );
                      return;
                    }

                    if (value == 'archive') {
                      await ref
                          .read(inventoryRepositoryProvider)
                          .archiveProduct(product);
                      return;
                    }

                    await ref
                        .read(inventoryRepositoryProvider)
                        .toggleProductActive(product);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(product.isActive ? 'Desactivar' : 'Activar'),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archivar'),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.productType == 'simple'
                          ? 'Costo directo: ${currency.format(product.directCost)}'
                          : 'Ingredientes en receta: ${product.recipeLines}',
                    ),
                  ),
                  if (product.productType == 'recipe')
                    Consumer(
                      builder: (context, ref, child) {
                        final recipe = ref.watch(recipeProvider(product.id));
                        return recipe.when(
                          data: (lines) => Column(
                            children: lines
                                .map(
                                  (line) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(line.ingredient.name),
                                    subtitle: Text(
                                      '${line.item.quantityUsed} ${line.ingredient.unitName}${line.item.isOptional ? ' · opcional' : ''}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stackTrace) => Text('$error'),
                        );
                      },
                    ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorState(message: '$error'),
    );
  }
}

Future<void> _showIngredientDialog(
  BuildContext context,
  WidgetRef ref, {
  Ingredient? ingredient,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _IngredientDialog(ingredient: ingredient),
  );
}

Future<void> _showProductDialog(
  BuildContext context,
  WidgetRef ref, {
  ProductSummary? product,
  List<RecipeDraftItem>? recipeDraft,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _ProductDialog(product: product, recipeDraft: recipeDraft ?? const []),
  );
}

class _IngredientDialog extends ConsumerStatefulWidget {
  const _IngredientDialog({this.ingredient});

  final Ingredient? ingredient;

  @override
  ConsumerState<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends ConsumerState<_IngredientDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.ingredient?.name ?? '',
    );
    _unitController = TextEditingController(
      text: widget.ingredient?.unitName ?? 'unidad',
    );
    _costController = TextEditingController(
      text: widget.ingredient == null
          ? ''
          : widget.ingredient!.currentUnitCost.toStringAsFixed(2),
    );
    _isActive = widget.ingredient?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingredient == null ? 'Nuevo ingrediente' : 'Editar ingrediente',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unidad de uso'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo unitario actual',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: const Text('Activo'),
              onChanged: (value) => setState(() => _isActive = value),
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
            final name = _nameController.text.trim();
            final unitName = _unitController.text.trim();
            final cost = double.tryParse(_costController.text.trim()) ?? 0;

            if (name.isEmpty || unitName.isEmpty) {
              return;
            }

            await ref
                .read(inventoryRepositoryProvider)
                .saveIngredient(
                  id: widget.ingredient?.id,
                  name: name,
                  unitName: unitName,
                  currentUnitCost: cost,
                  isActive: _isActive,
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ProductDialog extends ConsumerStatefulWidget {
  const _ProductDialog({this.product, required this.recipeDraft});

  final ProductSummary? product;
  final List<RecipeDraftItem> recipeDraft;

  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _directCostController;
  late String _productType;
  late bool _isActive;
  late final List<_RecipeEditorItem> _recipeItems;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(
      text: widget.product?.categoryName ?? '',
    );
    _salePriceController = TextEditingController(
      text: widget.product == null
          ? ''
          : widget.product!.salePrice.toStringAsFixed(2),
    );
    _directCostController = TextEditingController(
      text: widget.product == null
          ? ''
          : widget.product!.directCost.toStringAsFixed(2),
    );
    _productType = widget.product?.productType ?? 'recipe';
    _isActive = widget.product?.isActive ?? true;
    _recipeItems = widget.recipeDraft
        .map(
          (item) => _RecipeEditorItem(
            ingredientId: item.ingredientId,
            quantityController: TextEditingController(
              text: item.quantityUsed.toString(),
            ),
            isOptional: item.isOptional,
          ),
        )
        .toList();
    if (_recipeItems.isEmpty) {
      _recipeItems.add(
        _RecipeEditorItem(quantityController: TextEditingController(text: '1')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _salePriceController.dispose();
    _directCostController.dispose();
    for (final item in _recipeItems) {
      item.quantityController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider);

    return AlertDialog(
      title: Text(
        widget.product == null ? 'Nuevo producto' : 'Editar producto',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de producto',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'recipe',
                    child: Text('Compuesto por receta'),
                  ),
                  DropdownMenuItem(
                    value: 'simple',
                    child: Text('Simple / costo directo'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _productType = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _salePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Precio de venta'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _directCostController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _productType == 'simple'
                      ? 'Costo directo'
                      : 'Costo directo opcional',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text('Activo'),
                onChanged: (value) => setState(() => _isActive = value),
              ),
              if (_productType == 'recipe') ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Receta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                ingredients.when(
                  data: (ingredientList) {
                    if (ingredientList.isEmpty) {
                      return const Text(
                        'Primero agrega ingredientes para poder construir una receta.',
                      );
                    }

                    return Column(
                      children: [
                        for (final item in _recipeItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        ingredientList.any(
                                          (ing) => ing.id == item.ingredientId,
                                        )
                                        ? item.ingredientId
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Ingrediente',
                                    ),
                                    items: ingredientList
                                        .map<DropdownMenuItem<String>>(
                                          (ingredient) =>
                                              DropdownMenuItem<String>(
                                                value: ingredient.id,
                                                child: Text(ingredient.name),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => item.ingredientId = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: item.quantityController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _recipeItems.length == 1
                                      ? null
                                      : () {
                                          setState(() {
                                            item.quantityController.dispose();
                                            _recipeItems.remove(item);
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _recipeItems.add(
                                  _RecipeEditorItem(
                                    quantityController: TextEditingController(
                                      text: '1',
                                    ),
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar ingrediente'),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => Text('$error'),
                ),
              ],
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
            final name = _nameController.text.trim();
            final salePrice =
                double.tryParse(_salePriceController.text.trim()) ?? -1;
            final directCost =
                double.tryParse(_directCostController.text.trim()) ?? 0;
            if (name.isEmpty || salePrice < 0) {
              return;
            }

            final recipe = _productType == 'recipe'
                ? _recipeItems
                      .where((item) => item.ingredientId != null)
                      .map(
                        (item) => RecipeDraftItem(
                          ingredientId: item.ingredientId!,
                          quantityUsed:
                              double.tryParse(
                                item.quantityController.text.trim(),
                              ) ??
                              0,
                        ),
                      )
                      .where((item) => item.quantityUsed > 0)
                      .toList()
                : <RecipeDraftItem>[];

            if (_productType == 'recipe' && recipe.isEmpty) {
              return;
            }

            await ref
                .read(inventoryRepositoryProvider)
                .saveProduct(
                  id: widget.product?.id,
                  name: name,
                  categoryName: _categoryController.text.trim(),
                  productType: _productType,
                  salePrice: salePrice,
                  directCost: directCost,
                  isActive: _isActive,
                  recipeItems: recipe,
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _RecipeEditorItem {
  _RecipeEditorItem({
    this.ingredientId,
    required this.quantityController,
    this.isOptional = false,
  });

  String? ingredientId;
  final TextEditingController quantityController;
  bool isOptional;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
