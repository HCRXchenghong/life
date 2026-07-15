import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/ai/ai_models.dart';

class AiGatewayClient {
  AiGatewayClient({
    required Uri apiBaseUri,
    required String mobileToken,
    http.Client? httpClient,
  }) : _apiBaseUri = _validateBaseUri(apiBaseUri),
       _mobileToken = _requireToken(mobileToken),
       _http = httpClient ?? http.Client();

  final Uri _apiBaseUri;
  final String _mobileToken;
  final http.Client _http;

  Future<AiEntitlement> entitlement() async {
    final payload = await _request('GET', 'app/ai-entitlement');
    return AiEntitlement.fromJson(
      payload['entitlement']! as Map<String, Object?>,
    );
  }

  Future<DaylinkAiConfiguration> localConfiguration() async {
    final payload = await _request('GET', 'app/ai-settings');
    final provider = payload['provider']! as Map<String, Object?>;
    final models = (provider['models'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .where((model) => model['kind'] == 'text' && model['id'] is String)
        .map((model) => model['id']! as String)
        .toList(growable: false);
    final selectedModel =
        provider['selectedTextModel'] as String? ??
        provider['textModel']! as String;
    return DaylinkAiConfiguration(
      provider: AiProviderModel(
        id: provider['id']! as String,
        name: provider['name']! as String,
        kind: AiProviderKind.daylinkGateway,
        baseUrl: Uri.parse(provider['baseUrl']! as String),
        textModel: selectedModel,
        imageModel: provider['imageModel'] as String?,
        availableTextModels: models,
        reasoningEffort: AiReasoningEffort.parse(
          provider['reasoningEffort'] as String? ?? 'medium',
        ),
        secretRef: 'daylink-session',
      ),
      accessToken: _mobileToken,
    );
  }

  Future<void> updatePreferences({
    required String model,
    required AiReasoningEffort reasoningEffort,
  }) async {
    await _request(
      'PUT',
      'app/ai-preferences',
      body: {'textModel': model, 'reasoningEffort': reasoningEffort.name},
    );
  }

  Future<RemoteAiGatewayCredential> createRemoteCredential() async {
    final payload = await _request('POST', 'app/ai-remote-token');
    final gateway = payload['gateway']! as Map<String, Object?>;
    final token = gateway['token']! as String;
    if (!token.startsWith('dlkc_') ||
        token.length > 300 ||
        token.runes.any(
          (character) => character <= 0x20 || character == 0x7f,
        )) {
      throw const AiGatewayException(
        'invalid_response',
        'Server returned an invalid remote Agent credential',
      );
    }
    final baseUrl = Uri.parse(gateway['baseUrl']! as String);
    if (!baseUrl.isScheme('https') ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.query.isNotEmpty ||
        baseUrl.fragment.isNotEmpty ||
        !baseUrl.path.endsWith('/v1')) {
      throw const AiGatewayException(
        'invalid_response',
        'Server returned an invalid remote Agent gateway URL',
      );
    }
    return RemoteAiGatewayCredential(
      baseUrl: baseUrl,
      token: token,
      model: gateway['model']! as String,
      reasoningEffort: AiReasoningEffort.parse(
        gateway['reasoningEffort'] as String? ?? 'medium',
      ),
      expiresAt: DateTime.parse(gateway['expiresAt']! as String).toUtc(),
    );
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _apiBaseUri.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $_mobileToken',
        if (method != 'GET') 'content-type': 'application/json',
      });
    if (method != 'GET') {
      request.body = jsonEncode(body ?? const <String, Object?>{});
    }
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    if ((response.contentLength ?? 0) > 1 << 20) {
      throw const AiGatewayException(
        'invalid_response',
        'AI gateway response is too large',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (builder.length + chunk.length > 1 << 20) {
        throw const AiGatewayException(
          'invalid_response',
          'AI gateway response is too large',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    Map<String, Object?> payload;
    try {
      payload = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } on Object {
      throw const AiGatewayException(
        'invalid_response',
        'AI gateway returned invalid JSON',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'] as Map<String, Object?>?;
      throw AiGatewayException(
        error?['code'] as String? ?? 'http_${response.statusCode}',
        error?['message'] as String? ?? 'AI gateway request failed',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  void close() => _http.close();
}

enum AiExecutionMode {
  localAI('local_ai'),
  sshAgent('ssh_agent');

  const AiExecutionMode(this.wireName);
  final String wireName;

  static AiExecutionMode fromWireName(String value) => values.firstWhere(
    (mode) => mode.wireName == value,
    orElse: () => throw const AiGatewayException(
      'invalid_response',
      'Server returned an unsupported AI execution mode',
    ),
  );
}

class DaylinkAiConfiguration {
  const DaylinkAiConfiguration({
    required this.provider,
    required this.accessToken,
  });

  final AiProviderModel provider;
  final String accessToken;
}

class RemoteAiGatewayCredential {
  const RemoteAiGatewayCredential({
    required this.baseUrl,
    required this.token,
    required this.model,
    required this.reasoningEffort,
    required this.expiresAt,
  });

  final Uri baseUrl;
  final String token;
  final String model;
  final AiReasoningEffort reasoningEffort;
  final DateTime expiresAt;
}

class AiEntitlement {
  const AiEntitlement({
    required this.active,
    required this.plan,
    required this.cardType,
    required this.expiresAt,
    required this.weeklyUsed,
    required this.weeklyLimit,
    required this.weeklyResetsAt,
    required this.monthlyUsed,
    required this.monthlyLimit,
    required this.monthlyResetsAt,
    required this.supportedModes,
  });

  factory AiEntitlement.fromJson(Map<String, Object?> value) => AiEntitlement(
    active: value['active']! as bool,
    plan: value['plan'] as String?,
    cardType: value['cardType'] as String?,
    expiresAt: value['expiresAt'] == null
        ? null
        : DateTime.parse(value['expiresAt']! as String).toUtc(),
    weeklyUsed: value['weeklyUsed']! as int,
    weeklyLimit: value['weeklyLimit'] as int?,
    weeklyResetsAt: DateTime.parse(value['weeklyResetsAt']! as String).toUtc(),
    monthlyUsed: value['monthlyUsed']! as int,
    monthlyLimit: value['monthlyLimit'] as int?,
    monthlyResetsAt: DateTime.parse(
      value['monthlyResetsAt']! as String,
    ).toUtc(),
    supportedModes: (value['supportedModes']! as List<Object?>)
        .cast<String>()
        .map(AiExecutionMode.fromWireName)
        .toList(growable: false),
  );

  final bool active;
  final String? plan;
  final String? cardType;
  final DateTime? expiresAt;
  final int weeklyUsed;
  final int? weeklyLimit;
  final DateTime weeklyResetsAt;
  final int monthlyUsed;
  final int? monthlyLimit;
  final DateTime monthlyResetsAt;
  final List<AiExecutionMode> supportedModes;

  bool get unlimited => active && plan == 'max';
}

class AiGatewayException implements Exception {
  const AiGatewayException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AiGatewayException($code): $message';
}

Uri _validateBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.query.isNotEmpty ||
      value.fragment.isNotEmpty) {
    throw ArgumentError(
      'Daylink API must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  return value.path.endsWith('/')
      ? value
      : value.replace(path: '${value.path}/');
}

String _requireToken(String value) {
  if (!value.startsWith('dlka_') || value.length > 300) {
    throw ArgumentError('invalid App access token');
  }
  return value;
}
