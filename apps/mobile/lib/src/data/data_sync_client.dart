import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'data_sync_repository.dart';

const _maximumSyncResponseBytes = 4 << 20;
const _maximumCiphertextBytes = 2 << 20;
final _syncNamePattern = RegExp(r'^[a-z][a-z0-9_]{1,63}$');
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class DataSyncClientException implements Exception {
  const DataSyncClientException(this.message, {this.sessionRejected = false});

  final String message;
  final bool sessionRejected;

  @override
  String toString() => message;
}

class DataSyncPage {
  const DataSyncPage({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });

  final List<EncryptedSyncChangeDraft> changes;
  final int cursor;
  final bool hasMore;
}

class DataSyncClient {
  DataSyncClient({required Uri apiBaseUri, http.Client? httpClient})
    : _apiBaseUri = _validateApiBaseUri(apiBaseUri),
      _http = httpClient ?? http.Client();

  final Uri _apiBaseUri;
  final http.Client _http;

  Future<DataSyncPage> changes({
    required String accessToken,
    required int cursor,
  }) async {
    if (!_validAccessToken(accessToken) || cursor < 0) {
      throw const DataSyncClientException('同步请求无效');
    }
    final uri = _apiBaseUri
        .resolve('sync/changes')
        .replace(queryParameters: {'cursor': '$cursor', 'limit': '200'});
    final request = http.Request('GET', uri)
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
      });
    http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(const Duration(seconds: 15));
    } on Object {
      throw const DataSyncClientException('暂时无法连接同步服务');
    }
    if (response.statusCode == 401) {
      await response.stream.listen((_) {}).cancel();
      throw const DataSyncClientException('登录已失效，请重新登录', sessionRejected: true);
    }
    if (response.statusCode != 200 ||
        !response.headers['content-type'].toString().toLowerCase().startsWith(
          'application/json',
        )) {
      await response.stream.listen((_) {}).cancel();
      throw const DataSyncClientException('同步服务暂时不可用');
    }
    final body = await _readBoundedJson(response.stream);
    final rawChanges = body['changes'];
    final nextCursor = _requiredInt(body, 'cursor');
    final hasMore = body['hasMore'];
    if (rawChanges is! List<Object?> ||
        hasMore is! bool ||
        nextCursor < cursor) {
      throw const DataSyncClientException('同步服务返回异常');
    }
    final changes = <EncryptedSyncChangeDraft>[];
    var priorCursor = cursor;
    for (final raw in rawChanges) {
      if (raw is! Map<String, Object?>) {
        throw const DataSyncClientException('同步服务返回异常');
      }
      final change = _decodeChange(raw);
      if (change.cursor <= priorCursor || change.cursor > nextCursor) {
        throw const DataSyncClientException('同步游标无效');
      }
      priorCursor = change.cursor;
      changes.add(change);
    }
    if (changes.isNotEmpty && changes.last.cursor != nextCursor) {
      throw const DataSyncClientException('同步游标不完整');
    }
    if (hasMore && changes.isEmpty) {
      throw const DataSyncClientException('同步分页无进展');
    }
    return DataSyncPage(changes: changes, cursor: nextCursor, hasMore: hasMore);
  }

  void close() => _http.close();
}

EncryptedSyncChangeDraft _decodeChange(Map<String, Object?> value) {
  final cursor = _requiredInt(value, 'cursor');
  final collection = _requiredString(value, 'collection');
  final objectId = _requiredString(value, 'id');
  final operationId = _requiredString(value, 'operationId');
  final deviceId = _requiredString(value, 'deviceId');
  final revision = _requiredInt(value, 'revision');
  final deleted = value['deleted'];
  if (cursor < 1 ||
      revision < 1 ||
      deleted is! bool ||
      !_syncNamePattern.hasMatch(collection) ||
      !_uuidPattern.hasMatch(objectId) ||
      !_uuidPattern.hasMatch(operationId) ||
      !_uuidPattern.hasMatch(deviceId)) {
    throw const DataSyncClientException('同步变更无效');
  }
  final clientUpdatedAt = _requiredDate(value, 'clientUpdatedAt');
  final serverUpdatedAt = _requiredDate(value, 'serverUpdatedAt');
  Uint8List? ciphertext;
  Uint8List? nonce;
  int? keyVersion;
  if (!deleted) {
    ciphertext = _requiredBase64(value, 'ciphertext');
    nonce = _requiredBase64(value, 'nonce');
    keyVersion = _requiredInt(value, 'keyVersion');
    if (ciphertext.isEmpty ||
        ciphertext.length > _maximumCiphertextBytes ||
        nonce.length < 12 ||
        nonce.length > 64 ||
        keyVersion < 1 ||
        keyVersion > 1000000) {
      throw const DataSyncClientException('同步密文无效');
    }
  }
  return EncryptedSyncChangeDraft(
    cursor: cursor,
    collection: collection,
    objectId: objectId,
    operationId: operationId,
    deviceId: deviceId,
    revision: revision,
    deleted: deleted,
    ciphertext: ciphertext,
    nonce: nonce,
    keyVersion: keyVersion,
    clientUpdatedAt: clientUpdatedAt,
    serverUpdatedAt: serverUpdatedAt,
  );
}

Future<Map<String, Object?>> _readBoundedJson(Stream<List<int>> stream) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > _maximumSyncResponseBytes) {
      throw const DataSyncClientException('同步响应过大');
    }
    bytes.add(chunk);
  }
  try {
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map<String, Object?>) throw const FormatException();
    return decoded;
  } on FormatException {
    throw const DataSyncClientException('同步服务返回异常');
  }
}

int _requiredInt(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! num || !raw.isFinite || raw != raw.roundToDouble()) {
    throw const DataSyncClientException('同步服务返回异常');
  }
  return raw.toInt();
}

String _requiredString(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.isEmpty || raw.length > 128) {
    throw const DataSyncClientException('同步服务返回异常');
  }
  return raw;
}

DateTime _requiredDate(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.length > 64) {
    throw const DataSyncClientException('同步服务返回异常');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw const DataSyncClientException('同步服务返回异常');
  }
  return parsed.toUtc();
}

Uint8List _requiredBase64(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.length > 3 * _maximumCiphertextBytes) {
    throw const DataSyncClientException('同步密文无效');
  }
  try {
    return base64Decode(raw);
  } on FormatException {
    throw const DataSyncClientException('同步密文无效');
  }
}

Uri _validateApiBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.query.isNotEmpty ||
      value.fragment.isNotEmpty) {
    throw ArgumentError(
      'sync API must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  return value.path.endsWith('/')
      ? value
      : value.replace(path: '${value.path}/');
}

bool _validAccessToken(String value) =>
    value.startsWith('dlka_') &&
    value.length >= 32 &&
    value.length <= 300 &&
    !value.contains(RegExp(r'[\x00-\x20\x7f]'));
