import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceStore {
  static const _credentialKey = 'bj_operator_credential';
  static const _deviceNameKey = 'bj_operator_device_name';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> credential() => _storage.read(key: _credentialKey);
  Future<String?> deviceName() => _storage.read(key: _deviceNameKey);
  Future<void> save({
    required String credential,
    required String deviceName,
  }) async {
    await _storage.write(key: _credentialKey, value: credential);
    await _storage.write(key: _deviceNameKey, value: deviceName);
  }

  Future<void> clear() async {
    await _storage.delete(key: _credentialKey);
    await _storage.delete(key: _deviceNameKey);
  }
}
