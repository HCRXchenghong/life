import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<void> write(String reference, String secret);
  Future<String?> read(String reference);
  Future<void> delete(String reference);
}

class SecretVault implements SecretStore {
  SecretVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'daylink_vault',
              migrateWithBackup: true,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _prefix = 'daylink.secret.v1.';

  @override
  Future<void> write(String reference, String secret) {
    if (reference.isEmpty || secret.isEmpty) {
      throw ArgumentError('Secret reference and value must be non-empty');
    }
    return _storage.write(key: '$_prefix$reference', value: secret);
  }

  @override
  Future<String?> read(String reference) =>
      _storage.read(key: '$_prefix$reference');

  @override
  Future<void> delete(String reference) =>
      _storage.delete(key: '$_prefix$reference');
}
