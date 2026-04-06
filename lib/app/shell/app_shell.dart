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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120D08), Color(0xFF24140A), Color(0xFFF4EBDD)],
            stops: [0, 0.28, 0.28],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (isDesktop) _DesktopNavigation(current: destination),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(isDesktop ? 0 : 12, 12, 12, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF6EA), Color(0xFFF0E4D2)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  child: child,
                ),
              ),
            ],
          ),
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
    return Container(
      color: const Color(0xFF1A1208),
      width: 108,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7A30A), Color(0xFFCF5F0A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x552F1200),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.local_fire_department_rounded, color: Colors.white),
                SizedBox(height: 6),
                Text(
                  'B&J',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          for (final item in AppDestination.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NavTile(item: item, selected: item == current),
            ),
          const Spacer(),
          const RotatedBox(
            quarterTurns: 3,
            child: Text(
              'BJ BURGERS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
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
    return Material(
      color: selected ? const Color(0xFFF28C00) : const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go(item.route),
        child: SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Icon(
                  item.icon,
                  color: selected
                      ? const Color(0xFF1A1208)
                      : const Color(0xFFF8E9D2),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF1A1208)
                        : const Color(0xFFF8E9D2),
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
      AppDestination.dashboard,
      AppDestination.comandas,
      AppDestination.pos,
      AppDestination.caja,
      null,
    ];

    final selectedIndex = primaryItems.indexOf(current);
    final resolvedIndex = selectedIndex < 0 ? 4 : selectedIndex;

    return NavigationBar(
      selectedIndex: resolvedIndex,
      onDestinationSelected: (index) {
        if (index == 4) {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mas vistas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final item in const [
                      AppDestination.inventario,
                      AppDestination.compras,
                      AppDestination.reportes,
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
          icon: Icon(Icons.space_dashboard_rounded),
          label: 'Inicio',
        ),
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
          icon: Icon(Icons.grid_view_rounded),
          label: 'Mas',
        ),
      ],
    );
  }
}
