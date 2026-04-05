import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/shared_preferences_provider.dart';

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
  AdminModeController(this._ref)
    : super(
        AdminModeState(
          pin:
              _ref.read(sharedPreferencesProvider).getString(_pinKey) ?? '1234',
          enabled:
              _ref.read(sharedPreferencesProvider).getBool(_enabledKey) ??
              false,
        ),
      );

  static const _pinKey = 'admin_pin';
  static const _enabledKey = 'admin_mode_enabled';

  final Ref _ref;

  Future<void> updatePin(String pin) async {
    state = state.copyWith(pin: pin);
    await _ref.read(sharedPreferencesProvider).setString(_pinKey, pin);
  }

  Future<bool> enableWithPin(String pin) async {
    if (!state.verifyPin(pin)) {
      return false;
    }

    state = state.copyWith(enabled: true);
    await _ref.read(sharedPreferencesProvider).setBool(_enabledKey, true);
    return true;
  }

  Future<void> disable() async {
    state = state.copyWith(enabled: false);
    await _ref.read(sharedPreferencesProvider).setBool(_enabledKey, false);
  }
}

final adminModeProvider =
    StateNotifierProvider<AdminModeController, AdminModeState>((ref) {
      return AdminModeController(ref);
    });
