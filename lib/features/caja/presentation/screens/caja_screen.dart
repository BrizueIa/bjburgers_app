import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/ui_cards.dart';
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

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppMiniStatCard(
                          label: 'Modo',
                          value: admin.enabled ? 'Admin' : 'Lectura',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: activeSessionAsync.when(
                          data: (session) => AppMiniStatCard(
                            label: 'Sesion',
                            value: session == null ? 'Cerrada' : 'Abierta',
                          ),
                          loading: () => const AppMiniStatCard(
                            label: 'Sesion',
                            value: '...',
                          ),
                          error: (_, __) => const AppMiniStatCard(
                            label: 'Sesion',
                            value: 'Error',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Activa'),
                      Tab(text: 'Historial'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [activePanel, historyPanel]),
                ),
              ],
            ),
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
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.point_of_sale_rounded, size: 32),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: adminEnabled
                            ? () => _showOpenSessionDialog(context, ref)
                            : null,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Abrir caja'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final movementsAsync = ref.watch(cashMovementsProvider(session.id));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _CashSessionHeader(session: session, currency: currency),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        Chip(
                          label: Text(
                            'Ahorro: ${currency.format(session.ahorroTotal)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Guardadito: ${currency.format(session.guardaditoTotal)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.8,
                      children: [
                        OutlinedButton.icon(
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
                        OutlinedButton.icon(
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
                        OutlinedButton.icon(
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
            const SizedBox(height: 10),
            movementsAsync.when(
              data: (movements) => Column(
                children: movements
                    .map(
                      (movement) => Card(
                        child: ListTile(
                          dense: true,
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text('Historial', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...sessions.map(
            (session) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.isOpen ? 'Caja abierta' : 'Caja cerrada',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(session.openedAt)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(session.expectedCash),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            session.isOpen
                                ? 'Activa'
                                : 'Dif. ${currency.format(session.differenceAmount ?? 0)}',
                          ),
                        ),
                      ],
                    ),
                  ],
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

class _CashSessionHeader extends StatelessWidget {
  const _CashSessionHeader({required this.session, required this.currency});

  final CashSessionSummary session;
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
                    'Caja abierta',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text('Apertura ${currency.format(session.openingAmount)}'),
                ],
              ),
            ),
            Text(
              currency.format(session.expectedCash),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOpenSessionDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _OpenSessionDialog(ref: ref),
  );
}

class _OpenSessionDialog extends StatefulWidget {
  const _OpenSessionDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_OpenSessionDialog> createState() => _OpenSessionDialogState();
}

class _OpenSessionDialogState extends State<_OpenSessionDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir caja'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monto inicial'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
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
            final amount = double.tryParse(_amountController.text.trim()) ?? -1;
            if (amount < 0) return;
            await widget.ref
                .read(cajaRepositoryProvider)
                .openSession(
                  openingAmount: amount,
                  note: _noteController.text.trim(),
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}

Future<void> _showMovementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String movementType,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _MovementDialog(ref: ref, movementType: movementType),
  );
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.ref, required this.movementType});

  final WidgetRef ref;
  final String movementType;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_movementLabel(widget.movementType)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Efectivo')),
                ButtonSegment(value: 'transfer', label: Text('Transferencia')),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (selection) {
                setState(() => _paymentMethod = selection.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
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
            final amount = double.tryParse(_amountController.text.trim()) ?? -1;
            if (amount <= 0) return;
            await widget.ref
                .read(cajaRepositoryProvider)
                .addManualMovement(
                  movementType: widget.movementType,
                  amount: amount,
                  paymentMethod: _paymentMethod,
                  note: _noteController.text.trim(),
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

Future<void> _showCloseSessionDialog(
  BuildContext context,
  WidgetRef ref,
  CashSessionSummary session,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CloseSessionDialog(ref: ref, session: session),
  );
}

class _CloseSessionDialog extends StatefulWidget {
  const _CloseSessionDialog({required this.ref, required this.session});

  final WidgetRef ref;
  final CashSessionSummary session;

  @override
  State<_CloseSessionDialog> createState() => _CloseSessionDialogState();
}

class _CloseSessionDialogState extends State<_CloseSessionDialog> {
  late final TextEditingController _realCashController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _realCashController = TextEditingController(
      text: widget.session.expectedCash.toStringAsFixed(2),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _realCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corte de caja'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Venta total: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.totalSales)}',
            ),
            const SizedBox(height: 6),
            Text(
              'Ahorro: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.ahorroTotal)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Guardadito: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.guardaditoTotal)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Transferencias netas: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.transferNetSales)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Efectivo neto: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.cashNetSales)}',
            ),
            const SizedBox(height: 6),
            Text(
              'Esperado en efectivo: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(widget.session.expectedCash)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _realCashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado real',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
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
                double.tryParse(_realCashController.text.trim()) ?? -1;
            if (realCash < 0) return;
            await widget.ref
                .read(cajaRepositoryProvider)
                .closeSession(
                  realCash: realCash,
                  note: _noteController.text.trim(),
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Cerrar caja'),
        ),
      ],
    );
  }
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
