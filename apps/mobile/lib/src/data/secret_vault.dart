import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<void> write(String reference, String secret);
  Future<String?> read(String reference);
  Future<void> delete(String reference);
}

class SecretVault implements SecretStore {
  SecretVault({required String accountId, FlutterSecureStorage? storage})
    : _accountId = _validatedAccountId(accountId),
      _storage =
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
  final String _accountId;
  static const _prefix = 'daylink.secret.v1.';

  String _key(String reference) {
    if (reference.isEmpty ||
        reference.length > 200 ||
        reference.contains(RegExp(r'[\r\n\x00]'))) {
      throw ArgumentError('Secret reference is invalid');
    }
    return '$_prefix$_accountId.$reference';
  }

  @override
  Future<void> write(String reference, String secret) {
    if (secret.isEmpty) throw ArgumentError('Secret value must be non-empty');
    return _storage.write(key: _key(reference), value: secret);
  }

  @override
  Future<String?> read(String reference) => _storage.read(key: _key(reference));

  @override
  Future<void> delete(String reference) =>
      _storage.delete(key: _key(reference));
}

String _validatedAccountId(String value) {
  final normalized = value.toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError.value(value, 'accountId', 'Invalid account ID');
  }
  return normalized;
}
