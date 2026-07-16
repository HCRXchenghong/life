import 'dart:convert';

import 'package:daylink_mobile/src/data/data_sync_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('downloads and validates account-scoped encrypted changes', () async {
    final client = DataSyncClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/sync/changes');
        expect(request.url.queryParameters['cursor'], '0');
        expect(request.headers['authorization'], 'Bearer dlka_${_repeat('a')}');
        return http.Response(
          jsonEncode({
            'changes': [
              {
                'cursor': 1,
                'collection': 'schedule_events',
                'id': '123e4567-e89b-12d3-a456-426614174001',
                'operationId': '123e4567-e89b-12d3-a456-426614174002',
                'deviceId': '123e4567-e89b-12d3-a456-426614174003',
                'revision': 1,
                'deleted': false,
                'ciphertext': base64Encode(utf8.encode('opaque-content')),
                'nonce': base64Encode(List<int>.filled(12, 7)),
                'keyVersion': 1,
                'clientUpdatedAt': '2030-01-01T00:00:00Z',
                'serverUpdatedAt': '2030-01-01T00:00:01Z',
              },
            ],
            'cursor': 1,
            'hasMore': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final page = await client.changes(
      accessToken: 'dlka_${_repeat('a')}',
      cursor: 0,
    );

    expect(page.cursor, 1);
    expect(page.hasMore, isFalse);
    expect(page.changes.single.collection, 'schedule_events');
    expect(utf8.decode(page.changes.single.ciphertext!), 'opaque-content');
    client.close();
  });

  test('rejects malformed encrypted metadata before persistence', () async {
    final client = DataSyncClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'changes': [
              {
                'cursor': 1,
                'collection': '../other_account',
                'id': '123e4567-e89b-12d3-a456-426614174001',
                'operationId': '123e4567-e89b-12d3-a456-426614174002',
                'deviceId': '123e4567-e89b-12d3-a456-426614174003',
                'revision': 1,
                'deleted': true,
                'clientUpdatedAt': '2030-01-01T00:00:00Z',
                'serverUpdatedAt': '2030-01-01T00:00:01Z',
              },
            ],
            'cursor': 1,
            'hasMore': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.changes(accessToken: 'dlka_${_repeat('a')}', cursor: 0),
      throwsA(isA<DataSyncClientException>()),
    );
    client.close();
  });

  test('marks unauthorized sync without exposing response bodies', () async {
    final client = DataSyncClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient(
        (_) async => http.Response('secret upstream body', 401),
      ),
    );

    await expectLater(
      client.changes(accessToken: 'dlka_${_repeat('a')}', cursor: 0),
      throwsA(
        isA<DataSyncClientException>().having(
          (error) => error.sessionRejected,
          'sessionRejected',
          isTrue,
        ),
      ),
    );
    client.close();
  });
}

String _repeat(String value) => List.filled(40, value).join();
