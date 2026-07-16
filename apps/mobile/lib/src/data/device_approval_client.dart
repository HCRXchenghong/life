import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _approvalTimeout = Duration(seconds: 20);
const _maximumApprovalResponseBytes = 64 << 10;

class RemoteDeviceApprovalRequest {
  const RemoteDeviceApprovalRequest({
    required this.id,
    required this.deviceName,
    required this.publicKey,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String deviceName;
  final Uint8List publicKey;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class RemoteDeviceApprovalDecision {
  const RemoteDeviceApprovalDecision({
    required this.approverPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.keyVersion,
  });

  final List<int> approverPublicKey;
  final List<int> nonce;
  final List<int> ciphertext;
  final int keyVersion;

  Map<String, Object?> toJson() => {
    'approverPublicKey': base64Encode(approverPublicKey),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
    'keyVersion': keyVersion,
  };
}

enum RemoteDeviceApprovalStatus {
  pending,
  approved,
  rejected,
  consumed,
  expired,
}

class RemoteDeviceApprovalState {
  const RemoteDeviceApprovalState({
    required this.id,
    required this.status,
    required this.deviceName,
    required this.publicKey,
    required this.createdAt,
    required this.expiresAt,
    this.approverPublicKey,
    this.nonce,
    this.ciphertext,
    this.keyVersion,
  });

  final String id;
  final RemoteDeviceApprovalStatus status;
  final String deviceName;
  final Uint8List publicKey;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Uint8List? approverPublicKey;
  final Uint8List? nonce;
  final Uint8List? ciphertext;
  final int? keyVersion;
}

class DeviceApprovalClientException implements Exception {
  const DeviceApprovalClientException(
    this.message, {
    this.sessionRejected = false,
    this.unavailable = false,
  });

  final String message;
  final bool sessionRejected;
  final bool unavailable;

  @override
  String toString() => message;
}

abstract interface class DeviceApprovalTransport {
  Future<DateTime> create({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
    required List<int> publicKey,
  });

  Future<RemoteDeviceApprovalState> loadStatus({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  });

  Future<List<RemoteDeviceApprovalRequest>> listPending({
    required String accessToken,
  });

  Future<void> approve({
    required String accessToken,
    required String requestId,
    required RemoteDeviceApprovalDecision decision,
  });

  Future<void> reject({required String accessToken, required String requestId});

  Future<void> consume({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  });

  Future<void> cancel({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  });

  void close();
}

class DeviceApprovalClient implements DeviceApprovalTransport {
  DeviceApprovalClient({required Uri apiBaseUri, http.Client? httpClient})
    : _baseUri = _validateBaseUri(apiBaseUri),
      _client = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<DateTime> create({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
    required List<int> publicKey,
  }) async {
    _validateRequestId(requestId);
    final proof = _requestProof(requestToken);
    if (publicKey.length != 32 || publicKey.every((byte) => byte == 0)) {
      throw const DeviceApprovalClientException('设备批准请求无效');
    }
    final payload = await _request(
      'POST',
      'sync/device-approvals',
      accessToken: accessToken,
      body: {
        'id': requestId,
        'publicKey': base64Encode(publicKey),
        'requestToken': proof,
      },
    );
    try {
      if (_requiredString(payload, 'id', 36) != requestId ||
          payload['status'] != 'pending') {
        throw const FormatException();
      }
      final expiresAt = _requiredDate(payload, 'expiresAt');
      final now = DateTime.now().toUtc();
      if (!expiresAt.isAfter(now.subtract(const Duration(minutes: 1))) ||
          expiresAt.isAfter(now.add(const Duration(minutes: 12)))) {
        throw const FormatException();
      }
      return expiresAt;
    } on FormatException {
      throw const DeviceApprovalClientException('设备批准服务返回了无效响应');
    }
  }

  @override
  Future<RemoteDeviceApprovalState> loadStatus({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async {
    _validateRequestId(requestId);
    final payload = await _request(
      'GET',
      'sync/device-approvals/$requestId',
      accessToken: accessToken,
      requestProof: _requestProof(requestToken),
    );
    try {
      if (_requiredString(payload, 'id', 36) != requestId) {
        throw const FormatException();
      }
      final status = switch (_requiredString(payload, 'status', 16)) {
        'pending' => RemoteDeviceApprovalStatus.pending,
        'approved' => RemoteDeviceApprovalStatus.approved,
        'rejected' => RemoteDeviceApprovalStatus.rejected,
        'consumed' => RemoteDeviceApprovalStatus.consumed,
        'expired' => RemoteDeviceApprovalStatus.expired,
        _ => throw const FormatException(),
      };
      Uint8List? approverPublicKey;
      Uint8List? nonce;
      Uint8List? ciphertext;
      int? keyVersion;
      if (status == RemoteDeviceApprovalStatus.approved ||
          status == RemoteDeviceApprovalStatus.consumed) {
        approverPublicKey = _decodeFixed(payload['approverPublicKey'], 32);
        nonce = _decodeFixed(payload['nonce'], 12);
        ciphertext = _decodeFixed(payload['ciphertext'], 48);
        final rawVersion = payload['keyVersion'];
        if (rawVersion is! int || rawVersion < 1 || rawVersion > 1000000) {
          throw const FormatException();
        }
        keyVersion = rawVersion;
      }
      final createdAt = _requiredDate(payload, 'createdAt');
      final expiresAt = _requiredDate(payload, 'expiresAt');
      if (!expiresAt.isAfter(createdAt) ||
          expiresAt.difference(createdAt) > const Duration(minutes: 11)) {
        throw const FormatException();
      }
      return RemoteDeviceApprovalState(
        id: requestId,
        status: status,
        deviceName: _requiredString(payload, 'deviceName', 80),
        publicKey: _decodeFixed(payload['publicKey'], 32),
        createdAt: createdAt,
        expiresAt: expiresAt,
        approverPublicKey: approverPublicKey,
        nonce: nonce,
        ciphertext: ciphertext,
        keyVersion: keyVersion,
      );
    } on FormatException {
      throw const DeviceApprovalClientException('设备批准服务返回了无效响应');
    }
  }

  @override
  Future<List<RemoteDeviceApprovalRequest>> listPending({
    required String accessToken,
  }) async {
    final payload = await _request(
      'GET',
      'sync/device-approvals',
      accessToken: accessToken,
    );
    try {
      final rawRequests = payload['requests'];
      if (rawRequests is! List<Object?> || rawRequests.length > 20) {
        throw const FormatException();
      }
      final requests = <RemoteDeviceApprovalRequest>[];
      for (final raw in rawRequests) {
        if (raw is! Map<String, Object?>) throw const FormatException();
        final id = _requiredString(raw, 'id', 36);
        if (!_uuidPattern.hasMatch(id)) throw const FormatException();
        final createdAt = _requiredDate(raw, 'createdAt');
        final expiresAt = _requiredDate(raw, 'expiresAt');
        if (!expiresAt.isAfter(createdAt) ||
            expiresAt.difference(createdAt) > const Duration(minutes: 11)) {
          throw const FormatException();
        }
        requests.add(
          RemoteDeviceApprovalRequest(
            id: id,
            deviceName: _requiredString(raw, 'deviceName', 80),
            publicKey: _decodeFixed(raw['publicKey'], 32),
            createdAt: createdAt,
            expiresAt: expiresAt,
          ),
        );
      }
      return List.unmodifiable(requests);
    } on FormatException {
      throw const DeviceApprovalClientException('设备批准服务返回了无效响应');
    }
  }

  @override
  Future<void> approve({
    required String accessToken,
    required String requestId,
    required RemoteDeviceApprovalDecision decision,
  }) async {
    _validateRequestId(requestId);
    await _request(
      'POST',
      'sync/device-approvals/$requestId/approve',
      accessToken: accessToken,
      body: decision.toJson(),
    );
  }

  @override
  Future<void> reject({
    required String accessToken,
    required String requestId,
  }) async {
    _validateRequestId(requestId);
    await _request(
      'POST',
      'sync/device-approvals/$requestId/reject',
      accessToken: accessToken,
      body: const <String, Object?>{},
    );
  }

  @override
  Future<void> consume({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async {
    _validateRequestId(requestId);
    await _request(
      'POST',
      'sync/device-approvals/$requestId/consume',
      accessToken: accessToken,
      requestProof: _requestProof(requestToken),
      body: const <String, Object?>{},
    );
  }

  @override
  Future<void> cancel({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async {
    _validateRequestId(requestId);
    await _request(
      'DELETE',
      'sync/device-approvals/$requestId',
      accessToken: accessToken,
      requestProof: _requestProof(requestToken),
    );
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    required String accessToken,
    Map<String, Object?>? body,
    String? requestProof,
  }) async {
    final request = http.Request(method, _baseUri.resolve(path))
      ..headers['accept'] = 'application/json'
      ..headers['authorization'] = _bearer(accessToken);
    if (requestProof != null) {
      request.headers['x-daylink-device-request'] = requestProof;
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    late http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(_approvalTimeout);
    } on Object {
      throw const DeviceApprovalClientException('设备批准服务暂时不可用');
    }
    final bytes = await _readBounded(response.stream);
    if (response.statusCode == 401) {
      throw const DeviceApprovalClientException(
        '登录已失效，请重新登录',
        sessionRejected: true,
      );
    }
    if (response.statusCode == 404 || response.statusCode == 409) {
      throw const DeviceApprovalClientException('设备批准请求已失效', unavailable: true);
    }
    if (response.statusCode == 403) {
      throw const DeviceApprovalClientException(
        '设备批准请求凭证无效',
        unavailable: true,
      );
    }
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        !contentType.startsWith('application/json')) {
      throw const DeviceApprovalClientException('设备批准服务暂时不可用');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw const DeviceApprovalClientException('设备批准服务返回了无效响应');
    }
  }

  @override
  void close() => _client.close();
}

String _requestProof(List<int> token) {
  if (token.length != 32 ||
      token.any((byte) => byte < 0 || byte > 255) ||
      token.every((byte) => byte == 0)) {
    throw const DeviceApprovalClientException('设备批准请求无效');
  }
  return base64UrlEncode(token).replaceAll('=', '');
}

Future<List<int>> _readBounded(Stream<List<int>> stream) async {
  final bytes = <int>[];
  try {
    await for (final chunk in stream.timeout(_approvalTimeout)) {
      bytes.addAll(chunk);
      if (bytes.length > _maximumApprovalResponseBytes) {
        throw const DeviceApprovalClientException('设备批准服务响应过大');
      }
    }
    return bytes;
  } on DeviceApprovalClientException {
    rethrow;
  } on Object {
    throw const DeviceApprovalClientException('设备批准服务暂时不可用');
  }
}

String _bearer(String token) {
  if (!token.startsWith('dlka_') ||
      token.length < 32 ||
      token.length > 256 ||
      token.contains(RegExp(r'[\r\n\x00]'))) {
    throw const DeviceApprovalClientException(
      '登录已失效，请重新登录',
      sessionRejected: true,
    );
  }
  return 'Bearer $token';
}

void _validateRequestId(String value) {
  if (!_uuidPattern.hasMatch(value)) {
    throw const DeviceApprovalClientException('设备批准请求无效');
  }
}

String _requiredString(Map<String, Object?> value, String key, int maximum) {
  final item = value[key];
  if (item is! String ||
      item.isEmpty ||
      item.length > maximum ||
      item.contains(RegExp(r'[\r\n\x00]'))) {
    throw const FormatException();
  }
  return item;
}

DateTime _requiredDate(Map<String, Object?> value, String key) {
  final item = value[key];
  if (item is! String || item.length > 40) throw const FormatException();
  final parsed = DateTime.tryParse(item)?.toUtc();
  if (parsed == null) throw const FormatException();
  return parsed;
}

Uint8List _decodeFixed(Object? value, int length) {
  if (value is! String || value.length > 256) throw const FormatException();
  final decoded = base64Decode(value);
  if (decoded.length != length || decoded.every((byte) => byte == 0)) {
    throw const FormatException();
  }
  return decoded;
}

Uri _validateBaseUri(Uri value) {
  final secure = value.scheme == 'https';
  final loopback =
      value.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '::1'}.contains(value.host);
  if ((!secure && !loopback) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      !value.path.endsWith('/')) {
    throw ArgumentError('API base URI must use HTTPS and end with /');
  }
  return value;
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
