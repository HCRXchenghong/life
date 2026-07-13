import 'dart:async';

import '../../platform/native_core_service.dart';
import 'codex_app_server_client.dart';

typedef CodexAgentRequest =
    Future<Map<String, Object?>> Function(Map<String, Object?> request);

class AgentCodexAppServerTransport implements CodexAppServerTransport {
  AgentCodexAppServerTransport._({
    required this._request,
    required this._sessionId,
  }) {
    _pumpFuture = _pump();
  }

  static Future<AgentCodexAppServerTransport> start({
    required CodexAgentRequest request,
    required String cwd,
    String? model,
    String approvalPolicy = 'on_risk',
    String sandbox = 'workspace_write',
  }) async {
    if (!cwd.startsWith('/')) {
      throw ArgumentError('Codex working directory must be absolute');
    }
    final response = await request({
      'type': 'codex_start',
      'config': {
        'cwd': cwd,
        'model': model,
        'approval_policy': approvalPolicy,
        'sandbox': sandbox,
        'service_name': 'daylink_mobile',
      },
    });
    if (response['type'] != 'codex_started' ||
        response['session_id'] is! String) {
      throw const CodexProtocolException(
        'agent did not return a Codex session identifier',
      );
    }
    return AgentCodexAppServerTransport._(
      request: request,
      sessionId: response['session_id']! as String,
    );
  }

  factory AgentCodexAppServerTransport.forChannel({
    required NativeAgentChannel channel,
    required String sessionId,
  }) => AgentCodexAppServerTransport._(
    request: channel.requestPayload,
    sessionId: sessionId,
  );

  final CodexAgentRequest _request;
  final String _sessionId;
  final StreamController<Map<String, Object?>> _messages = StreamController();
  late final Future<void> _pumpFuture;
  bool _closing = false;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  Future<void> send(Map<String, Object?> message) async {
    if (_closing) throw StateError('Codex transport is closing');
    final response = await _request({
      'type': 'codex_message',
      'session_id': _sessionId,
      'message': message,
    });
    _expectAcceptedData(response);
  }

  Future<void> _pump() async {
    while (!_closing) {
      try {
        final response = await _request({
          'type': 'codex_next_event',
          'session_id': _sessionId,
          'timeout_ms': 250,
        });
        final value = _dataValue(response);
        if (value['timeout'] == true) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          continue;
        }
        if (!_closing) _messages.add(value);
      } on Object catch (error, stackTrace) {
        if (!_closing) _messages.addError(error, stackTrace);
        break;
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await _pumpFuture;
    try {
      final response = await _request({
        'type': 'codex_stop',
        'session_id': _sessionId,
      });
      _expectAcceptedData(response, expectedKey: 'stopped');
    } finally {
      await _messages.close();
    }
  }
}

Map<String, Object?> _dataValue(Map<String, Object?> response) {
  if (response['type'] != 'data' ||
      response['value'] is! Map<String, Object?>) {
    throw const CodexProtocolException('agent returned invalid Codex data');
  }
  return response['value']! as Map<String, Object?>;
}

void _expectAcceptedData(
  Map<String, Object?> response, {
  String expectedKey = 'accepted',
}) {
  final value = _dataValue(response);
  if (value[expectedKey] != true) {
    throw CodexProtocolException('agent did not acknowledge $expectedKey');
  }
}
