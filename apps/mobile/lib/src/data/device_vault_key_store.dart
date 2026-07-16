import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DeviceVaultKeyStore {
  Future<String?> read(String accountId);
  Future<void> write(String accountId, String encodedKey);
  Future<void> delete(String accountId);
}

class PlatformDeviceVaultKeyStore implements DeviceVaultKeyStore {
  PlatformDeviceVaultKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'daylink_e2ee_device_keys',
              migrateWithBackup: false,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  static const _prefix = 'daylink.e2ee.device-vault-key.v1.';
  final FlutterSecureStorage _storage;

  String _key(String accountId) {
    final normalized = accountId.toLowerCase();
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(normalized)) {
      throw ArgumentError('Invalid account ID');
    }
    return '$_prefix$normalized';
  }

  @override
  Future<String?> read(String accountId) => _storage.read(key: _key(accountId));

  @override
  Future<void> write(String accountId, String encodedKey) {
    if (encodedKey.isEmpty || encodedKey.length > 128) {
      throw ArgumentError('Invalid encoded device key');
    }
    return _storage.write(key: _key(accountId), value: encodedKey);
  }

  @override
  Future<void> delete(String accountId) =>
      _storage.delete(key: _key(accountId));
}
