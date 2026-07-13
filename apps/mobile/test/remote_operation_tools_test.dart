import 'package:daylink_mobile/src/application/remote_operation_tools.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'read tools execute without approval and redact remote secrets',
    () async {
      var approvals = 0;
      Map<String, Object?>? request;
      final registry = ToolRegistry(
        approvals: (_, _) async {
          approvals++;
          return ApprovalDecision.accept;
        },
      );
      RemoteOperationTools(
        request: (value) async {
          request = value;
          return {
            'type': 'data',
            'value': {
              'authorization': 'Bearer should-never-leak',
              'status': 'ok',
            },
          };
        },
      ).register(registry);

      final result = await registry.invoke(
        const ToolCall(
          callId: 'read-1',
          name: 'daylink_system_info',
          arguments: {},
        ),
      );

      expect(result.success, isTrue);
      expect(approvals, 0);
      expect(request, {'type': 'system_info'});
      expect(result.output.toString(), isNot(contains('should-never-leak')));
    },
  );

  test(
    'mutating tools require approval and inject a non-model approval id',
    () async {
      Map<String, Object?>? request;
      final registry = ToolRegistry(
        approvals: (_, _) async => ApprovalDecision.accept,
      );
      RemoteOperationTools(
        request: (value) async {
          request = value;
          return {
            'type': 'data',
            'value': {'success': true},
          };
        },
      ).register(registry);

      final result = await registry.invoke(
        const ToolCall(
          callId: 'write-1',
          name: 'daylink_command_run',
          arguments: {
            'argv': ['uptime'],
            'cwd': '/home/daylink',
            'timeout_ms': 5000,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(request?['type'], 'command_run');
      expect(
        request?['approval_id'],
        isA<String>().having((v) => v, 'value', isNotEmpty),
      );
    },
  );

  test('invalid remote arguments fail before reaching the agent', () async {
    var reachedAgent = false;
    final registry = ToolRegistry(
      approvals: (_, _) async => ApprovalDecision.accept,
    );
    RemoteOperationTools(
      request: (_) async {
        reachedAgent = true;
        return const {};
      },
    ).register(registry);

    final result = await registry.invoke(
      const ToolCall(
        callId: 'bad-path',
        name: 'daylink_file_read',
        arguments: {'path': '../etc/passwd', 'offset': 0, 'length': 70000},
      ),
    );

    expect(result.success, isFalse);
    expect(reachedAgent, isFalse);
  });
}
