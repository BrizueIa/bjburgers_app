import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_settings_store.dart';

class AdminModeState {
  const AdminModeState({required this.pin, required this.enabled});

  final String pin;
  final bool enabled;

  bool verifyPin(String value) => pin == value;

  AdminModeState copyWith({String? pin, bool? enabled}) {
    return AdminModeState(
      pin: pin ?? this.pin,
      enabled: enabled ?? this.enabled,
    );
  }
}

class AdminModeController extends StateNotifier<AdminModeState> {
  AdminModeController(this._ref) : super(_buildState(_ref));

  final Ref _ref;

  static AdminModeState _buildState(Ref ref) {
    final snapshot = ref.read(localSettingsStoreProvider).read();
    return AdminModeState(
      pin: snapshot.adminPin,
      enabled: snapshot.adminModeEnabled,
    );
  }

  Future<bool> enableWithPin(String pin) async {
    if (!state.verifyPin(pin)) {
      return false;
    }

    state = state.copyWith(enabled: true);
    await _ref.read(localSettingsStoreProvider).saveAdminModeEnabled(true);
    return true;
  }

  Future<void> disable() async {
    state = state.copyWith(enabled: false);
    await _ref.read(localSettingsStoreProvider).saveAdminModeEnabled(false);
  }

  void reload() {
    state = _buildState(_ref);
  }
}

final adminModeProvider =
    StateNotifierProvider<AdminModeController, AdminModeState>((ref) {
      return AdminModeController(ref);
    });
