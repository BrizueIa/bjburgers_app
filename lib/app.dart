import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'data/api_client.dart';
import 'data/device_store.dart';
import 'domain/models.dart';

final deviceStoreProvider = Provider<DeviceStore>((ref) => DeviceStore());
final apiProvider = Provider<BjApiClient>(
  (ref) => BjApiClient(ref.watch(deviceStoreProvider)),
);

const _gold = Color(0xffe8b85f);
const _red = Color(0xffef233c);
const _ink = Color(0xff0a0d0b);
const _panel = Color(0xff151a16);

class BjOperationsApp extends ConsumerWidget {
  const BjOperationsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'B&J Operación',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gold,
        brightness: Brightness.dark,
        surface: _panel,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
    ),
    home: const _RootGate(),
  );
}

class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();
  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  late Future<String?> _credential;
  @override
  void initState() {
    super.initState();
    _credential = ref.read(deviceStoreProvider).credential();
  }

  void _linked() =>
      setState(() => _credential = ref.read(deviceStoreProvider).credential());
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _credential,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _LoadingView();
      }
      return snapshot.data == null
          ? DeviceSetupScreen(onLinked: _linked)
          : const OrdersBoardScreen();
    },
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key, required this.onLinked});
  final VoidCallback onLinked;
  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _deviceId = TextEditingController();
  final _pairingCode = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _deviceId.dispose();
    _pairingCode.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(apiProvider)
          .activateDevice(
            deviceId: _deviceId.text,
            pairingCode: _pairingCode.text,
          );
      widget.onLinked();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 28),
                  Text(
                    'Vincular este Android',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea un código temporal en el panel B&J. Este paso se hace una sola vez y no agrega una pantalla de inicio de sesión.',
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _deviceId,
                    decoration: const InputDecoration(
                      labelText: 'ID del dispositivo',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pairingCode,
                    decoration: const InputDecoration(
                      labelText: 'Código temporal',
                    ),
                    autocorrect: false,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_error!, style: const TextStyle(color: _red)),
                    ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _busy ? null : _activate,
                    icon: const Icon(Icons.link),
                    label: Text(_busy ? 'Vinculando…' : 'Vincular dispositivo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OrdersBoardScreen extends ConsumerStatefulWidget {
  const OrdersBoardScreen({super.key});
  @override
  ConsumerState<OrdersBoardScreen> createState() => _OrdersBoardScreenState();
}

class _OrdersBoardScreenState extends ConsumerState<OrdersBoardScreen>
    with WidgetsBindingObserver {
  List<Order> _orders = const [];
  String _filter = 'all';
  String? _error;
  bool _loading = true;
  String? _selectedId;
  StreamSubscription<void>? _events;
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _events = ref
        .read(apiProvider)
        .orderEvents()
        .listen((_) => _load(silent: true), onError: (_) {});
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await ref
          .read(apiProvider)
          .orders(status: _filter == 'all' ? null : _filter);
      if (mounted) {
        setState(() {
          _orders = rows;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openImport() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const OrderImportScreen()));
    if (created == true) _load(silent: true);
  }

  Future<void> _openOrder(Order order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
    if (changed == true) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _orders
        .where((order) => order.id == _selectedId)
        .cast<Order?>()
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const _BrandHeader(compact: true),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openImport,
        icon: const Icon(Icons.add),
        label: const Text('Importar pedido'),
      ),
      body: Column(
        children: [
          _StatusFilters(
            value: _filter,
            onChanged: (value) {
              setState(() => _filter = value);
              _load();
            },
          ),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _load),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final list = _OrdersList(
                        orders: _orders,
                        onOpen: (order) {
                          if (constraints.maxWidth >= 800) {
                            setState(() => _selectedId = order.id);
                          } else {
                            _openOrder(order);
                          }
                        },
                      );
                      if (constraints.maxWidth < 800) return list;
                      return Row(
                        children: [
                          SizedBox(width: 410, child: list),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: selected == null
                                ? const _EmptyDetail()
                                : OrderDetailScreen(
                                    orderId: selected.id,
                                    embedded: true,
                                    onChanged: () => _load(silent: true),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.onOpen});
  final List<Order> orders;
  final ValueChanged<Order> onOpen;
  @override
  Widget build(BuildContext context) => orders.isEmpty
      ? const Center(child: Text('No hay comandas en este estado.'))
      : RefreshIndicator(
          onRefresh: () async {},
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpen(order),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusPill(order.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.items
                              .map(
                                (item) =>
                                    '${item.quantity}× ${item.productName}',
                              )
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              money(order.totalCents),
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(order.createdAt.toLocal()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  static const _items = [
    ('all', 'Todas'),
    ('new', 'Nuevas'),
    ('preparing', 'Preparación'),
    ('ready', 'Listas'),
    ('out_for_delivery', 'En entrega'),
    ('delivered', 'Entregadas'),
  ];
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
    child: Row(
      children: _items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: value == item.$1,
                onSelected: (_) => onChanged(item.$1),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.embedded = false,
    this.onChanged,
  });
  final String orderId;
  final bool embedded;
  final VoidCallback? onChanged;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _order = null);
      final order = await ref.read(apiProvider).order(widget.orderId);
      if (mounted) setState(() => _order = order);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _status(String status) async {
    setState(() => _busy = true);
    try {
      final order = await ref
          .read(apiProvider)
          .updateStatus(widget.orderId, status);
      if (mounted) {
        setState(() => _order = order);
        widget.onChanged?.call();
      }
    } on ApiException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issueCode() async {
    setState(() => _busy = true);
    try {
      final issued = await ref.read(apiProvider).issueSpinCode(widget.orderId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de ruleta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                issued.code,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: _gold),
              ),
              const SizedBox(height: 12),
              Text(
                'Vence: ${issued.expiresAt == null ? '—' : DateFormat('d MMM y').format(issued.expiresAt!.toLocal())}',
              ),
              const Text(
                'Compártelo únicamente con el cliente. No se muestra de nuevo fuera de esta emisión.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: issued.code));
                _notice('Código copiado.');
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Share.share(
                'Tu código de ruleta B&J Burgers: ${issued.code}\nVálido por 30 días.',
              ),
              child: const Text('Compartir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      await _load();
      widget.onChanged?.call();
    } on ApiException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    final body = _error != null
        ? _ErrorBanner(message: _error!, onRetry: _load)
        : _order == null
        ? const Center(child: CircularProgressIndicator())
        : _OrderDetail(
            order: _order!,
            busy: _busy,
            onStatus: _status,
            onIssueCode: _issueCode,
          );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de comanda')),
      body: body,
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.busy,
    required this.onStatus,
    required this.onIssueCode,
  });
  final Order order;
  final bool busy;
  final ValueChanged<String> onStatus;
  final VoidCallback onIssueCode;
  String? get _next => switch (order.status) {
    'new' => 'preparing',
    'preparing' => 'ready',
    'ready' => 'out_for_delivery',
    'out_for_delivery' => 'delivered',
    _ => null,
  };
  String get _nextLabel => switch (_next) {
    'preparing' => 'Iniciar preparación',
    'ready' => 'Marcar lista',
    'out_for_delivery' => 'Enviar a entrega',
    'delivered' => 'Marcar entregada',
    _ => '',
  };
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              order.customerName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          _StatusPill(order.status),
        ],
      ),
      const SizedBox(height: 6),
      Text('${order.neighborhood} · ${order.streetAndNumber}'),
      if (order.references.isNotEmpty) Text('Referencias: ${order.references}'),
      if (order.deliveryNotes.isNotEmpty)
        Text('Indicaciones: ${order.deliveryNotes}'),
      const SizedBox(height: 18),
      ...order.items.map(
        (item) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}× ${item.productName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      money(item.lineTotalCents),
                      style: const TextStyle(color: _gold),
                    ),
                  ],
                ),
                if (item.removedIngredients.isNotEmpty)
                  Text('Sin: ${item.removedIngredients.join(', ')}'),
                if (item.modifiers.isNotEmpty)
                  Text(
                    'Extras: ${item.modifiers.map((value) => (value as Map<String, dynamic>)['name']).join(', ')}',
                  ),
                if (item.combo != null)
                  Text('Combo: ${item.combo!['drinkName']}'),
                if (item.note.isNotEmpty) Text('Nota: ${item.note}'),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            money(order.totalCents),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: _gold),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (_next != null)
        FilledButton(
          onPressed: busy ? null : () => onStatus(_next!),
          child: Text(_nextLabel),
        ),
      if (['new', 'preparing', 'ready'].contains(order.status))
        OutlinedButton(
          onPressed: busy ? null : () => onStatus('cancelled'),
          child: const Text('Cancelar comanda'),
        ),
      if (order.status == 'delivered') ...[
        const SizedBox(height: 8),
        order.spinCodeIssued
            ? const ListTile(
                leading: Icon(Icons.check_circle, color: _gold),
                title: Text('Código de ruleta ya emitido'),
              )
            : OutlinedButton.icon(
                onPressed: busy ? null : onIssueCode,
                icon: const Icon(Icons.casino),
                label: const Text('Generar código de ruleta'),
              ),
      ],
      const SizedBox(height: 24),
      Text('Cronología', style: Theme.of(context).textTheme.titleLarge),
      ...order.events.map(
        (event) => ListTile(
          leading: const Icon(Icons.circle, size: 12, color: _gold),
          title: Text(
            event.status == null ? event.type : statusLabel(event.status!),
          ),
          subtitle: Text(
            '${event.note}${event.note.isEmpty ? '' : '\n'}${DateFormat('d MMM, HH:mm').format(event.createdAt.toLocal())}',
          ),
        ),
      ),
    ],
  );
}

