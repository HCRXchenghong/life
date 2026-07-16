import 'dart:convert';

import 'package:daylink_mobile/src/data/device_approval_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const token = 'dlka_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final requestProof = List<int>.filled(32, 6);
  const requestId = '9b276a3e-b141-4d91-8dbf-0f217b62b071';

  test('strictly parses account-scoped pending device requests', () async {
    final now = DateTime.utc(2026, 7, 16, 12);
    final client = DeviceApprovalClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/sync/device-approvals');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'requests': [
              {
                'id': '9b276a3e-b141-4d91-8dbf-0f217b62b071',
                'deviceName': 'Daylink iPhone',
                'publicKey': base64Encode(List<int>.filled(32, 7)),
                'createdAt': now.toIso8601String(),
                'expiresAt': now
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final requests = await client.listPending(accessToken: token);
    expect(requests, hasLength(1));
    expect(requests.single.deviceName, 'Daylink iPhone');
    expect(requests.single.publicKey, everyElement(7));
    client.close();
  });

  test('uploads only the encrypted approval package', () async {
    final client = DeviceApprovalClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/sync/device-approvals/'
          '9b276a3e-b141-4d91-8dbf-0f217b62b071/approve',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body.keys, {
          'approverPublicKey',
          'nonce',
          'ciphertext',
          'keyVersion',
        });
        expect(base64Decode(body['ciphertext']! as String), hasLength(48));
        return http.Response(
          '{"approved":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.approve(
      accessToken: token,
      requestId: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
      decision: RemoteDeviceApprovalDecision(
        approverPublicKey: List<int>.filled(32, 2),
        nonce: List<int>.filled(12, 3),
        ciphertext: List<int>.filled(48, 4),
        keyVersion: 1,
      ),
    );
    client.close();
  });

  test(
    'creates, polls, consumes, and cancels with the private proof',
    () async {
      final now = DateTime.now().toUtc();
      final methods = <String>[];
      final client = DeviceApprovalClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'POST' &&
              request.url.path == '/api/sync/device-approvals') {
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(
              body['requestToken'],
              base64UrlEncode(requestProof).replaceAll('=', ''),
            );
            return http.Response(
              jsonEncode({
                'id': requestId,
                'status': 'pending',
                'expiresAt': now
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(
            request.headers['x-daylink-device-request'],
            base64UrlEncode(requestProof).replaceAll('=', ''),
          );
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': requestId,
                'status': 'approved',
                'deviceName': 'Daylink iPhone',
                'publicKey': base64Encode(List<int>.filled(32, 5)),
                'createdAt': now.toIso8601String(),
                'expiresAt': now
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
                'approverPublicKey': base64Encode(List<int>.filled(32, 7)),
                'nonce': base64Encode(List<int>.filled(12, 8)),
                'ciphertext': base64Encode(List<int>.filled(48, 9)),
                'keyVersion': 1,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await client.create(
          accessToken: token,
          requestId: requestId,
          requestToken: requestProof,
          publicKey: List<int>.filled(32, 5),
        ),
        now.add(const Duration(minutes: 10)),
      );
      final state = await client.loadStatus(
        accessToken: token,
        requestId: requestId,
        requestToken: requestProof,
      );
      expect(state.status, RemoteDeviceApprovalStatus.approved);
      expect(state.ciphertext, everyElement(9));
      await client.consume(
        accessToken: token,
        requestId: requestId,
        requestToken: requestProof,
      );
      await client.cancel(
        accessToken: token,
        requestId: requestId,
        requestToken: requestProof,
      );
      expect(methods, ['POST', 'GET', 'POST', 'DELETE']);
      client.close();
    },
  );

  test('rejects malformed or all-zero public keys', () async {
    for (final publicKey in [
      base64Encode(List<int>.filled(31, 7)),
      base64Encode(List<int>.filled(32, 0)),
    ]) {
      final client = DeviceApprovalClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'requests': [
                {
                  'id': '9b276a3e-b141-4d91-8dbf-0f217b62b071',
                  'deviceName': 'Daylink iPhone',
                  'publicKey': publicKey,
                  'createdAt': '2026-07-16T12:00:00Z',
                  'expiresAt': '2026-07-16T12:10:00Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        client.listPending(accessToken: token),
        throwsA(isA<DeviceApprovalClientException>()),
      );
      client.close();
    }
  });
}
