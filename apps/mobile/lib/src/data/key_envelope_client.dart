import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _maximumEnvelopeResponseBytes = 64 << 10;
const _envelopeTimeout = Duration(seconds: 20);

class KeyEnvelope {
  const KeyEnvelope({
    this.envelopeRevision = 1,
    required this.keyVersion,
    required this.algorithm,
    required this.kdf,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.creatorDeviceId,
  });

  final int envelopeRevision;
  final int keyVersion;
  final String algorithm;
  final String kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final String creatorDeviceId;

  bool sameAs(KeyEnvelope other) =>
      envelopeRevision == other.envelopeRevision &&
      keyVersion == other.keyVersion &&
      algorithm == other.algorithm &&
      kdf == other.kdf &&
      creatorDeviceId == other.creatorDeviceId &&
      _bytesEqual(salt, other.salt) &&
      _bytesEqual(nonce, other.nonce) &&
      _bytesEqual(ciphertext, other.ciphertext);

  Map<String, Object?> toJson() => {
    'keyVersion': keyVersion,
    'algorithm': algorithm,
    'kdf': kdf,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
    'creatorDeviceId': creatorDeviceId,
  };
}

class KeyEnvelopeClientException implements Exception {
  const KeyEnvelopeClientException(
    this.message, {
    this.sessionRejected = false,
    this.conflict = false,
  });

  final String message;
  final bool sessionRejected;
  final bool conflict;

  @override
  String toString() => message;
}

abstract interface class KeyEnvelopeTransport {
  Future<KeyEnvelope?> load({required String accessToken});

  Future<void> store({
    required String accessToken,
    required KeyEnvelope envelope,
  });

  Future<void> beginRecoveryKeyRotation({
    required String accessToken,
    required String rotationId,
    required int expectedRevision,
    required KeyEnvelope envelope,
  });

  Future<void> commitRecoveryKeyRotation({
    required String accessToken,
    required String rotationId,
  });

  void close();
}

class KeyEnvelopeClient implements KeyEnvelopeTransport {
  KeyEnvelopeClient({required Uri apiBaseUri, http.Client? httpClient})
    : _baseUri = _validateBaseUri(apiBaseUri),
      _client = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<KeyEnvelope?> load({required String accessToken}) async {
    final response = await _send(
      http.Request('GET', _baseUri.resolve('sync/key-envelope'))
        ..headers['Authorization'] = _bearer(accessToken),
    );
    final payload = await _decodeResponse(
      response,
      expectedStatuses: const {200},
    );
    try {
      final exists = payload['exists'];
      if (exists == false) return null;
      if (exists != true) throw const FormatException('Invalid envelope state');
      return _parseEnvelope(payload);
    } on FormatException {
      throw const KeyEnvelopeClientException('密钥服务返回了无效响应');
    }
  }

  @override
  Future<void> store({
    required String accessToken,
    required KeyEnvelope envelope,
  }) async {
    final response = await _send(
      http.Request('PUT', _baseUri.resolve('sync/key-envelope'))
        ..headers['Authorization'] = _bearer(accessToken)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode(envelope.toJson()),
    );
    if (response.statusCode == 409) {
      await _readBounded(response.stream);
      throw const KeyEnvelopeClientException('该账号已存在其他内容密钥', conflict: true);
    }
    await _decodeResponse(response, expectedStatuses: const {200, 201});
  }

  @override
  Future<void> beginRecoveryKeyRotation({
    required String accessToken,
    required String rotationId,
    required int expectedRevision,
    required KeyEnvelope envelope,
  }) async {
    final response = await _send(
      http.Request('POST', _baseUri.resolve('sync/key-envelope/rotations'))
        ..headers['Authorization'] = _bearer(accessToken)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode({
          'rotationId': rotationId,
          'expectedRevision': expectedRevision,
          'envelope': envelope.toJson(),
        }),
    );
    if (response.statusCode == 409) {
      await _readBounded(response.stream);
      throw const KeyEnvelopeClientException(
        '恢复密钥已在其他设备更新或正在更新',
        conflict: true,
      );
    }
    await _decodeResponse(response, expectedStatuses: const {200, 201});
  }

