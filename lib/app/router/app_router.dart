import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/caja/presentation/screens/caja_screen.dart';
import '../../features/comandas/presentation/screens/comandas_screen.dart';
import '../../features/compras/presentation/screens/compras_screen.dart';
import '../../features/inventario/presentation/screens/inventario_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/reportes/presentation/screens/reportes_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppDestination.comandas.route,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppDestination.pos.route,
            pageBuilder: (context, state) =>
                _buildRouteTransition(state: state, child: const PosScreen()),
          ),
          GoRoute(
            path: AppDestination.comandas.route,
            pageBuilder: (context, state) => _buildRouteTransition(
              state: state,
              child: const ComandasScreen(),
            ),
          ),
          GoRoute(
            path: AppDestination.inventario.route,
            pageBuilder: (context, state) => _buildRouteTransition(
              state: state,
              child: const InventarioScreen(),
            ),
          ),
          GoRoute(
            path: AppDestination.compras.route,
            pageBuilder: (context, state) => _buildRouteTransition(
              state: state,
              child: const ComprasScreen(),
            ),
          ),
          GoRoute(
            path: AppDestination.caja.route,
            pageBuilder: (context, state) =>
                _buildRouteTransition(state: state, child: const CajaScreen()),
          ),
          GoRoute(
            path: AppDestination.reportes.route,
            pageBuilder: (context, state) => _buildRouteTransition(
              state: state,
              child: const ReportesScreen(),
            ),
          ),
          GoRoute(
            path: AppDestination.settings.route,
            pageBuilder: (context, state) => _buildRouteTransition(
              state: state,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _buildRouteTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum AppDestination {
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
      orElse: () => AppDestination.comandas,
    );
  }
}
