import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/storage/promo_config.dart';
import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../../../inventario/presentation/controllers/inventory_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _menuController;
  late final TextEditingController _unlockController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _nameController = TextEditingController(text: settings.businessName);
    _menuController = TextEditingController(text: settings.digitalMenuUrl);
    _unlockController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _menuController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final admin = ref.watch(adminModeProvider);
    final sync = ref.watch(syncStatusProvider);
    final products =
        ref.watch(productSummariesProvider).valueOrNull ?? const [];
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: AppMiniStatCard(
                  label: 'Admin',
                  value: admin.enabled ? 'Activo' : 'Apagado',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppMiniStatCard(
                  label: 'Sync',
                  value: sync.isOnline ? 'Online' : 'Offline',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Negocio',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del negocio',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _menuController,
                  decoration: const InputDecoration(
                    labelText: 'URL o referencia del menu digital',
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(appSettingsProvider.notifier)
                          .updateBusinessName(_nameController.text.trim());
                      await ref
                          .read(appSettingsProvider.notifier)
                          .updateDigitalMenuUrl(_menuController.text.trim());
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Configuracion guardada.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Operacion e inventario',
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.stockTrackingEnabled,
              title: const Text('Controlar stock de ingredientes'),
              onChanged: (value) async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .updateStockTrackingEnabled(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Promociones',
            child: Column(
              children: [
                for (final promo in settings.promoConfigs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(promo.title),
                        subtitle: Text(
                          '${promo.dayLabel} · ${promo.count} item(s) · ${currency.format(promo.totalPrice)}',
                        ),
                        trailing: IconButton(
                          onPressed: admin.enabled
                              ? () async {
                                  final updated = await showDialog<PromoConfig>(
                                    context: context,
                                    builder: (_) => _PromoConfigDialog(
                                      promo: promo,
                                      productNames: products
                                          .map((item) => item.name)
                                          .toList(),
                                    ),
                                  );
                                  if (updated == null) return;
                                  final next = settings.promoConfigs
                                      .map(
                                        (item) => item.id == updated.id
                                            ? updated
                                            : item,
                                      )
                                      .toList();
                                  await ref
                                      .read(appSettingsProvider.notifier)
                                      .updatePromoConfigs(next);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Promocion actualizada.'),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Modo admin',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                      avatar: const Icon(Icons.pin_rounded, size: 18),
                      label: Text('PIN global activo (${_maskPin(admin.pin)})'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _unlockController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'PIN para activar admin',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref
                            .read(adminModeProvider.notifier)
                            .enableWithPin(_unlockController.text.trim());
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Modo admin activado.' : 'PIN incorrecto.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Activar admin'),
                    ),
                    OutlinedButton.icon(
                      onPressed: admin.enabled
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await ref
                                  .read(adminModeProvider.notifier)
                                  .disable();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Modo admin desactivado.'),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Apagar admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Sincronizacion base',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    sync.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  ),
                  title: Text(sync.statusLabel),
                  subtitle: Text(
                    settings.hasSupabaseConfig
                        ? 'Supabase detectado.'
                        : 'Sin config.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text('Ultimo intento: ${settings.lastSyncLabel}'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(appSettingsProvider.notifier)
                        .recordSyncAttempt();
                    final message = await ref
                        .read(syncStatusProvider.notifier)
                        .synchronize();
                    ref.read(appSettingsProvider.notifier).reload();
                    ref.read(adminModeProvider.notifier).reload();
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Forzar sincronizacion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _maskPin(String pin) {
  if (pin.isEmpty) return '****';
  return List.filled(pin.length, '*').join();
}

class _PromoConfigDialog extends StatefulWidget {
  const _PromoConfigDialog({required this.promo, required this.productNames});

  final PromoConfig promo;
  final List<String> productNames;

  @override
  State<_PromoConfigDialog> createState() => _PromoConfigDialogState();
}

class _PromoConfigDialogState extends State<_PromoConfigDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _dayController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late List<PromoProductSlotConfig> _slots;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.promo.title);
    _dayController = TextEditingController(text: widget.promo.dayLabel);
    _descriptionController = TextEditingController(
      text: widget.promo.description,
    );
    _priceController = TextEditingController(
      text: widget.promo.totalPrice.toStringAsFixed(2),
    );
    _slots = List<PromoProductSlotConfig>.from(widget.promo.slots);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dayController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.promo.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dayController,
                decoration: const InputDecoration(labelText: 'Dia visible'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Precio total'),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _slots.length; i++) ...[
                _PromoSlotEditor(
                  index: i,
                  slot: _slots[i],
                  productNames: widget.productNames,
                  onChanged: (slot) {
                    setState(() => _slots[i] = slot);
                  },
                  onRemove: _slots.length > 1
                      ? () {
                          setState(() => _slots.removeAt(i));
                        }
                      : null,
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _slots.add(
                        PromoProductSlotConfig(
                          fixedProductName: widget.productNames.firstOrNull,
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar item'),
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
          onPressed: () {
            final price = double.tryParse(_priceController.text.trim()) ?? -1;
            if (price < 0 || _slots.isEmpty) return;
            Navigator.of(context).pop(
              widget.promo.copyWith(
                title: _titleController.text.trim(),
                dayLabel: _dayController.text.trim(),
                description: _descriptionController.text.trim(),
                totalPrice: price,
                slots: _slots,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _PromoSlotEditor extends StatelessWidget {
  const _PromoSlotEditor({
    required this.index,
    required this.slot,
    required this.productNames,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final PromoProductSlotConfig slot;
  final List<String> productNames;
  final ValueChanged<PromoProductSlotConfig> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Item ${index + 1}')),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Fijo')),
                ButtonSegment<bool>(value: true, label: Text('A eleccion')),
              ],
              selected: {slot.needsSelection},
              onSelectionChanged: (selection) {
                final selectable = selection.first;
                onChanged(
                  selectable
                      ? PromoProductSlotConfig(
                          selectableProductNames:
                              slot.selectableProductNames.isEmpty
                              ? productNames.take(1).toList()
                              : slot.selectableProductNames,
                        )
                      : PromoProductSlotConfig(
                          fixedProductName:
                              slot.fixedProductName ?? productNames.firstOrNull,
                        ),
                );
              },
            ),
            const SizedBox(height: 10),
            if (!slot.needsSelection)
              DropdownButtonFormField<String>(
                initialValue: slot.fixedProductName,
                decoration: const InputDecoration(labelText: 'Producto fijo'),
                items: productNames
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  onChanged(PromoProductSlotConfig(fixedProductName: value));
                },
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDialog<List<String>>(
                      context: context,
                      builder: (_) => _SelectableProductsDialog(
                        allProducts: productNames,
                        selectedProducts: slot.selectableProductNames,
                      ),
                    );
                    if (selected == null || selected.isEmpty) return;
                    onChanged(
                      PromoProductSlotConfig(selectableProductNames: selected),
                    );
                  },
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(
                    '${slot.selectableProductNames.length} seleccionable(s)',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectableProductsDialog extends StatefulWidget {
  const _SelectableProductsDialog({
    required this.allProducts,
    required this.selectedProducts,
  });

  final List<String> allProducts;
  final List<String> selectedProducts;

  @override
  State<_SelectableProductsDialog> createState() =>
      _SelectableProductsDialogState();
}

class _SelectableProductsDialogState extends State<_SelectableProductsDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedProducts.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Productos a eleccion'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.allProducts
                .map(
                  (name) => CheckboxListTile(
                    value: _selected.contains(name),
                    title: Text(name),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