  @override
  Future<void> commitRecoveryKeyRotation({
    required String accessToken,
    required String rotationId,
  }) async {
    final response = await _send(
      http.Request(
        'POST',
        _baseUri.resolve(
          'sync/key-envelope/rotations/${Uri.encodeComponent(rotationId)}/commit',
        ),
      )..headers['Authorization'] = _bearer(accessToken),
    );
    if (response.statusCode == 409) {
      await _readBounded(response.stream);
      throw const KeyEnvelopeClientException(
        '恢复密钥轮换已完成、过期或发生冲突',
        conflict: true,
      );
    }
    await _decodeResponse(response, expectedStatuses: const {200});
  }

  Future<http.StreamedResponse> _send(http.Request request) async {
    try {
      final response = await _client.send(request).timeout(_envelopeTimeout);
      return response;
    } on KeyEnvelopeClientException {
      rethrow;
    } on Object {
      throw const KeyEnvelopeClientException('密钥服务暂时不可用');
    }
  }

  Future<Map<String, Object?>> _decodeResponse(
    http.StreamedResponse response, {
    required Set<int> expectedStatuses,
  }) async {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.startsWith('application/json')) {
      await _readBounded(response.stream);
      throw const KeyEnvelopeClientException('密钥服务返回了无效响应');
    }
    final bytes = await _readBounded(response.stream);
    if (response.statusCode == 401) {
      throw const KeyEnvelopeClientException(
        '登录已失效，请重新登录',
        sessionRejected: true,
      );
    }
    if (!expectedStatuses.contains(response.statusCode)) {
      throw const KeyEnvelopeClientException('密钥服务暂时不可用');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw const KeyEnvelopeClientException('密钥服务返回了无效响应');
    }
  }

  @override
  void close() => _client.close();
}

Future<List<int>> _readBounded(Stream<List<int>> stream) async {
  final bytes = <int>[];
  try {
    await for (final chunk in stream.timeout(_envelopeTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > _maximumEnvelopeResponseBytes) {
        throw const KeyEnvelopeClientException('密钥服务响应过大');
      }
    }
    return bytes;
  } on KeyEnvelopeClientException {
    rethrow;
  } on Object {
    throw const KeyEnvelopeClientException('密钥服务暂时不可用');
  }
}

KeyEnvelope _parseEnvelope(Map<String, Object?> value) {
  final envelopeRevision = value['envelopeRevision'];
  final version = value['keyVersion'];
  final algorithm = value['algorithm'];
  final kdf = value['kdf'];
  final deviceId = value['creatorDeviceId'];
  if (envelopeRevision is! int ||
      envelopeRevision < 1 ||
      envelopeRevision > 0x7FFFFFFFFFFFFFFF ||
      version != 1 ||
      algorithm != 'aes-256-gcm' ||
      kdf != 'hkdf-sha256' ||
      deviceId is! String ||
      !_uuidPattern.hasMatch(deviceId)) {
    throw const FormatException('Invalid envelope metadata');
  }
  return KeyEnvelope(
    envelopeRevision: envelopeRevision,
    keyVersion: version as int,
    algorithm: algorithm as String,
    kdf: kdf as String,
    salt: _decodeFixed(value['salt'], 32),
    nonce: _decodeFixed(value['nonce'], 12),
    ciphertext: _decodeFixed(value['ciphertext'], 48),
    creatorDeviceId: deviceId,
  );
}

Uint8List _decodeFixed(Object? value, int length) {
  if (value is! String || value.length > 256) throw const FormatException();
  try {
    final bytes = base64Decode(value);
    if (bytes.length != length) throw const FormatException();
    return bytes;
  } on FormatException {
    throw const FormatException('Invalid envelope bytes');
  }
}

Uri _validateBaseUri(Uri value) {
  final secure = value.scheme == 'https';
  final loopback =
      value.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '::1'}.contains(value.host);
  if ((!secure && !loopback) ||
      value.host.isEmpty ||
      !value.path.endsWith('/')) {
    throw ArgumentError('API base URI must use HTTPS and end with /');
  }
  return value;
}

String _bearer(String token) {
  if (!token.startsWith('dlka_') ||
      token.length > 300 ||
      token.contains(RegExp(r'[\r\n\x00]'))) {
    throw const KeyEnvelopeClientException(
      '登录已失效，请重新登录',
      sessionRejected: true,
    );
  }
  return 'Bearer $token';
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
