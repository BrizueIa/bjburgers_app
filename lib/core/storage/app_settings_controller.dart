import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/app_environment.dart';
import '../storage/shared_preferences_provider.dart';

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
  AppSettingsController(this._ref)
    : super(
        AppSettingsState(
          businessName:
              _ref.read(sharedPreferencesProvider).getString(_nameKey) ??
              'BJ Burguers',
          digitalMenuUrl:
              _ref.read(sharedPreferencesProvider).getString(_menuKey) ?? '',
          lastSyncLabel:
              _ref.read(sharedPreferencesProvider).getString(_lastSyncKey) ??
              'Pendiente de primera sincronizacion',
        ),
      );

  static const _nameKey = 'business_name';
  static const _menuKey = 'digital_menu_url';
  static const _lastSyncKey = 'last_sync_label';

  final Ref _ref;

  Future<void> updateBusinessName(String value) async {
    state = state.copyWith(businessName: value);
    await _ref.read(sharedPreferencesProvider).setString(_nameKey, value);
  }

  Future<void> updateDigitalMenuUrl(String value) async {
    state = state.copyWith(digitalMenuUrl: value);
    await _ref.read(sharedPreferencesProvider).setString(_menuKey, value);
  }

  Future<void> recordSyncAttempt() async {
    final label = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    state = state.copyWith(lastSyncLabel: label);
    await _ref.read(sharedPreferencesProvider).setString(_lastSyncKey, label);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
      return AppSettingsController(ref);
    });
