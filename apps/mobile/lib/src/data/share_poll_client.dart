import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/poster/poster_template_models.dart';
import '../domain/share/share_poll_models.dart';

class SharePollClient {
  SharePollClient({
    required Uri apiBaseUri,
    required String mobileToken,
    http.Client? httpClient,
  }) : _apiBaseUri = _validateBaseUri(apiBaseUri),
       _mobileToken = _requireToken(mobileToken),
       _http = httpClient ?? http.Client();

  final Uri _apiBaseUri;
  final String _mobileToken;
  final http.Client _http;

  Future<List<PosterTemplate>> posterTemplates() async {
    final json = await _send(
      'GET',
      'poster-templates',
      authenticated: true,
      expectedStatuses: const {200},
    );
    final templates = json['templates'];
    if (templates is! List<Object?>) {
      throw const ShareApiException(
        'invalid_response',
        'Server returned an invalid poster template list',
      );
    }
    return templates
        .map((value) => PosterTemplate.fromJson(_map(value, 'template')))
        .toList(growable: false);
  }

  Future<List<ManagedSharePollSummary>> listManaged() async {
    final json = await _send(
      'GET',
      'polls',
      authenticated: true,
      expectedStatuses: const {200},
    );
    final polls = json['polls'];
    if (polls is! List<Object?>) {
      throw const ShareApiException(
        'invalid_response',
        'Server returned an invalid poll list',
      );
    }
    return polls
        .map((value) => ManagedSharePollSummary.fromJson(_map(value, 'poll')))
        .toList(growable: false);
  }

  Future<CreatedSharePoll> create(CreateSharePollDraft draft) async {
    draft.validate();
    final json = await _send(
      'POST',
      'polls',
      body: draft.toJson(),
      authenticated: true,
      expectedStatuses: const {201},
    );
    final poll = _map(json['poll'], 'poll');
    return CreatedSharePoll(
      pollId: _string(poll, 'id'),
      publicToken: _string(poll, 'publicToken'),
      manageToken: _string(poll, 'manageToken'),
      inviteUrl: Uri.parse(_string(poll, 'inviteUrl')),
      status: SharePollStatus.values.byName(_string(poll, 'status')),
      version: _integer(poll, 'version'),
      draft: draft,
    );
  }

  Future<String> createExclusive(CreateSharePollDraft draft) async {
    draft.validate();
    final body = draft.toJson()..['exclusiveInvites'] = true;
    final json = await _send(
      'POST',
      'polls',
      body: body,
      authenticated: true,
      expectedStatuses: const {201},
    );
    return _string(_map(json['poll'], 'poll'), 'id');
  }

  Future<FriendPollDetails> managedDetails(String pollId) async {
    final id = _pathToken(pollId);
    final json = await _send(
      'GET',
      'polls/$id/details',
      authenticated: true,
      expectedStatuses: const {200},
    );
    return FriendPollDetails.fromJson(json);
  }

  Future<FriendPollInvite> createFriendInvite({
    required String pollId,
    required String displayName,
  }) async {
    final id = _pathToken(pollId);
    final name = displayName.trim();
    if (name.isEmpty || name.length > 80) {
      throw ArgumentError('friend name must contain 1-80 characters');
    }
    final json = await _send(
      'POST',
      'polls/$id/invites',
      body: {'displayName': name},
      authenticated: true,
      expectedStatuses: const {201},
    );
    return FriendPollInvite.fromJson(_map(json['invite'], 'invite'));
  }

  Future<void> revokeFriendInvite({
    required String pollId,
    required String inviteId,
  }) async {
    final id = _pathToken(pollId);
    final friend = _pathToken(inviteId);
    await _send(
      'DELETE',
      'polls/$id/invites/$friend',
      authenticated: true,
      expectedStatuses: const {204},
    );
  }

  Future<FinalizedSharePoll> confirmManaged({
    required String pollId,
    required DateTime startsAtUtc,
    required DateTime endsAtUtc,
    required int expectedVersion,
  }) async {
    if (expectedVersion < 1 || !endsAtUtc.isAfter(startsAtUtc)) {
      throw ArgumentError('confirmed time is invalid');
    }
    final id = _pathToken(pollId);
    final json = await _send(
      'POST',
      'polls/$id/confirm',
      body: {
        'startsAt': startsAtUtc.toUtc().toIso8601String(),
        'endsAt': endsAtUtc.toUtc().toIso8601String(),
        'expectedVersion': expectedVersion,
      },
      authenticated: true,
      expectedStatuses: const {200},
    );
    return FinalizedSharePoll(
      pollId: _string(json, 'pollId'),
      version: _integer(json, 'version'),
      selectedSlot: SharePollSlot.fromJson(
        _map(json['selectedSlot'], 'selectedSlot'),
      ),
    );
  }

  Future<SharePollState> get(String publicToken) async {
    final token = _pathToken(publicToken);
    final json = await _send(
      'GET',
      'polls/$token',
      authenticated: false,
      expectedStatuses: const {200},
    );
    return SharePollState.fromJson(json);
  }

  Future<FinalizedSharePoll> finalize({
    required String publicToken,
    required String manageToken,
    required String slotId,
    required int expectedVersion,
  }) async {
    if (expectedVersion < 1) {
      throw ArgumentError('expectedVersion must be positive');
    }
    final token = _pathToken(publicToken);
    final json = await _send(
      'POST',
      'polls/$token/finalize',
      body: {
        'manageToken': _requireToken(manageToken),
        'slotId': _pathToken(slotId),
        'expectedVersion': expectedVersion,
      },
      authenticated: false,
      expectedStatuses: const {200},
    );
    return FinalizedSharePoll(
      pollId: _string(json, 'pollId'),
      version: _integer(json, 'version'),
      selectedSlot: SharePollSlot.fromJson(
        _map(json['selectedSlot'], 'selectedSlot'),
      ),
    );
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    required bool authenticated,
    required Set<int> expectedStatuses,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) headers['authorization'] = 'Bearer $_mobileToken';
    final request = http.Request(method, _apiBaseUri.resolve(path))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const ShareApiException(
        'invalid_response',
        'Server returned invalid JSON',
      );
    }
    if (!expectedStatuses.contains(response.statusCode)) {
      final error = decoded['error'];
      final errorMap = error is Map<String, Object?>
          ? error
          : const <String, Object?>{};
      throw ShareApiException(
        errorMap['code'] as String? ?? 'http_${response.statusCode}',
        errorMap['message'] as String? ?? 'Share service request failed',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void close() => _http.close();
}

class ShareApiException implements Exception {
  const ShareApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ShareApiException($code): $message';
}

Uri _validateBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty) {
    throw ArgumentError(
      'share API must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  return value.path.endsWith('/')
      ? value
      : value.replace(path: '${value.path}/');
}

String _requireToken(String value) {
  if (value.trim().isEmpty) throw ArgumentError('token must not be empty');
  return value;
}

String _pathToken(String value) {
  final token = _requireToken(value);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(token)) {
    throw ArgumentError('invalid opaque identifier');
  }
  return Uri.encodeComponent(token);
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('response field $name must be an object');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('response field $key must be a non-empty string');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('response field $key must be a number');
  }
  return value.toInt();
}
