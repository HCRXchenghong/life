import 'dart:async';

/// Transport supplied by the Rust core. On remote hosts it is backed by an SSH
/// channel running `codex app-server` (stdio is the default); on a trusted TLS endpoint
/// it may be backed by a WebSocket.
abstract interface class CodexAppServerTransport {
  Stream<Map<String, Object?>> get messages;
  Future<void> send(Map<String, Object?> message);
  Future<void> close();
}

typedef CodexServerRequestHandler =
    Future<Map<String, Object?>> Function(
      String method,
      Map<String, Object?> params,
    );

class CodexAppServerClient {
  CodexAppServerClient({
    required this._transport,
    required this._onServerRequest,
  });

  final CodexAppServerTransport _transport;
  final CodexServerRequestHandler _onServerRequest;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();
  StreamSubscription<Map<String, Object?>>? _subscription;
  var _nextId = 1;
  bool _initialized = false;
  bool _experimentalApi = false;

  Stream<Map<String, Object?>> get events => _events.stream;

  Future<void> initialize({
    String clientName = 'daylink_mobile',
    String clientTitle = 'Daylink',
    String version = '0.1.0',
    bool experimentalApi = false,
  }) async {
    if (_initialized) return;
    _subscription = _transport.messages.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        for (final completer in _pending.values) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
        _pending.clear();
      },
    );
    await _request('initialize', {
      'clientInfo': {
        'name': clientName,
        'title': clientTitle,
        'version': version,
      },
      'capabilities': {'experimentalApi': experimentalApi},
    });
    await _transport.send({
      'method': 'initialized',
      'params': <String, Object?>{},
    });
    _experimentalApi = experimentalApi;
    _initialized = true;
  }

  Future<String> startThread({
    required String cwd,
    String? model,
    String approvalPolicy = 'onRequest',
    String sandbox = 'workspaceWrite',
    String personality = 'friendly',
    List<Map<String, Object?>> dynamicTools = const [],
  }) async {
    _requireInitialized();
    if (dynamicTools.isNotEmpty && !_experimentalApi) {
      throw StateError(
        'Codex dynamic tools require initialize(experimentalApi: true)',
      );
    }
    final result = await _request('thread/start', {
      'cwd': cwd,
      'model': ?model,
      'approvalPolicy': approvalPolicy,
      'sandbox': sandbox,
      'personality': personality,
      'serviceName': 'daylink_mobile',
      if (dynamicTools.isNotEmpty) 'dynamicTools': dynamicTools,
    });
    final thread = result['thread'] as Map<String, Object?>?;
    final id = thread?['id'] as String?;
    if (id == null) {
      throw const CodexProtocolException('thread/start returned no thread id');
    }
    return id;
  }

  Future<void> startTurn({
    required String threadId,
    required String text,
  }) async {
    _requireInitialized();
    await _request('turn/start', {
      'threadId': threadId,
      'input': [
        {'type': 'text', 'text': text},
      ],
    });
  }

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    _requireInitialized();
    await _request('turn/interrupt', {'threadId': threadId, 'turnId': turnId});
  }

  Future<Map<String, Object?>> _request(
    String method,
    Map<String, Object?> params,
  ) async {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    await _transport.send({'id': id, 'method': method, 'params': params});
    try {
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      _pending.remove(id);
    }
  }

  void _handleMessage(Map<String, Object?> message) {
    final id = message['id'];
    final method = message['method'];
    if (id is num && method == null) {
      final completer = _pending[id.toInt()];
      if (completer == null) return;
      if (message['error'] != null) {
        completer.completeError(
          CodexProtocolException(message['error'].toString()),
        );
      } else {
        completer.complete(
          (message['result'] as Map<String, Object?>?) ?? const {},
        );
      }
      return;
    }
    if (id != null && method is String) {
      unawaited(_answerServerRequest(id, method, message['params']));
      return;
    }
    if (method is String) _events.add(message);
  }

  Future<void> _answerServerRequest(
    Object id,
    String method,
    Object? rawParams,
  ) async {
    final params = rawParams is Map<String, Object?>
        ? rawParams
        : <String, Object?>{};
    try {
      final result = await _onServerRequest(method, params);
      await _transport.send({'id': id, 'result': result});
    } on Object catch (error) {
      await _transport.send({
        'id': id,
        'error': {'code': -32000, 'message': error.toString()},
      });
    }
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError('Codex app-server client is not initialized');
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _events.close();
    await _transport.close();
  }
}

class CodexProtocolException implements Exception {
  const CodexProtocolException(this.message);
  final String message;
  @override
  String toString() => 'CodexProtocolException: $message';
}

/// Safe default for clients that have not yet attached an approval surface.
Future<Map<String, Object?>> declineCodexServerRequest(
  String method,
  Map<String, Object?> params,
) async {
  if (method == 'item/permissions/requestApproval') {
    return {'permissions': <Object?>[], 'scope': 'turn'};
  }
  if (method == 'mcpServer/elicitation/request') {
    return {'action': 'decline', 'content': null};
  }
  return {'decision': 'decline'};
}
