import 'dart:convert';
import 'dart:typed_data';

import 'package:daylink_mobile/src/domain/ai/ai_models.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_input_file.dart';
import 'package:daylink_mobile/src/domain/ai/openai_responses_client.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends real file bytes as Responses API input_file content', () async {
    Map<String, Object?>? requestBody;
    var rawRequestBody = '';
    final httpClient = MockClient((request) async {
      rawRequestBody = request.body;
      requestBody = jsonDecode(request.body) as Map<String, Object?>;
      return http.Response(
        jsonEncode({'id': 'response-1', 'output_text': '已读取真实文件'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = OpenAiResponsesClient(httpClient: httpClient);
    addTearDown(client.close);
    final registry = ToolRegistry(
      approvals: (_, _) async => ApprovalDecision.decline,
    );

    final result = await client.run(
      provider: AiProviderModel(
        id: 'provider-1',
        name: 'Responses',
        kind: AiProviderKind.openaiResponses,
        baseUrl: Uri.parse('https://api.example.test/v1'),
        textModel: 'test-model',
        secretRef: 'secret',
      ),
      apiKey: 'test-key',
      input: '读取并总结附件',
      files: [
        AssistantInputFile(
          filename: '真实资料.pdf',
          contentType: 'application/pdf',
          bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
        ),
      ],
      tools: registry,
    );

    final input = requestBody!['input']! as List<Object?>;
    final message = input.single as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final file = content.first as Map<String, Object?>;
    expect(file['type'], 'input_file');
    expect(file['filename'], '真实资料.pdf');
    expect(file['detail'], 'auto');
    expect(file['file_data'], 'data:application/pdf;base64,JVBERg==');
    expect(content.last, {'type': 'input_text', 'text': '读取并总结附件'});
    expect(result.text, '已读取真实文件');
    expect(rawRequestBody, isNot(contains('/Users/')));
  });

  test('rejects a file whose bytes do not match its declared type', () {
    expect(
      () => AssistantInputFile(
        filename: '伪装文件.pdf',
        contentType: 'application/pdf',
        bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
      ),
      throwsArgumentError,
    );
  });

  test('sends real image bytes as Responses API input_image content', () async {
    Map<String, Object?>? requestBody;
    final httpClient = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, Object?>;
      return http.Response(
        jsonEncode({'id': 'response-2', 'output_text': '已读取图片'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = OpenAiResponsesClient(httpClient: httpClient);
    addTearDown(client.close);
    final registry = ToolRegistry(
      approvals: (_, _) async => ApprovalDecision.decline,
    );
    final png = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
    ]);

    final result = await client.run(
      provider: AiProviderModel(
        id: 'provider-1',
        name: 'Responses',
        kind: AiProviderKind.openaiResponses,
        baseUrl: Uri.parse('https://api.example.test/v1'),
        textModel: 'vision-model',
        secretRef: 'secret',
      ),
      apiKey: 'test-key',
      input: '说明图片',
      files: [
        AssistantInputFile(
          filename: '日程.png',
          contentType: 'image/png',
          bytes: png,
        ),
      ],
      tools: registry,
    );

    final input = requestBody!['input']! as List<Object?>;
    final message = input.single as Map<String, Object?>;
    final content = message['content']! as List<Object?>;
    final image = content.first as Map<String, Object?>;
    expect(image['type'], 'input_image');
    expect(image['detail'], 'auto');
    expect(image['image_url'], 'data:image/png;base64,iVBORw0KGgoA');
    expect(image, isNot(contains('filename')));
    expect(content.last, {'type': 'input_text', 'text': '说明图片'});
    expect(result.text, '已读取图片');
  });

  test('rejects an image whose bytes do not match its declared type', () {
    expect(
      () => AssistantInputFile(
        filename: '伪装图片.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList(const [0xff, 0xd8, 0xff]),
      ),
      throwsArgumentError,
    );
  });
}
