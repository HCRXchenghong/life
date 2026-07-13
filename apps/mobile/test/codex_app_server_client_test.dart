import 'dart:async';

import 'package:daylink_mobile/src/domain/ai/codex_app_server_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'performs handshake and starts a thread with official field names',
    () async {
      final transport = _FakeTransport();
      final client = CodexAppServerClient(
        transport: transport,
        onServerRequest: declineCodexServerRequest,
      );

      await client.initialize();
      final threadId = await client.startThread(cwd: '/workspace');

      expect(threadId, 'thr_test');
      expect(transport.sent[0]['method'], 'initialize');
      expect(transport.sent[1], {
        'method': 'initialized',
        'params': <String, Object?>{},
      });
      final start = transport.sent[2];
      expect(start['method'], 'thread/start');
      final params = start['params']! as Map<String, Object?>;
      expect(params['approvalPolicy'], 'onRequest');
      expect(params['sandbox'], 'workspaceWrite');
      await client.close();
    },
  );

  test('fails closed for approvals and MCP elicitation', () async {
    final transport = _FakeTransport();
    final client = CodexAppServerClient(
      transport: transport,
      onServerRequest: declineCodexServerRequest,
    );
    await client.initialize();

    transport.add({
      'id': 70,
      'method': 'item/commandExecution/requestApproval',
      'params': {'threadId': 'thr_test'},
    });
    transport.add({
      'id': 71,
      'method': 'item/permissions/requestApproval',
      'params': {'threadId': 'thr_test'},
    });
    transport.add({
      'id': 72,
      'method': 'mcpServer/elicitation/request',
      'params': {'threadId': 'thr_test'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(
      transport.sent,
      contains(
        predicate<Map<String, Object?>>((message) {
          return message['id'] == 70 &&
              (message['result'] as Map<String, Object?>?)?['decision'] ==
                  'decline';
        }),
      ),
    );
    expect(
      transport.sent,
      contains(
        predicate<Map<String, Object?>>((message) {
          final result = message['result'] as Map<String, Object?>?;
          return message['id'] == 71 &&
              (result?['permissions'] as List<Object?>?)?.isEmpty == true &&
              result?['scope'] == 'turn';
        }),
      ),
    );
    expect(
      transport.sent,
      contains(
        predicate<Map<String, Object?>>((message) {
          final result = message['result'] as Map<String, Object?>?;
          return message['id'] == 72 && result?['action'] == 'decline';
        }),
      ),
    );
    await client.close();
  });

  test('dynamic tools require the experimental capability', () async {
    final transport = _FakeTransport();
    final client = CodexAppServerClient(
      transport: transport,
      onServerRequest: declineCodexServerRequest,
    );
    await client.initialize();

    expect(
      () => client.startThread(
        cwd: '/workspace',
        dynamicTools: [
          {'name': 'daylink_test'},
        ],
      ),
      throwsStateError,
    );
    await client.close();
  });
}

class _FakeTransport implements CodexAppServerTransport {
  final StreamController<Map<String, Object?>> _messages = StreamController();
  final List<Map<String, Object?>> sent = [];

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  void add(Map<String, Object?> message) => _messages.add(message);

  @override
  Future<void> send(Map<String, Object?> message) async {
    sent.add(message);
    final id = message['id'];
    final method = message['method'];
    if (id is! int) return;
    if (method == 'initialize') {
      scheduleMicrotask(() => add({'id': id, 'result': <String, Object?>{}}));
    } else if (method == 'thread/start') {
      scheduleMicrotask(
        () => add({
          'id': id,
          'result': {
            'thread': {'id': 'thr_test'},
          },
        }),
      );
    }
  }

  @override
  Future<void> close() => _messages.close();
}
