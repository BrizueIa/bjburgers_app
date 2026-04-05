import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/caja/presentation/screens/caja_screen.dart';
import '../../features/comandas/presentation/screens/comandas_screen.dart';
import '../../features/compras/presentation/screens/compras_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/inventario/presentation/screens/inventario_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/reportes/presentation/screens/reportes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppDestination.dashboard.route,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppDestination.dashboard.route,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppDestination.pos.route,
            builder: (context, state) => const PosScreen(),
          ),
          GoRoute(
            path: AppDestination.comandas.route,
            builder: (context, state) => const ComandasScreen(),
          ),
          GoRoute(
            path: AppDestination.inventario.route,
            builder: (context, state) => const InventarioScreen(),
          ),
          GoRoute(
            path: AppDestination.compras.route,
            builder: (context, state) => const ComprasScreen(),
          ),
          GoRoute(
            path: AppDestination.caja.route,
            builder: (context, state) => const CajaScreen(),
          ),
          GoRoute(
            path: AppDestination.reportes.route,
            builder: (context, state) => const ReportesScreen(),
          ),
          GoRoute(
            path: AppDestination.settings.route,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

enum AppDestination {
  dashboard('/dashboard', 'Dashboard', Icons.space_dashboard_rounded),
  pos('/pos', 'POS', Icons.point_of_sale_rounded),
  comandas('/comandas', 'Comandas', Icons.receipt_long_rounded),
  inventario('/inventario', 'Inventario', Icons.inventory_2_rounded),
  compras('/compras', 'Compras', Icons.shopping_cart_rounded),
  caja('/caja', 'Caja', Icons.payments_rounded),
  reportes('/reportes', 'Reportes', Icons.bar_chart_rounded),
  settings('/settings', 'Settings', Icons.settings_rounded);

  const AppDestination(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;

  static AppDestination fromLocation(String location) {
    return AppDestination.values.firstWhere(
      (destination) => location.startsWith(destination.route),
      orElse: () => AppDestination.dashboard,
    );
  }
}
