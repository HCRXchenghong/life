import 'dart:convert';

import 'package:daylink_mobile/src/data/artifact_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'artifact client authenticates and accepts only Office ZIP output',
    () async {
      late http.Request request;
      final client = ArtifactClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        mobileToken: 'dlka_test-access-token',
        httpClient: MockClient((incoming) async {
          request = incoming;
          return http.Response.bytes(
            const [0x50, 0x4b, 0x03, 0x04],
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            },
          );
        }),
      );

      final result = await client.generate({
        'kind': 'pptx',
        'title': '汇报',
        'slides': [
          {
            'title': '目标',
            'bullets': ['清晰'],
          },
        ],
      });

      expect(request.url.path, '/api/assistant/artifacts');
      expect(request.headers['authorization'], 'Bearer dlka_test-access-token');
      expect(jsonDecode(request.body)['kind'], 'pptx');
      expect(result.extension, 'pptx');
      client.close();
    },
  );
}
