import 'dart:convert';

import 'package:daylink_mobile/src/data/app_authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('App auth client uses the protected App login contract', () async {
    late Map<String, Object?> requestBody;
    final client = AppAuthClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/auth/login');
        expect(request.headers['content-type'], 'application/json');
        requestBody = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode({
            'account': {
              'id': '123e4567-e89b-12d3-a456-426614174000',
              'username': 'alice',
              'passwordChangeRequired': true,
            },
            'tokens': {
              'accessToken': 'dlka_${_repeat('a')}',
              'accessExpiresAt': '2030-01-01T00:00:00Z',
              'refreshToken': 'dlkr_${_repeat('b')}',
              'refreshExpiresAt': '2031-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await client.login(
      username: ' alice ',
      password: 'secret-value',
      deviceName: 'Daylink iOS',
    );

    expect(requestBody['username'], 'alice');
    expect(requestBody['password'], 'secret-value');
    expect(session.accountId, '123e4567-e89b-12d3-a456-426614174000');
    expect(session.passwordChangeRequired, isTrue);
    client.close();
  });

  test('App auth client rejects non-TLS non-loopback origins', () {
    expect(
      () => AppAuthClient(apiBaseUri: Uri.parse('http://daylink.example/api/')),
      throwsArgumentError,
    );
  });

  test('refresh rotates tokens without changing account identity', () async {
    final current = AppSessionCredentials(
      accountId: '123e4567-e89b-12d3-a456-426614174000',
      username: 'alice',
      passwordChangeRequired: false,
      accessToken: 'dlka_${_repeat('a')}',
      accessExpiresAt: DateTime.utc(2029),
      refreshToken: 'dlkr_${_repeat('b')}',
      refreshExpiresAt: DateTime.utc(2030),
    );
    final client = AppAuthClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'tokens': {
              'accessToken': 'dlka_${_repeat('c')}',
              'accessExpiresAt': '2031-01-01T00:00:00Z',
              'refreshToken': 'dlkr_${_repeat('d')}',
              'refreshExpiresAt': '2032-01-01T00:00:00Z',
            },
          }),
          200,
        ),
      ),
    );

    final refreshed = await client.refresh(current);

    expect(refreshed.accountId, current.accountId);
    expect(refreshed.username, current.username);
    expect(refreshed.accessToken, startsWith('dlka_c'));
    expect(refreshed.refreshToken, startsWith('dlkr_d'));
    client.close();
  });

  test(
    'password change uses bearer auth and rotates the whole session',
    () async {
      late http.Request captured;
      final current = _session(passwordChangeRequired: true);
      final client = AppAuthClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'account': {
                'id': current.accountId,
                'username': current.username,
                'passwordChangeRequired': false,
              },
              'tokens': {
                'accessToken': 'dlka_${_repeat('c')}',
                'accessExpiresAt': '2031-01-01T00:00:00Z',
                'refreshToken': 'dlkr_${_repeat('d')}',
                'refreshExpiresAt': '2032-01-01T00:00:00Z',
              },
            }),
            200,
          );
        }),
      );

      final changed = await client.changePassword(
        current,
        currentPassword: 'Temporary1!',
        newPassword: 'Replacement2!',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/app/auth/password');
      expect(
        captured.headers['authorization'],
        'Bearer ${current.accessToken}',
      );
      expect(jsonDecode(captured.body), {
        'currentPassword': 'Temporary1!',
        'newPassword': 'Replacement2!',
      });
      expect(changed.passwordChangeRequired, isFalse);
      expect(changed.accessToken, startsWith('dlka_c'));
      expect(changed.refreshToken, startsWith('dlkr_d'));
      client.close();
    },
  );

  test(
    'logout uses DELETE and clears local credentials on network error',
    () async {
      late http.BaseRequest captured;
      final store = _MemoryCredentialStore(
        _session(passwordChangeRequired: false),
      );
      final authenticator = AppAuthenticator(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        credentialStore: store,
        httpClient: MockClient((request) async {
          captured = request;
          throw http.ClientException('offline');
        }),
      );
      await authenticator.restore();

      await authenticator.logout();

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/api/app/auth/session');
      expect(captured.headers['authorization'], startsWith('Bearer dlka_'));
      expect(store.value, isNull);
      expect(await authenticator.accessToken(), isNull);
      authenticator.close();
    },
  );

  test(
    'device session client lists devices and revokes only other sessions',
    () async {
      final requests = <http.Request>[];
      final current = _session(passwordChangeRequired: false);
      final client = AppAuthClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'devices': [
                  {
                    'id': '123e4567-e89b-12d3-a456-426614174001',
                    'name': 'Daylink iPhone',
                    'current': true,
                    'trusted': true,
                    'lastSeenAt': '2030-07-16T01:41:00Z',
                    'createdAt': '2030-07-01T01:41:00Z',
                  },
                  {
                    'id': '123e4567-e89b-12d3-a456-426614174002',
                    'name': 'Daylink Android',
                    'current': false,
                    'trusted': true,
                    'lastSeenAt': '2030-07-15T01:41:00Z',
                    'createdAt': '2030-07-02T01:41:00Z',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith(
            '/123e4567-e89b-12d3-a456-426614174002',
          )) {
            return http.Response(jsonEncode({'revoked': true}), 200);
          }
          return http.Response(jsonEncode({'revoked': 1}), 200);
        }),
      );

      final devices = await client.loadDeviceSessions(current);
      await client.revokeDeviceSession(current, devices.last.id);
      await client.revokeOtherDeviceSessions(current);

      expect(devices, hasLength(2));
      expect(devices.first.name, 'Daylink iPhone');
      expect(devices.first.current, isTrue);
      expect(devices, everyElement(isA<AppDeviceSession>()));
      expect(devices.every((device) => device.trusted), isTrue);
      expect(requests.map((request) => request.method), [
        'GET',
        'DELETE',
        'DELETE',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/app/auth/devices',
        '/api/app/auth/devices/123e4567-e89b-12d3-a456-426614174002',
        '/api/app/auth/devices',
      ]);
      expect(
        requests.map((request) => request.headers['authorization']),
        everyElement('Bearer ${current.accessToken}'),
      );
      client.close();
    },
  );

  test(
    'device session client rejects a response without one current device',
    () async {
      final current = _session(passwordChangeRequired: false);
      final client = AppAuthClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'devices': [
                {
                  'id': '123e4567-e89b-12d3-a456-426614174002',
                  'name': 'Daylink Android',
                  'current': false,
                  'trusted': false,
                  'lastSeenAt': '2030-07-15T01:41:00Z',
                  'createdAt': '2030-07-02T01:41:00Z',
                },
              ],
            }),
            200,
          ),
        ),
      );

      await expectLater(
        client.loadDeviceSessions(current),
        throwsA(isA<AppAuthenticationException>()),
      );
      client.close();
    },
  );

  test('password validation matches the server complexity policy', () {
    expect(validateStrongAppPassword('Replacement2!'), isNull);
    expect(validateStrongAppPassword('replacement2!'), contains('大小写'));
    expect(validateStrongAppPassword('Short2!'), contains('12'));
  });
}

String _repeat(String value) => List.filled(40, value).join();

AppSessionCredentials _session({required bool passwordChangeRequired}) =>
    AppSessionCredentials(
      accountId: '123e4567-e89b-12d3-a456-426614174000',
      username: 'alice',
      passwordChangeRequired: passwordChangeRequired,
      accessToken: 'dlka_${_repeat('a')}',
      accessExpiresAt: DateTime.utc(2029),
      refreshToken: 'dlkr_${_repeat('b')}',
      refreshExpiresAt: DateTime.utc(2030),
    );

class _MemoryCredentialStore implements AppCredentialStore {
  _MemoryCredentialStore(this.value);

  AppSessionCredentials? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AppSessionCredentials?> read() async => value;

  @override
  Future<void> write(AppSessionCredentials credentials) async =>
      value = credentials;
}
