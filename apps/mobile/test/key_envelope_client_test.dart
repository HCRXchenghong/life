import 'dart:convert';
import 'dart:typed_data';

import 'package:daylink_mobile/src/data/key_envelope_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'dlka_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('loads and strictly validates a recovery envelope', () async {
    final client = KeyEnvelopeClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/sync/key-envelope');
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'exists': true,
            'keyVersion': 1,
            'algorithm': 'aes-256-gcm',
            'kdf': 'hkdf-sha256',
            'salt': base64Encode(List<int>.filled(32, 1)),
            'nonce': base64Encode(List<int>.filled(12, 2)),
            'ciphertext': base64Encode(List<int>.filled(48, 3)),
            'creatorDeviceId': '9b276a3e-b141-4d91-8dbf-0f217b62b071',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final envelope = await client.load(accessToken: token);
    expect(envelope, isNotNull);
    expect(envelope!.ciphertext, hasLength(48));
    client.close();
  });

  test(
    'rejects malformed envelope without exposing the response body',
    () async {
      final client = KeyEnvelopeClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'exists': true,
              'keyVersion': 1,
              'algorithm': 'aes-256-gcm',
              'kdf': 'hkdf-sha256',
              'salt': base64Encode(List<int>.filled(31, 1)),
              'nonce': base64Encode(List<int>.filled(12, 2)),
              'ciphertext': base64Encode(List<int>.filled(48, 3)),
              'creatorDeviceId': '9b276a3e-b141-4d91-8dbf-0f217b62b071',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.load(accessToken: token),
        throwsA(
          anyOf(isA<FormatException>(), isA<KeyEnvelopeClientException>()),
        ),
      );
      client.close();
    },
  );

  test('maps server conflict and session rejection to safe errors', () async {
    var status = 409;
    final client = KeyEnvelopeClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'secret-server-error'},
          }),
          status,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final envelope = KeyEnvelope(
      keyVersion: 1,
      algorithm: 'aes-256-gcm',
      kdf: 'hkdf-sha256',
      salt: Uint8List.fromList(List<int>.filled(32, 1)),
      nonce: Uint8List.fromList(List<int>.filled(12, 2)),
      ciphertext: Uint8List.fromList(List<int>.filled(48, 3)),
      creatorDeviceId: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
    );

    await expectLater(
      client.store(accessToken: token, envelope: envelope),
      throwsA(
        isA<KeyEnvelopeClientException>().having(
          (error) => error.conflict,
          'conflict',
          true,
        ),
      ),
    );
    status = 401;
    await expectLater(
      client.load(accessToken: token),
      throwsA(
        isA<KeyEnvelopeClientException>()
            .having((error) => error.sessionRejected, 'rejected', true)
            .having(
              (error) => error.toString().contains('secret-server-error'),
              'does not expose body',
              false,
            ),
      ),
    );
    client.close();
  });
}
