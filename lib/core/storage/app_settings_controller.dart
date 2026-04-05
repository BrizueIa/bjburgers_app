import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'local_settings_store.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.businessName,
    required this.digitalMenuUrl,
    required this.lastSyncLabel,
  });

  final String businessName;
  final String digitalMenuUrl;
  final String lastSyncLabel;

  bool get hasSupabaseConfig => AppEnvironment.hasSupabaseConfig;

  AppSettingsState copyWith({
    String? businessName,
    String? digitalMenuUrl,
    String? lastSyncLabel,
  }) {
    return AppSettingsState(
      businessName: businessName ?? this.businessName,
      digitalMenuUrl: digitalMenuUrl ?? this.digitalMenuUrl,
      lastSyncLabel: lastSyncLabel ?? this.lastSyncLabel,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController(this._ref) : super(_buildState(_ref));

  final Ref _ref;

  static AppSettingsState _buildState(Ref ref) {
    final snapshot = ref.read(localSettingsStoreProvider).read();
    return AppSettingsState(
      businessName: snapshot.businessName,
      digitalMenuUrl: snapshot.digitalMenuUrl,
      lastSyncLabel: snapshot.lastSyncLabel,
    );
  }

  Future<void> updateBusinessName(String value) async {
    state = state.copyWith(businessName: value);
    await _ref.read(localSettingsStoreProvider).saveBusinessName(value);
  }

  Future<void> updateDigitalMenuUrl(String value) async {
    state = state.copyWith(digitalMenuUrl: value);
    await _ref.read(localSettingsStoreProvider).saveDigitalMenuUrl(value);
  }

  Future<void> recordSyncAttempt() async {
    await _ref.read(localSettingsStoreProvider).setLastSyncNow();
    reload();
  }

  void reload() {
    state = _buildState(_ref);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
      return AppSettingsController(ref);
    });
