import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'app_sync_service.dart';

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
  SyncStatusController(this._ref)
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

  final Ref _ref;
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

  Future<String> synchronize() async {
    if (!state.isConfigured) {
      state = state.copyWith(statusLabel: 'Falta configurar Supabase');
      return state.statusLabel;
    }

    if (!state.isOnline) {
      state = state.copyWith(statusLabel: 'Sin conexion, modo offline');
      return state.statusLabel;
    }

    state = state.copyWith(statusLabel: 'Sincronizando...', pendingItems: 0);
    final result = await _ref.read(appSyncServiceProvider).synchronizeAll();
    state = state.copyWith(statusLabel: result.message);
    return result.message;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatusState>((ref) {
      return SyncStatusController(ref);
    });
