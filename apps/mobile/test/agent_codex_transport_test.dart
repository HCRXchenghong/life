import 'package:daylink_mobile/src/domain/ai/agent_codex_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bridges Codex JSON-RPC messages through the agent and stops cleanly',
    () async {
      final requests = <Map<String, Object?>>[];
      var delivered = false;
      var stopped = false;
      final transport = await AgentCodexAppServerTransport.start(
        request: (request) async {
          requests.add(request);
          switch (request['type']) {
            case 'codex_start':
              return {
                'type': 'codex_started',
                'session_id': '11111111-1111-4111-8111-111111111111',
              };
            case 'codex_message':
              return {
                'type': 'data',
                'value': {'accepted': true},
              };
            case 'codex_next_event':
              if (!delivered) {
                delivered = true;
                return {
                  'type': 'data',
                  'value': {
                    'id': 1,
                    'result': {'ready': true},
                  },
                };
              }
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return {
                'type': 'data',
                'value': {'timeout': true},
              };
            case 'codex_stop':
              stopped = true;
              return {
                'type': 'data',
                'value': {'stopped': true},
              };
          }
          throw StateError('unexpected request');
        },
        cwd: '/home/daylink/project',
      );
      final firstMessage = transport.messages.first;

      await transport.send({
        'id': 1,
        'method': 'initialize',
        'params': <String, Object?>{},
      });
      expect(await firstMessage, {
        'id': 1,
        'result': {'ready': true},
      });
      await transport.close();

      expect(stopped, isTrue);
      expect(requests.first['type'], 'codex_start');
      expect(
        requests.any((request) => request['type'] == 'codex_message'),
        isTrue,
      );
    },
  );

  test('rejects relative Codex working directories before agent access', () {
    var called = false;
    expect(
      () => AgentCodexAppServerTransport.start(
        request: (_) async {
          called = true;
          return const {};
        },
        cwd: '../project',
      ),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });
}
