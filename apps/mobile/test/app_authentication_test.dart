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
}

String _repeat(String value) => List.filled(40, value).join();
