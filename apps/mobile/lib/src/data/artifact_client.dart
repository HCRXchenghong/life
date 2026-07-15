import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _maximumArtifactBytes = 24 << 20;

abstract interface class ArtifactGenerator {
  Future<GeneratedArtifactPayload> generate(Map<String, Object?> request);
}

class GeneratedArtifactPayload {
  const GeneratedArtifactPayload({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
}

class ArtifactClient implements ArtifactGenerator {
  ArtifactClient({
    required Uri apiBaseUri,
    required String mobileToken,
    http.Client? httpClient,
  }) : _apiBaseUri = _validateBaseUri(apiBaseUri),
       _mobileToken = _requireToken(mobileToken),
       _http = httpClient ?? http.Client();

  final Uri _apiBaseUri;
  final String _mobileToken;
  final http.Client _http;

  @override
  Future<GeneratedArtifactPayload> generate(
    Map<String, Object?> requestBody,
  ) async {
    final request = http.Request('POST', _apiBaseUri.resolve('assistant/artifacts'))
      ..headers.addAll({
        'accept': [
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        ].join(', '),
        'authorization': 'Bearer $_mobileToken',
        'content-type': 'application/json',
      })
      ..body = jsonEncode(requestBody);
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 40));
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > _maximumArtifactBytes) {
      throw const ArtifactApiException(
        'artifact_too_large',
        'Generated artifact is too large',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 40),
    )) {
      if (bytes.length + chunk.length > _maximumArtifactBytes) {
        throw const ArtifactApiException(
          'artifact_too_large',
          'Generated artifact is too large',
        );
      }
      bytes.add(chunk);
    }
    final content = bytes.takeBytes();
    if (response.statusCode != 200) {
      throw _serverError(response.statusCode, content);
    }
    final contentType = response.headers['content-type']?.split(';').first;
    final extension = _extensionForContentType(contentType);
    if (extension == null ||
        content.length < 4 ||
        content[0] != 0x50 ||
        content[1] != 0x4b) {
      throw const ArtifactApiException(
        'invalid_response',
        'Server returned an invalid Office artifact',
      );
    }
    return GeneratedArtifactPayload(
      bytes: content,
      contentType: contentType!,
      extension: extension,
    );
  }

  void close() => _http.close();
}

class ArtifactApiException implements Exception {
  const ArtifactApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ArtifactApiException($code): $message';
}

ArtifactApiException _serverError(int statusCode, Uint8List body) {
  if (body.length <= 64 << 10) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is Map<String, Object?> &&
          decoded['error'] is Map<String, Object?>) {
        final error = decoded['error']! as Map<String, Object?>;
        return ArtifactApiException(
          error['code'] as String? ?? 'http_$statusCode',
          error['message'] as String? ?? 'Artifact generation failed',
          statusCode: statusCode,
        );
      }
    } on Object {
      // A generic error below avoids returning arbitrary upstream content.
    }
  }
  return ArtifactApiException(
    'http_$statusCode',
    'Artifact generation failed',
    statusCode: statusCode,
  );
}

String? _extensionForContentType(String? contentType) => switch (contentType) {
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
    'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
    'pptx',
  _ => null,
};

Uri _validateBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty) {
    throw ArgumentError(
      'artifact API must use HTTPS (HTTP is allowed only on loopback)',
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
