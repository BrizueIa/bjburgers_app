import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

class LocalSettingsSnapshot {
  const LocalSettingsSnapshot({
    required this.businessName,
    required this.digitalMenuUrl,
    required this.adminPin,
    required this.adminModeEnabled,
    required this.stockTrackingEnabled,
    required this.settingsUpdatedAt,
    required this.lastSyncLabel,
    this.remoteSettingsId,
  });

  final String businessName;
  final String digitalMenuUrl;
  final String adminPin;
  final bool adminModeEnabled;
  final bool stockTrackingEnabled;
  final DateTime settingsUpdatedAt;
  final String lastSyncLabel;
  final String? remoteSettingsId;
}

class LocalSettingsStore {
  LocalSettingsStore(this._preferences);

  static const businessNameKey = 'business_name';
  static const digitalMenuUrlKey = 'digital_menu_url';
  static const adminPinKey = 'admin_pin';
  static const adminModeEnabledKey = 'admin_mode_enabled';
  static const stockTrackingEnabledKey = 'stock_tracking_enabled';
  static const settingsUpdatedAtKey = 'settings_updated_at';
  static const lastSyncLabelKey = 'last_sync_label';
  static const remoteSettingsIdKey = 'remote_settings_id';

  final SharedPreferences _preferences;

  LocalSettingsSnapshot read() {
    return LocalSettingsSnapshot(
      businessName: _preferences.getString(businessNameKey) ?? 'BJ Burguers',
      digitalMenuUrl: _preferences.getString(digitalMenuUrlKey) ?? '',
      adminPin: _preferences.getString(adminPinKey) ?? '1234',
      adminModeEnabled: _preferences.getBool(adminModeEnabledKey) ?? false,
      stockTrackingEnabled:
          _preferences.getBool(stockTrackingEnabledKey) ?? false,
      settingsUpdatedAt:
          DateTime.tryParse(
            _preferences.getString(settingsUpdatedAtKey) ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSyncLabel:
          _preferences.getString(lastSyncLabelKey) ??
          'Pendiente de primera sincronizacion',
      remoteSettingsId: _preferences.getString(remoteSettingsIdKey),
    );
  }

  Future<void> saveBusinessName(String value) async {
    await _preferences.setString(businessNameKey, value);
    await _touchSettingsUpdatedAt();
  }

  Future<void> saveDigitalMenuUrl(String value) async {
    await _preferences.setString(digitalMenuUrlKey, value);
    await _touchSettingsUpdatedAt();
  }

  Future<void> saveAdminPin(String value) async {
    await _preferences.setString(adminPinKey, value);
    await _touchSettingsUpdatedAt();
  }

  Future<void> saveAdminModeEnabled(bool value) async {
    await _preferences.setBool(adminModeEnabledKey, value);
    await _touchSettingsUpdatedAt();
  }

  Future<void> saveStockTrackingEnabled(bool value) async {
    await _preferences.setBool(stockTrackingEnabledKey, value);
    await _touchSettingsUpdatedAt();
  }

  Future<void> setLastSyncNow() async {
    final label = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    await _preferences.setString(lastSyncLabelKey, label);
  }

  Future<void> setRemoteSettingsId(String id) async {
    await _preferences.setString(remoteSettingsIdKey, id);
  }

  Future<void> replaceFromRemote({
    required String businessName,
    required String digitalMenuUrl,
    required String adminPin,
    required bool adminModeEnabled,
    required bool stockTrackingEnabled,
    required DateTime updatedAt,
    required String remoteSettingsId,
  }) async {
    await _preferences.setString(businessNameKey, businessName);
    await _preferences.setString(digitalMenuUrlKey, digitalMenuUrl);
    await _preferences.setString(adminPinKey, adminPin);
    await _preferences.setBool(adminModeEnabledKey, adminModeEnabled);
    await _preferences.setBool(stockTrackingEnabledKey, stockTrackingEnabled);
    await _preferences.setString(
      settingsUpdatedAtKey,
      updatedAt.toIso8601String(),
    );
    await _preferences.setString(remoteSettingsIdKey, remoteSettingsId);
  }

  Future<void> _touchSettingsUpdatedAt() async {
    await _preferences.setString(
      settingsUpdatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}

final localSettingsStoreProvider = Provider<LocalSettingsStore>((ref) {
  return LocalSettingsStore(ref.watch(sharedPreferencesProvider));
});
