import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/admin/admin_mode_controller.dart';
import '../../data/caja_repository.dart';
import '../controllers/caja_controller.dart';

class CajaScreen extends ConsumerWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminModeProvider);
    final activeSessionAsync = ref.watch(activeCashSessionProvider);
    final sessionsAsync = ref.watch(cashSessionsProvider);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Chip(
                avatar: Icon(
                  admin.enabled
                      ? Icons.admin_panel_settings_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                ),
                label: Text(admin.enabled ? 'Admin activo' : 'Solo lectura'),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1050;
          final activePanel = _ActiveSessionPanel(
            activeSessionAsync: activeSessionAsync,
            currency: currency,
            adminEnabled: admin.enabled,
          );
          final historyPanel = _SessionsHistory(
            sessionsAsync: sessionsAsync,
            currency: currency,
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 5, child: activePanel),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: historyPanel),
              ],
            );
          }

          return ListView(
            children: [
              SizedBox(height: 760, child: activePanel),
              const Divider(height: 1),
              SizedBox(height: 560, child: historyPanel),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveSessionPanel extends ConsumerWidget {
  const _ActiveSessionPanel({
    required this.activeSessionAsync,
    required this.currency,
    required this.adminEnabled,
  });

  final AsyncValue<CashSessionSummary?> activeSessionAsync;
  final NumberFormat currency;
  final bool adminEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return activeSessionAsync.when(
      data: (session) {
        if (session == null) {
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.point_of_sale_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No hay caja abierta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Abre una nueva sesion para empezar a registrar ventas y movimientos.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: adminEnabled
                          ? () => _showOpenSessionDialog(context, ref)
                          : null,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Abrir caja'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final movementsAsync = ref.watch(cashMovementsProvider(session.id));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja abierta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Apertura: ${currency.format(session.openingAmount)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Efectivo esperado: ${currency.format(session.expectedCash)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Transferencias: ${currency.format(session.transferSalesTotal)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Efectivo en ventas: ${currency.format(session.cashSalesTotal)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: adminEnabled
                              ? () => _showMovementDialog(
                                  context,
                                  ref,
                                  movementType: 'deposit',
                                )
                              : null,
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Deposito'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: adminEnabled
                              ? () => _showMovementDialog(
                                  context,
                                  ref,
                                  movementType: 'withdrawal',
                                )
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          label: const Text('Retiro'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: adminEnabled
                              ? () => _showMovementDialog(
                                  context,
                                  ref,
                                  movementType: 'adjustment',
                                )
                              : null,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Ajuste'),
                        ),
                        FilledButton.icon(
                          onPressed: adminEnabled
                              ? () => _showCloseSessionDialog(
                                  context,
                                  ref,
                                  session,
                                )
                              : null,
                          icon: const Icon(Icons.assignment_turned_in_rounded),
                          label: const Text('Corte de caja'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            movementsAsync.when(
              data: (movements) => Column(
                children: movements
                    .map(
                      (movement) => Card(
                        child: ListTile(
                          title: Text(_movementLabel(movement.movementType)),
                          subtitle: Text(
                            movement.note ??
                                _paymentLabel(movement.paymentMethod),
                          ),
                          trailing: Text(currency.format(movement.amount)),
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('$error'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _SessionsHistory extends StatelessWidget {
  const _SessionsHistory({required this.sessionsAsync, required this.currency});

  final AsyncValue<List<CashSessionSummary>> sessionsAsync;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    return sessionsAsync.when(
      data: (sessions) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Text('Historial', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...sessions.map(
            (session) => Card(
              child: ListTile(
                title: Text(session.isOpen ? 'Caja abierta' : 'Caja cerrada'),
                subtitle: Text(
                  '${dateFormat.format(session.openedAt)} · esperado ${currency.format(session.expectedCash)}',
                ),
                trailing: session.isOpen
                    ? const Chip(label: Text('Activa'))
                    : Chip(
                        label: Text(
                          'Dif. ${currency.format(session.differenceAmount ?? 0)}',
                        ),
                      ),
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

Future<void> _showOpenSessionDialog(BuildContext context, WidgetRef ref) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Abrir caja'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monto inicial'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Nota opcional'),
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
            final amount = double.tryParse(amountController.text.trim()) ?? -1;
            if (amount < 0) return;
            await ref
                .read(cajaRepositoryProvider)
                .openSession(
                  openingAmount: amount,
                  note: noteController.text.trim(),
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Abrir'),
        ),
      ],
    ),
  );
  amountController.dispose();
  noteController.dispose();
}

Future<void> _showMovementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String movementType,
}) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String paymentMethod = 'cash';
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(_movementLabel(movementType)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Efectivo')),
                  ButtonSegment(
                    value: 'transfer',
                    label: Text('Transferencia'),
                  ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (selection) =>
                    setState(() => paymentMethod = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Nota'),
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
              final amount =
                  double.tryParse(amountController.text.trim()) ?? -1;
              if (amount <= 0) return;
              await ref
                  .read(cajaRepositoryProvider)
                  .addManualMovement(
                    movementType: movementType,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    note: noteController.text.trim(),
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  amountController.dispose();
  noteController.dispose();
}

Future<void> _showCloseSessionDialog(
  BuildContext context,
  WidgetRef ref,
  CashSessionSummary session,
) async {
  final realCashController = TextEditingController(
    text: session.expectedCash.toStringAsFixed(2),
  );
  final noteController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Corte de caja'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esperado en efectivo: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(session.expectedCash)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: realCashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado real',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Nota opcional'),
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
            final realCash =
                double.tryParse(realCashController.text.trim()) ?? -1;
            if (realCash < 0) return;
            await ref
                .read(cajaRepositoryProvider)
                .closeSession(
                  realCash: realCash,
                  note: noteController.text.trim(),
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Cerrar caja'),
        ),
      ],
    ),
  );
  realCashController.dispose();
  noteController.dispose();
}

String _movementLabel(String movementType) {
  switch (movementType) {
    case 'opening':
      return 'Apertura';
    case 'sale':
      return 'Venta';
    case 'deposit':
      return 'Deposito';
    case 'withdrawal':
      return 'Retiro';
    case 'adjustment':
      return 'Ajuste';
    case 'closing':
      return 'Cierre';
    default:
      return movementType;
  }
}

String _paymentLabel(String? paymentMethod) {
  switch (paymentMethod) {
    case 'cash':
      return 'Efectivo';
    case 'transfer':
      return 'Transferencia';
    default:
      return 'Movimiento';
  }
}
