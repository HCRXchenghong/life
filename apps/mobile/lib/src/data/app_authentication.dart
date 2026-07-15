import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _maximumAuthResponseBytes = 64 << 10;

abstract interface class AppAuthentication {
  Uri get apiBaseUri;

  Future<AppSessionCredentials?> restore();
  Future<AppSessionCredentials> login({
    required String username,
    required String password,
    required String deviceName,
  });
  Future<String?> accessToken();
  Future<bool> refresh();
  Future<void> clear();
  void close();
}

abstract interface class AppCredentialStore {
  Future<AppSessionCredentials?> read();
  Future<void> write(AppSessionCredentials credentials);
  Future<void> clear();
}

class SecureAppCredentialStore implements AppCredentialStore {
  SecureAppCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'daylink_auth',
              migrateWithBackup: true,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  static const _key = 'daylink.auth.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<AppSessionCredentials?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return AppSessionCredentials.fromJson(decoded);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AppSessionCredentials credentials) =>
      _storage.write(key: _key, value: jsonEncode(credentials.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class AppSessionCredentials {
  const AppSessionCredentials({
    required this.accountId,
    required this.username,
    required this.passwordChangeRequired,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  final String accountId;
  final String username;
  final bool passwordChangeRequired;
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  factory AppSessionCredentials.fromJson(Map<String, Object?> value) {
    final accountId = _requiredString(value, 'accountId', 36);
    if (!_uuidPattern.hasMatch(accountId)) throw const FormatException();
    final username = _requiredString(value, 'username', 32);
    final accessToken = _requiredToken(value, 'accessToken', 'dlka_');
    final refreshToken = _requiredToken(value, 'refreshToken', 'dlkr_');
    return AppSessionCredentials(
      accountId: accountId,
      username: username,
      passwordChangeRequired: _requiredBool(value, 'passwordChangeRequired'),
      accessToken: accessToken,
      accessExpiresAt: _requiredDate(value, 'accessExpiresAt'),
      refreshToken: refreshToken,
      refreshExpiresAt: _requiredDate(value, 'refreshExpiresAt'),
    );
  }

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'username': username,
    'passwordChangeRequired': passwordChangeRequired,
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt.toUtc().toIso8601String(),
  };

  AppSessionCredentials withTokens(Map<String, Object?> tokens) =>
      AppSessionCredentials(
        accountId: accountId,
        username: username,
        passwordChangeRequired: passwordChangeRequired,
        accessToken: _requiredToken(tokens, 'accessToken', 'dlka_'),
        accessExpiresAt: _requiredDate(tokens, 'accessExpiresAt'),
        refreshToken: _requiredToken(tokens, 'refreshToken', 'dlkr_'),
        refreshExpiresAt: _requiredDate(tokens, 'refreshExpiresAt'),
      );
}

class AppAuthenticationException implements Exception {
  const AppAuthenticationException(
    this.message, {
    this.sessionRejected = false,
  });

  final String message;
  final bool sessionRejected;

  @override
  String toString() => message;
}

class AppAuthenticator implements AppAuthentication {
  AppAuthenticator({
    required Uri apiBaseUri,
    AppCredentialStore? credentialStore,
    http.Client? httpClient,
  }) : apiBaseUri = _validateApiBaseUri(apiBaseUri),
       _store = credentialStore ?? SecureAppCredentialStore(),
       _client = AppAuthClient(apiBaseUri: apiBaseUri, httpClient: httpClient);

  @override
  final Uri apiBaseUri;
  final AppCredentialStore _store;
  final AppAuthClient _client;
  AppSessionCredentials? _current;
  Future<bool>? _refreshing;

  @override
  Future<AppSessionCredentials?> restore() async {
    final credentials = await _store.read();
    if (credentials == null) return null;
    if (!credentials.refreshExpiresAt.isAfter(DateTime.now().toUtc())) {
      await clear();
      return null;
    }
    _current = credentials;
    return credentials;
  }

  @override
  Future<AppSessionCredentials> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final credentials = await _client.login(
      username: username,
      password: password,
      deviceName: deviceName,
    );
    await _store.write(credentials);
    _current = credentials;
    return credentials;
  }

  @override
  Future<String?> accessToken() async {
    final current = _current ?? await _store.read();
    _current = current;
    return current?.accessToken;
  }

  @override
  Future<bool> refresh() {
    final active = _refreshing;
    if (active != null) return active;
    final future = _refreshOnce();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<bool> _refreshOnce() async {
    final current = _current ?? await _store.read();
    if (current == null ||
        !current.refreshExpiresAt.isAfter(DateTime.now().toUtc())) {
      await clear();
      return false;
    }
    try {
      final refreshed = await _client.refresh(current);
      await _store.write(refreshed);
      _current = refreshed;
      return true;
    } on AppAuthenticationException catch (error) {
      if (error.sessionRejected) await clear();
      return false;
    }
  }

  @override
  Future<void> clear() async {
    _current = null;
    await _store.clear();
  }

  @override
  void close() => _client.close();
}

class AppAuthClient {
  AppAuthClient({required Uri apiBaseUri, http.Client? httpClient})
    : _apiBaseUri = _validateApiBaseUri(apiBaseUri),
      _http = httpClient ?? http.Client();

  final Uri _apiBaseUri;
  final http.Client _http;

  Future<AppSessionCredentials> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    username = username.trim();
    deviceName = deviceName.trim();
    if (username.isEmpty ||
        username.length > 32 ||
        password.isEmpty ||
        password.length > 128 ||
        deviceName.isEmpty ||
        deviceName.length > 80) {
      throw const AppAuthenticationException('请输入有效的账号和密码');
    }
    final result = await _post('app/auth/login', {
      'username': username,
      'password': password,
      'deviceName': deviceName,
    });
    final account = _requiredMap(result, 'account');
    final tokens = _requiredMap(result, 'tokens');
    return AppSessionCredentials.fromJson({
      'accountId': account['id'],
      'username': account['username'],
      'passwordChangeRequired': account['passwordChangeRequired'],
      ...tokens,
    });
  }

  Future<AppSessionCredentials> refresh(AppSessionCredentials current) async {
    final result = await _post('app/auth/refresh', {
      'refreshToken': current.refreshToken,
    });
    return current.withTokens(_requiredMap(result, 'tokens'));
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final request = http.Request('POST', _apiBaseUri.resolve(path))
        ..headers.addAll({
          'accept': 'application/json',
          'content-type': 'application/json',
        })
        ..body = jsonEncode(body);
      final response = await _http
          .send(request)
          .timeout(const Duration(seconds: 20));
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > _maximumAuthResponseBytes) {
          throw const FormatException();
        }
        bytes.add(chunk);
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on Object {
        throw const FormatException();
      }
      if (decoded is! Map<String, Object?>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final envelope = decoded['error'];
        final message = envelope is Map<String, Object?>
            ? envelope['message']
            : null;
        throw AppAuthenticationException(
          message is String && message.isNotEmpty && message.length <= 200
              ? message
              : '登录失败，请稍后重试',
          sessionRejected: response.statusCode == 401,
        );
      }
      return decoded;
    } on AppAuthenticationException {
      rethrow;
    } on TimeoutException {
      throw const AppAuthenticationException('连接超时，请检查网络后重试');
    } on http.ClientException {
      throw const AppAuthenticationException('无法连接 Daylink 服务');
    } on FormatException {
      throw const AppAuthenticationException('Daylink 服务返回异常');
    }
  }

  void close() => _http.close();
}

Uri _validateApiBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.query.isNotEmpty ||
      value.fragment.isNotEmpty) {
    throw ArgumentError(
      'App API must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  return value.path.endsWith('/')
      ? value
      : value.replace(path: '${value.path}/');
}

Map<String, Object?> _requiredMap(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! Map<String, Object?>) throw const FormatException();
  return value;
}

String _requiredString(Map<String, Object?> map, String key, int maximum) {
  final value = map[key];
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.contains(RegExp(r'[\r\n\x00]'))) {
    throw const FormatException();
  }
  return value;
}

String _requiredToken(Map<String, Object?> map, String key, String prefix) {
  final value = _requiredString(map, key, 256);
  if (!value.startsWith(prefix) || value.length < 32) {
    throw const FormatException();
  }
  return value;
}

bool _requiredBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) throw const FormatException();
  return value;
}

DateTime _requiredDate(Map<String, Object?> map, String key) {
  final value = _requiredString(map, key, 64);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException();
  return parsed.toUtc();
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
