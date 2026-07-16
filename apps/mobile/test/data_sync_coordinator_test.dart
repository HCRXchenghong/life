import 'dart:convert';

import 'package:daylink_mobile/src/application/data_sync_coordinator.dart';
import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/data_sync_client.dart';
import 'package:daylink_mobile/src/data/data_sync_repository.dart';
import 'package:daylink_mobile/src/domain/sync/data_sync_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('refreshes once and persists every encrypted page', () async {
    final database = AppDatabase.inMemory();
    var token = 'dlka_${_repeat('a')}';
    var requests = 0;
    var refreshes = 0;
    final client = DataSyncClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response('', 401);
        expect(request.headers['authorization'], 'Bearer $token');
        final cursor = int.parse(request.url.queryParameters['cursor']!);
        return http.Response(
          jsonEncode({
            'changes': cursor == 0 ? [_change(1)] : [_change(2)],
            'cursor': cursor + 1,
            'hasMore': cursor == 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final coordinator = DataSyncCoordinator(
      repository: DataSyncRepository(database),
      client: client,
      accessToken: () async => token,
      refreshAccessToken: () async {
        refreshes++;
        token = 'dlka_${_repeat('b')}';
        return true;
      },
      encryptionStatus: () async => DataEncryptionStatus.unlocked,
    );

    final state = await coordinator.syncNow();

    expect(refreshes, 1);
    expect(requests, 3);
    expect(state.cachedChangeCount, 2);
    expect(state.encryptionStatus, DataEncryptionStatus.unlocked);
    expect(state.lastSyncedAt, isNotNull);
    coordinator.close();
    await database.close();
  });

  test('disabled automatic sync does not touch the network', () async {
    final database = AppDatabase.inMemory();
    final repository = DataSyncRepository(database);
    await repository.setAutoSyncEnabled(false);
    var requests = 0;
    final coordinator = DataSyncCoordinator(
      repository: repository,
      client: DataSyncClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }),
      ),
      accessToken: () async => 'dlka_${_repeat('a')}',
      refreshAccessToken: () async => false,
    );

    await coordinator.reconcile();

    expect(requests, 0);
    coordinator.close();
    await database.close();
  });
}

Map<String, Object?> _change(int cursor) => {
  'cursor': cursor,
  'collection': 'schedule_events',
  'id': '123e4567-e89b-12d3-a456-42661417400$cursor',
  'operationId': '223e4567-e89b-12d3-a456-42661417400$cursor',
  'deviceId': '323e4567-e89b-12d3-a456-426614174001',
  'revision': 1,
  'deleted': false,
  'ciphertext': base64Encode(utf8.encode('opaque-$cursor')),
  'nonce': base64Encode(List<int>.filled(12, cursor)),
  'keyVersion': 1,
  'clientUpdatedAt': '2030-01-01T00:00:00Z',
  'serverUpdatedAt': '2030-01-01T00:00:01Z',
};

String _repeat(String value) => List.filled(40, value).join();
