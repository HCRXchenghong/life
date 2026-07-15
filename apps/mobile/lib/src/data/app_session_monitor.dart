import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef AccessTokenProvider = Future<String?> Function();
typedef SessionRefreshCallback = Future<bool> Function();
typedef SessionActionCallback = Future<void> Function();
typedef ForcedSignOutCallback = Future<void> Function(String reason);

/// Keeps one authenticated App account attached to its account-scoped SSE
/// stream. It never logs tokens or event payloads.
class AppSessionMonitor {
  factory AppSessionMonitor({
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
    required ForcedSignOutCallback onForcedSignOut,
    SessionActionCallback? onChanges,
    http.Client? httpClient,
    http.Client Function()? streamClientFactory,
    Duration reconnectDelay = const Duration(seconds: 2),
  }) {
    final baseUri = _validateBaseUri(apiBaseUri);
    final requestClient = httpClient ?? http.Client();
    return AppSessionMonitor._(
      baseUri.resolve('sync/events'),
      baseUri.resolve('app/auth/session'),
      accessToken,
      refreshAccessToken,
      clearCredentials,
      onForcedSignOut,
      onChanges,
      requestClient,
      streamClientFactory ??
          (httpClient == null ? () => http.Client() : () => requestClient),
      reconnectDelay,
    );
  }

  AppSessionMonitor._(
    this._eventsUri,
    this._sessionUri,
    this._accessToken,
    this._refreshAccessToken,
    this._clearCredentials,
    this._onForcedSignOut,
    this._onChanges,
    this._requestHttp,
    this._streamClientFactory,
    this._reconnectDelay,
  );

  final Uri _eventsUri;
  final Uri _sessionUri;
  final AccessTokenProvider _accessToken;
  final SessionRefreshCallback _refreshAccessToken;
  final SessionActionCallback _clearCredentials;
  final ForcedSignOutCallback _onForcedSignOut;
  final SessionActionCallback? _onChanges;
  final http.Client _requestHttp;
  final http.Client Function() _streamClientFactory;
  final Duration _reconnectDelay;

  bool _closed = false;
  bool _signedOut = false;
  bool _started = false;
  http.Client? _activeStreamHttp;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    while (!_closed) {
      String? token;
      try {
        token = await _accessToken();
      } on Object {
        await _waitBeforeReconnect();
        continue;
      }
      if (!_validAccessToken(token)) {
        await _forceSignOut('session_revoked');
        return;
      }
      final streamHttp = _streamClientFactory();
      _activeStreamHttp = streamHttp;
      try {
        final request = http.Request('GET', _eventsUri)
          ..headers.addAll({
            'accept': 'text/event-stream',
            'authorization': 'Bearer $token',
            'cache-control': 'no-cache',
          });
        final response = await streamHttp
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (_closed) return;
        if (response.statusCode == 401) {
          await response.stream.listen((_) {}).cancel();
          final refreshed = await _refreshAccessToken();
          if (!refreshed) {
            await _forceSignOut('session_revoked');
            return;
          }
          continue;
        }
        if (response.statusCode != 200 ||
            !response.headers['content-type']
                .toString()
                .toLowerCase()
                .startsWith('text/event-stream')) {
          await response.stream.listen((_) {}).cancel();
          await _waitBeforeReconnect();
          continue;
        }
        await _consume(response.stream.timeout(const Duration(seconds: 45)));
      } on Object {
        // Transport, refresh, and malformed event failures reconnect without
        // changing auth state. Only an explicit 401 rejection or revocation
        // event may force sign-out.
      } finally {
        if (identical(_activeStreamHttp, streamHttp)) {
          _activeStreamHttp = null;
        }
        streamHttp.close();
      }
      if (!_closed) await _waitBeforeReconnect();
    }
  }

  Future<void> _consume(Stream<List<int>> stream) async {
    String eventName = '';
    final data = StringBuffer();
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (_closed) return;
      if (line.isEmpty) {
        await _dispatch(eventName, data.toString());
        eventName = '';
        data.clear();
        if (_closed) return;
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:') && data.length < 8192) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
    }
  }

  Future<void> _dispatch(String eventName, String data) async {
    if (eventName == 'changes') {
      try {
        await _onChanges?.call();
      } on Object {
        // A sync failure is reconciled after reconnect and must not sign out.
      }
      return;
    }
    if (eventName != 'session_revoked') return;
    var reason = 'session_revoked';
    if (data.isNotEmpty && data.length <= 8192) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, Object?>) {
          reason = _safeReason(decoded['reason']);
        }
      } on FormatException {
        // The event type itself is authoritative; malformed data only loses
        // the optional user-facing reason.
      }
    }
    await _forceSignOut(reason);
  }

  Future<void> _forceSignOut(String reason) async {
    if (_signedOut) return;
    _signedOut = true;
    _closed = true;
    _activeStreamHttp?.close();
    _requestHttp.close();
    try {
      await _clearCredentials();
    } finally {
      await _onForcedSignOut(_safeReason(reason));
    }
  }

  Future<void> _waitBeforeReconnect() async {
    if (_closed || _reconnectDelay == Duration.zero) return;
    await Future<void>.delayed(_reconnectDelay);
  }

  /// Revalidates immediately when the App returns to the foreground, covering
  /// mobile OS suspension where an SSE socket may not have run in background.
  Future<void> reconcile() async {
    if (_closed) return;
    try {
      final token = await _accessToken();
      if (!_validAccessToken(token)) {
        await _forceSignOut('session_revoked');
        return;
      }
      final request = http.Request('GET', _sessionUri)
        ..headers.addAll({
          'accept': 'application/json',
          'authorization': 'Bearer $token',
        });
      final response = await _requestHttp
          .send(request)
          .timeout(const Duration(seconds: 15));
      await response.stream.listen((_) {}).cancel();
      if (response.statusCode == 401) {
        if (!await _refreshAccessToken()) {
          await _forceSignOut('session_revoked');
        } else {
          // The refresh endpoint rotates and revokes the old DB session. Close
          // its SSE transport before the server's revocation fallback arrives,
          // then let the loop reconnect with the rotated access token.
          _activeStreamHttp?.close();
        }
      }
    } on Object {
      // Offline foregrounding is not an authentication failure. The SSE loop
      // and next resume retry without clearing local credentials.
    }
  }

  /// Cancellation is deliberately non-blocking so a forced-sign-out callback
  /// can close its own runtime without awaiting the monitor's current loop.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _activeStreamHttp?.close();
    _requestHttp.close();
  }
}

Uri _validateBaseUri(Uri value) {
  final loopback = value.host == '127.0.0.1' || value.host == 'localhost';
  if ((!value.isScheme('https') && !(loopback && value.isScheme('http'))) ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.query.isNotEmpty ||
      value.fragment.isNotEmpty) {
    throw ArgumentError(
      'session API must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  return value.path.endsWith('/')
      ? value
      : value.replace(path: '${value.path}/');
}

bool _validAccessToken(String? value) =>
    value != null &&
    value.startsWith('dlka_') &&
    value.length <= 300 &&
    !value.contains(RegExp(r'[\x00-\x20\x7f]'));

String _safeReason(Object? value) => switch (value) {
  'account_disabled' => 'account_disabled',
  'credentials_changed' => 'credentials_changed',
  _ => 'session_revoked',
};