class OrderImportScreen extends ConsumerStatefulWidget {
  const OrderImportScreen({super.key});
  @override
  ConsumerState<OrderImportScreen> createState() => _OrderImportScreenState();
}

class _OrderImportScreenState extends ConsumerState<OrderImportScreen> {
  final _raw = TextEditingController();
  final _customer = TextEditingController();
  final _neighborhood = TextEditingController();
  final _address = TextEditingController();
  final _references = TextEditingController();
  final _notes = TextEditingController();
  CatalogData? _catalog;
  OrderDraft? _draft;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    for (final controller in [
      _raw,
      _customer,
      _neighborhood,
      _address,
      _references,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ref.read(apiProvider).catalog();
      if (mounted) setState(() => _catalog = catalog);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _parse() async {
    if (_raw.text.trim().length < 3) {
      setState(() => _error = 'Pega el mensaje de WhatsApp primero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await ref.read(apiProvider).parseDraft(_raw.text);
      _applyDraft(draft);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyDraft(OrderDraft draft) {
    _customer.text = draft.customerName;
    _neighborhood.text = draft.neighborhood;
    _address.text = draft.streetAndNumber;
    _references.text = draft.references;
    _notes.text = draft.deliveryNotes;
    setState(() => _draft = draft);
  }

  void _addItem() {
    final product = _catalog?.products
        .where((item) => item.available)
        .firstOrNull;
    if (product == null) return;
    setState(
      () => (_draft ??= OrderDraft.empty()).items.add(
        DraftItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
        ),
      ),
    );
  }

  Future<void> _create() async {
    final draft = _draft;
    if (draft == null) {
      setState(
        () => _error = 'Interpreta o captura el pedido antes de guardarlo.',
      );
      return;
    }
    draft
      ..rawMessage = _raw.text
      ..customerName = _customer.text.trim()
      ..neighborhood = _neighborhood.text.trim()
      ..streetAndNumber = _address.text.trim()
      ..references = _references.text.trim()
      ..deliveryNotes = _notes.text.trim();
    if (draft.customerName.isEmpty || draft.items.isEmpty) {
      setState(() => _error = 'Indica cliente y al menos un producto.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createOrder(draft);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comanda creada.')));
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importar pedido de WhatsApp')),
    body: _catalog == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
            children: [
              Text(
                '1. Pega y revisa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'La app interpreta el formato de B&J. Nada se guarda hasta que confirmes la vista previa.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _raw,
                maxLines: 7,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensaje recibido por WhatsApp',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _parse,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Interpretar pedido'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _ErrorBanner(message: _error!, onRetry: _parse),
                ),
              if (_draft != null) ..._editor(context),
            ],
          ),
  );
  List<Widget> _editor(BuildContext context) {
    final draft = _draft!;
    return [
      const SizedBox(height: 26),
      Text(
        '2. Confirma la comanda',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (draft.unresolvedLines.isNotEmpty)
        Card(
          color: const Color(0xff4a3410),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No se reconoció: ${draft.unresolvedLines.join(' · ')}. Corrige o agrega el producto antes de continuar.',
            ),
          ),
        ),
      const SizedBox(height: 10),
      _TextField(
        controller: _customer,
        label: 'Nombre del cliente',
        required: true,
      ),
      _TextField(controller: _neighborhood, label: 'Colonia'),
      _TextField(controller: _address, label: 'Calle y número'),
      _TextField(controller: _references, label: 'Referencias', lines: 2),
      _TextField(controller: _notes, label: 'Indicaciones', lines: 2),
      const SizedBox(height: 16),
      Row(
        children: [
          Text('Productos', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      ...List.generate(
        draft.items.length,
        (index) => _DraftItemEditor(
          key: ValueKey('${draft.items[index].productId}-$index'),
          item: draft.items[index],
          catalog: _catalog!,
          onChanged: () => setState(() {}),
          onDelete: () => setState(() => draft.items.removeAt(index)),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Estimado sin promoción: ${money(_estimatedTotal(draft))}',
        style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'El servidor recalcula el total, promociones y disponibilidad al guardar.',
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.save),
        label: Text(_busy ? 'Guardando…' : 'Crear comanda confirmada'),
      ),
    ];
  }

  int _estimatedTotal(OrderDraft draft) => draft.items.fold(0, (sum, item) {
    final product = _catalog!.products.firstWhere(
      (value) => value.id == item.productId,
    );
    final extras = item.modifierIds.fold(
      0,
      (extra, id) =>
          extra +
          (_catalog!.modifiers
                  .where((value) => value.id == id)
                  .firstOrNull
                  ?.priceCents ??
              0),
    );
    return sum +
        (product.priceCents + extras + (item.combo ? 4600 : 0)) * item.quantity;
  });
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.lines = 1,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final int lines;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        alignLabelWithHint: lines > 1,
      ),
    ),
  );
}

class _DraftItemEditor extends StatefulWidget {
  const _DraftItemEditor({
    super.key,
    required this.item,
    required this.catalog,
    required this.onChanged,
    required this.onDelete,
  });
  final DraftItem item;
  final CatalogData catalog;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  @override
  State<_DraftItemEditor> createState() => _DraftItemEditorState();
}

class _DraftItemEditorState extends State<_DraftItemEditor> {
  Product get _product => widget.catalog.products.firstWhere(
    (product) => product.id == widget.item.productId,
  );
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final drinks = widget.catalog.products
        .where(
          (product) =>
              product.id.contains('coca') ||
              product.id == 'delaware' ||
              product.id == 'escuis' ||
              product.id == 'fanta',
        )
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.productId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: widget.catalog.products
                        .where(
                          (product) =>
                              product.available || product.id == item.productId,
                        )
                        .map(
                          (product) => DropdownMenuItem(
                            value: product.id,
                            child: Text(
                              '${product.name} · ${money(product.priceCents)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final product = widget.catalog.products.firstWhere(
                        (value) => value.id == id,
                      );
                      setState(() {
                        item.productId = id;
                        item.productName = product.name;
                        item.removedIngredients = [];
                        item.modifierIds = [];
                        if (!product.comboEligible) {
                          item.combo = false;
                          item.drinkProductId = null;
                        }
                      });
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  tooltip: 'Quitar producto',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Cantidad'),
                IconButton(
                  onPressed: item.quantity > 1
                      ? () {
                          setState(() => item.quantity--);
                          widget.onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '${item.quantity}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: item.quantity < 20
                      ? () {
                          setState(() => item.quantity++);
                          widget.onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_product.removableIngredients.isNotEmpty)
              ExpansionTile(
                title: const Text('Ingredientes a retirar'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  Wrap(
                    spacing: 6,
                    children: _product.removableIngredients
                        .map(
                          (ingredient) => FilterChip(
                            label: Text(ingredient),
                            selected: item.removedIngredients.contains(
                              ingredient,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                selected
                                    ? item.removedIngredients.add(ingredient)
                                    : item.removedIngredients.remove(
                                        ingredient,
                                      );
                              });
                              widget.onChanged();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ExpansionTile(
              title: const Text('Extras'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Wrap(
                  spacing: 6,
                  children: widget.catalog.modifiers
                      .where((modifier) => modifier.available)
                      .map(
                        (modifier) => FilterChip(
                          label: Text(
                            '${modifier.name} +${money(modifier.priceCents)}',
                          ),
                          selected: item.modifierIds.contains(modifier.id),
                          onSelected: (selected) {
                            setState(() {
                              selected
                                  ? item.modifierIds.add(modifier.id)
                                  : item.modifierIds.remove(modifier.id);
                            });
                            widget.onChanged();
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            if (_product.comboEligible)
              SwitchListTile(
                value: item.combo,
                contentPadding: EdgeInsets.zero,
                title: const Text('Hacer combo (+\$46)'),
                subtitle: const Text('Incluye papas 100 g y refresco.'),
                onChanged: (selected) {
                  setState(() {
                    item.combo = selected;
                    if (!selected) item.drinkProductId = null;
                  });
                  widget.onChanged();
                },
              ),
            if (item.combo)
              DropdownButtonFormField<String>(
                initialValue: item.drinkProductId,
                decoration: const InputDecoration(
                  labelText: 'Refresco del combo',
                ),
                items: drinks
                    .map(
                      (drink) => DropdownMenuItem(
                        value: drink.id,
                        child: Text(drink.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => item.drinkProductId = value);
                  widget.onChanged();
                },
              ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Nota del producto'),
              onChanged: (value) {
                item.note = value;
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    children: [
      Image.asset(
        'assets/logo.jpeg',
        width: compact ? 38 : 58,
        height: compact ? 38 : 58,
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'B&J BURGERS',
            style: TextStyle(
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
              color: compact ? Colors.white : _gold,
            ),
          ),
          if (!compact)
            const Text(
              'OPERACIÓN',
              style: TextStyle(letterSpacing: 2, fontSize: 12),
            ),
        ],
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'cancelled'
          ? _red.withValues(alpha: .18)
          : _gold.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      statusLabel(status),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Selecciona una comanda para ver su detalle.'));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _red),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

String statusLabel(String status) => switch (status) {
  'new' => 'Nueva',
  'preparing' => 'Preparación',
  'ready' => 'Lista',
  'out_for_delivery' => 'En entrega',
  'delivered' => 'Entregada',
  'cancelled' => 'Cancelada',
  _ => status,
};

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
