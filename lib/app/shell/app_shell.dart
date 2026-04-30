import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destination = AppDestination.fromLocation(location);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop) _DesktopNavigation(current: destination),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(isDesktop ? 0 : 10, 10, 10, 0),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(isDesktop ? 0 : 18),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _MobileNavigation(current: destination),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.current});

  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      width: 96,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: scheme.primary,
            ),
            child: const Icon(Icons.lunch_dining_rounded, color: Colors.white),
          ),

          const SizedBox(height: 18),
          for (final item in AppDestination.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _NavTile(item: item, selected: item == current),
            ),
          const Spacer(),
          Text(
            'BJ',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected});

  final AppDestination item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(item.route),
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              children: [
                Icon(
                  item.icon,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.current});

  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    const primaryItems = [
      AppDestination.comandas,
      AppDestination.pos,
      AppDestination.caja,
      AppDestination.reportes,
      null,
    ];

    final selectedIndex = primaryItems.indexOf(current);
    final resolvedIndex = selectedIndex < 0 ? 4 : selectedIndex;

    return NavigationBar(
      elevation: 0,
      selectedIndex: resolvedIndex,
      onDestinationSelected: (index) {
        if (index == 4) {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mas vistas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in const [
                      AppDestination.inventario,
                      AppDestination.compras,
                      AppDestination.settings,
                    ])
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(item.route);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
          return;
        }
        if (index < primaryItems.length) {
          final destination = primaryItems[index];
          if (destination != null) {
            context.go(destination.route);
          }
          return;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.receipt_long_rounded),
          label: 'Comandas',
        ),
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_rounded),
          label: 'POS',
        ),
        NavigationDestination(
          icon: Icon(Icons.payments_rounded),
          label: 'Caja',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Reportes',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Mas',
        ),
      ],
    );
  }
}
