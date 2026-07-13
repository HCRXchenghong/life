import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_models.dart';
import 'tool_protocol.dart';

class OpenAiResponsesClient {
  OpenAiResponsesClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();
  final http.Client _http;

  void close() => _http.close();

  Future<AiTurnResult> run({
    required AiProviderModel provider,
    required String apiKey,
    required String input,
    required ToolRegistry tools,
    String? previousResponseId,
    int maxToolRounds = 12,
  }) async {
    if (!provider.enabled) throw StateError('AI provider is disabled');
    var round = 0;
    var nextInput = <Object?>[
      {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': input},
        ],
      },
    ];
    var previous = previousResponseId;
    var toolCallCount = 0;
    while (round++ < maxToolRounds) {
      final body = <String, Object?>{
        if (provider.kind != AiProviderKind.daylinkGateway)
          'model': provider.textModel,
        if (provider.kind == AiProviderKind.daylinkGateway)
          'providerId': provider.id,
        'input': nextInput,
        'tools': tools.specs.map((spec) => spec.toResponsesTool()).toList(),
        'store': true,
        'parallel_tool_calls': false,
        'previous_response_id': ?previous,
      };
      final response = await _post(
        _endpoint(
          provider.baseUrl,
          provider.kind == AiProviderKind.daylinkGateway
              ? 'assistant/responses'
              : 'responses',
        ),
        apiKey,
        body,
      );
      final responseId = response['id'] as String? ?? '';
      final output = (response['output'] as List<Object?>? ?? const []);
      final calls = output
          .whereType<Map<String, Object?>>()
          .where((item) => item['type'] == 'function_call')
          .toList(growable: false);
      if (calls.isEmpty) {
        return AiTurnResult(
          responseId: responseId,
          text: _outputText(response),
          toolCalls: toolCallCount,
        );
      }
      final outputs = <Object?>[];
      for (final raw in calls) {
        final callId = raw['call_id'] as String?;
        final name = raw['name'] as String?;
        if (callId == null || name == null) continue;
        final arguments =
            jsonDecode(raw['arguments'] as String? ?? '{}')
                as Map<String, Object?>;
        final result = await tools.invoke(
          ToolCall(callId: callId, name: name, arguments: arguments),
        );
        outputs.add({
          'type': 'function_call_output',
          'call_id': callId,
          'output': jsonEncode({
            'success': result.success,
            'output': result.output,
          }),
        });
        toolCallCount++;
      }
      previous = responseId;
      nextInput = outputs;
    }
    throw StateError('AI tool loop exceeded $maxToolRounds rounds');
  }

  Future<Uint8List> generateImage({
    required AiProviderModel provider,
    required String apiKey,
    required String prompt,
    String size = '1024x1024',
    String quality = 'medium',
  }) async {
    final model = provider.imageModel;
    if (model == null || model.isEmpty) {
      throw StateError('Image model is not configured');
    }
    final response = await _post(
      _endpoint(
        provider.baseUrl,
        provider.kind == AiProviderKind.daylinkGateway
            ? 'assistant/images'
            : 'images/generations',
      ),
      apiKey,
      {
        if (provider.kind != AiProviderKind.daylinkGateway) 'model': model,
        if (provider.kind == AiProviderKind.daylinkGateway)
          'providerId': provider.id,
        'prompt': prompt,
        'n': 1,
        'size': size,
        'quality': quality,
        'output_format': 'png',
      },
    );
    final data = response['data'] as List<Object?>?;
    final first = data == null || data.isEmpty
        ? null
        : data.first as Map<String, Object?>?;
    final encoded = first?['b64_json'] as String?;
    if (encoded == null) throw StateError('Image provider returned no image');
    return base64Decode(encoded);
  }

  Future<Map<String, Object?>> _post(
    Uri endpoint,
    String apiKey,
    Map<String, Object?> body,
  ) async {
    final response = await _http
        .post(
          endpoint,
          headers: {
            'authorization': 'Bearer $apiKey',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(minutes: 2));
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as Map<String, Object?>?;
      throw AiProviderException(
        statusCode: response.statusCode,
        code: error?['code'] as String? ?? 'provider_error',
        message: error?['message'] as String? ?? 'AI provider request failed',
        requestId: response.headers['x-request-id'],
      );
    }
    return decoded;
  }

  String _outputText(Map<String, Object?> response) {
    if (response['output_text'] case final String text) return text;
    final chunks = <String>[];
    for (final item in response['output'] as List<Object?>? ?? const []) {
      if (item is! Map<String, Object?>) continue;
      for (final content in item['content'] as List<Object?>? ?? const []) {
        if (content is Map<String, Object?> && content['text'] is String) {
          chunks.add(content['text']! as String);
        }
      }
    }
    return chunks.join('\n');
  }

  Uri _endpoint(Uri base, String path) =>
      Uri.parse('${base.toString().replaceFirst(RegExp(r'/$'), '')}/$path');
}

class AiProviderException implements Exception {
  const AiProviderException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
  });
  final int statusCode;
  final String code;
  final String message;
  final String? requestId;

  @override
  String toString() => 'AiProviderException($code, $statusCode): $message';
}
