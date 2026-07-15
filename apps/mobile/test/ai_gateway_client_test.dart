import 'dart:convert';

import 'package:daylink_mobile/src/data/ai_gateway_client.dart';
import 'package:daylink_mobile/src/domain/ai/ai_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads both AI modes without receiving the upstream API key', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer dlka_app-access');
      switch (request.url.path) {
        case '/api/app/ai-settings':
          return http.Response(
            jsonEncode({
              'provider': {
                'id': 'provider-1',
                'name': 'Daylink AI',
                'kind': 'daylinkGateway',
                'baseUrl': 'https://daylink.example/api',
                'textModel': 'gpt-5.3-codex',
                'imageModel': 'gpt-image-1.5',
                'enabled': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        case '/api/app/ai-entitlement':
          return http.Response(
            jsonEncode({
              'entitlement': {
                'active': true,
                'plan': 'pro',
                'cardType': 'month',
                'expiresAt': '2026-08-15T00:00:00Z',
                'weeklyUsed': 8,
                'weeklyLimit': 100,
                'weeklyResetsAt': '2026-07-20T00:00:00Z',
                'monthlyUsed': 30,
                'monthlyLimit': 400,
                'monthlyResetsAt': '2026-08-01T00:00:00Z',
                'supportedModes': ['local_ai', 'ssh_agent'],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        case '/api/app/ai-remote-token':
          return http.Response(
            jsonEncode({
              'gateway': {
                'baseUrl': 'https://daylink.example/v1',
                'token': 'dlkc_short-lived',
                'model': 'gpt-5.3-codex',
                'expiresAt': '2026-07-15T12:00:00Z',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
      }
      return http.Response('{}', 404);
    });
    final client = AiGatewayClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      mobileToken: 'dlka_app-access',
      httpClient: httpClient,
    );

    final local = await client.localConfiguration();
    final entitlement = await client.entitlement();
    final remote = await client.createRemoteCredential();

    expect(local.provider.kind, AiProviderKind.daylinkGateway);
    expect(local.provider.imageModel, 'gpt-image-1.5');
    expect(local.accessToken, 'dlka_app-access');
    expect(entitlement.plan, 'pro');
    expect(entitlement.supportedModes, [
      AiExecutionMode.localAI,
      AiExecutionMode.sshAgent,
    ]);
    expect(remote.token, 'dlkc_short-lived');
    expect(remote.baseUrl.toString(), 'https://daylink.example/v1');
    expect(requests.last.method, 'POST');
    expect(requests.last.body, '{}');
    client.close();
  });
}
