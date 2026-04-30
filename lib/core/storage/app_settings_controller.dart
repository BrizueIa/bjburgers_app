import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'promo_config.dart';
import 'local_settings_store.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.businessName,
    required this.digitalMenuUrl,
    required this.stockTrackingEnabled,
    required this.promoConfigs,
    required this.lastSyncLabel,
  });

  final String businessName;
  final String digitalMenuUrl;
  final bool stockTrackingEnabled;
  final List<PromoConfig> promoConfigs;
  final String lastSyncLabel;

  bool get hasSupabaseConfig => AppEnvironment.hasSupabaseConfig;

  AppSettingsState copyWith({
    String? businessName,
    String? digitalMenuUrl,
    bool? stockTrackingEnabled,
    List<PromoConfig>? promoConfigs,
    String? lastSyncLabel,
  }) {
    return AppSettingsState(
      businessName: businessName ?? this.businessName,
      digitalMenuUrl: digitalMenuUrl ?? this.digitalMenuUrl,
      stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
      promoConfigs: promoConfigs ?? this.promoConfigs,
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
      stockTrackingEnabled: snapshot.stockTrackingEnabled,
      promoConfigs: snapshot.promoConfigs,
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

  Future<void> updateStockTrackingEnabled(bool value) async {
    state = state.copyWith(stockTrackingEnabled: value);
    await _ref.read(localSettingsStoreProvider).saveStockTrackingEnabled(value);
  }

  Future<void> updatePromoConfigs(List<PromoConfig> value) async {
    state = state.copyWith(promoConfigs: value);
    await _ref.read(localSettingsStoreProvider).savePromoConfigs(value);
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
