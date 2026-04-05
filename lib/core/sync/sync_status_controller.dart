import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';

class SyncStatusState {
  const SyncStatusState({
    required this.isConfigured,
    required this.isOnline,
    required this.pendingItems,
    required this.statusLabel,
  });

  final bool isConfigured;
  final bool isOnline;
  final int pendingItems;
  final String statusLabel;

  SyncStatusState copyWith({
    bool? isConfigured,
    bool? isOnline,
    int? pendingItems,
    String? statusLabel,
  }) {
    return SyncStatusState(
      isConfigured: isConfigured ?? this.isConfigured,
      isOnline: isOnline ?? this.isOnline,
      pendingItems: pendingItems ?? this.pendingItems,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }
}

class SyncStatusController extends StateNotifier<SyncStatusState> {
  SyncStatusController()
    : super(
        SyncStatusState(
          isConfigured: AppEnvironment.hasSupabaseConfig,
          isOnline: false,
          pendingItems: 0,
          statusLabel: AppEnvironment.hasSupabaseConfig
              ? 'Esperando verificacion de red'
              : 'Falta configurar Supabase',
        ),
      ) {
    _bootstrap();
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _bootstrap() async {
    final current = await Connectivity().checkConnectivity();
    _updateOnlineState(current);

    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateOnlineState,
    );
  }

  void _updateOnlineState(List<ConnectivityResult> result) {
    final online = result.any((item) => item != ConnectivityResult.none);
    final label = !state.isConfigured
        ? 'Falta configurar Supabase'
        : online
        ? 'Listo para sincronizar'
        : 'Sin conexion, modo offline';

    state = state.copyWith(isOnline: online, statusLabel: label);
  }

  Future<void> simulateSync() async {
    state = state.copyWith(statusLabel: 'Sincronizando...', pendingItems: 0);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(
      statusLabel: state.isConfigured
          ? (state.isOnline
                ? 'Sincronizacion base lista'
                : 'Sin conexion, modo offline')
          : 'Falta configurar Supabase',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatusState>((ref) {
      return SyncStatusController();
    });
