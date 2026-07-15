import 'dart:async';

import 'package:daylink_mobile/src/data/app_session_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'account disable event immediately clears credentials and signs out',
    () async {
      final signedOut = Completer<String>();
      var credentialsCleared = 0;
      final requests = <http.Request>[];
      final monitor = AppSessionMonitor(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        accessToken: () async => 'dlka_access-token',
        refreshAccessToken: () async => false,
        clearCredentials: () async => credentialsCleared++,
        onForcedSignOut: (reason) async => signedOut.complete(reason),
        reconnectDelay: Duration.zero,
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            'event: ready\ndata: {}\n\n'
            'event: session_revoked\ndata: {"reason":"account_disabled"}\n\n',
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );

      monitor.start();

      expect(
        await signedOut.future.timeout(const Duration(seconds: 1)),
        'account_disabled',
      );
      expect(credentialsCleared, 1);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/sync/events');
      expect(
        requests.single.headers['authorization'],
        'Bearer dlka_access-token',
      );
      await monitor.close();
    },
  );

  test(
    'unauthorized stream signs out only after refresh is rejected',
    () async {
      final signedOut = Completer<String>();
      var refreshes = 0;
      var credentialsCleared = 0;
      final monitor = AppSessionMonitor(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        accessToken: () async => 'dlka_expired-access',
        refreshAccessToken: () async {
          refreshes++;
          return false;
        },
        clearCredentials: () async => credentialsCleared++,
        onForcedSignOut: (reason) async => signedOut.complete(reason),
        reconnectDelay: Duration.zero,
        httpClient: MockClient((_) async => http.Response('{}', 401)),
      );

      monitor.start();

      expect(
        await signedOut.future.timeout(const Duration(seconds: 1)),
        'session_revoked',
      );
      expect(refreshes, 1);
      expect(credentialsCleared, 1);
      await monitor.close();
    },
  );

  test('untrusted revocation reason is reduced to a safe value', () async {
    final signedOut = Completer<String>();
    final monitor = AppSessionMonitor(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      accessToken: () async => 'dlka_access-token',
      refreshAccessToken: () async => false,
      clearCredentials: () async {},
      onForcedSignOut: (reason) async => signedOut.complete(reason),
      reconnectDelay: Duration.zero,
      httpClient: MockClient(
        (_) async => http.Response(
          'event: session_revoked\ndata: {"reason":"injected"}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );

    monitor.start();

    expect(
      await signedOut.future.timeout(const Duration(seconds: 1)),
      'session_revoked',
    );
    await monitor.close();
  });

  test('foreground reconciliation rejects a disabled session', () async {
    final signedOut = Completer<String>();
    var refreshes = 0;
    var credentialsCleared = 0;
    final monitor = AppSessionMonitor(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      accessToken: () async => 'dlka_access-token',
      refreshAccessToken: () async {
        refreshes++;
        return false;
      },
      clearCredentials: () async => credentialsCleared++,
      onForcedSignOut: (reason) async => signedOut.complete(reason),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/auth/session');
        return http.Response('{}', 401);
      }),
    );

    await monitor.reconcile();

    expect(await signedOut.future, 'session_revoked');
    expect(refreshes, 1);
    expect(credentialsCleared, 1);
    await monitor.close();
  });
}
