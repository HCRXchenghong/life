import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

const _spec = ToolSpec(
  name: 'daylink_write_test',
  description: 'Test a mutating tool.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'value': {'type': 'string'},
      'options': {
        'type': 'array',
        'maxItems': 2,
        'items': {'type': 'integer', 'minimum': 1, 'maximum': 5},
      },
    },
    'required': ['value'],
    'additionalProperties': false,
  },
  risk: ToolRisk.high,
  approval: ToolApprovalPolicy.always,
  sandbox: ToolSandbox.localData,
);

void main() {
  test('session approval is reused only for the same tool', () async {
    var approvals = 0;
    var executions = 0;
    final registry =
        ToolRegistry(
          approvals: (_, _) async {
            approvals++;
            return ApprovalDecision.acceptForSession;
          },
        )..register(_spec, (arguments) async {
          executions++;
          return {'value': arguments['value']};
        });

    final first = await registry.invoke(
      const ToolCall(
        callId: 'call-1',
        name: 'daylink_write_test',
        arguments: {'value': 'a'},
      ),
    );
    final second = await registry.invoke(
      const ToolCall(
        callId: 'call-2',
        name: 'daylink_write_test',
        arguments: {'value': 'b'},
      ),
    );

    expect(first.success, isTrue);
    expect(second.success, isTrue);
    expect(approvals, 1);
    expect(executions, 2);
  });

  test('invalid arguments fail before approval or execution', () async {
    var approved = false;
    var executed = false;
    final registry =
        ToolRegistry(
          approvals: (_, _) async {
            approved = true;
            return ApprovalDecision.accept;
          },
        )..register(_spec, (_) async {
          executed = true;
          return null;
        });

    final result = await registry.invoke(
      const ToolCall(
        callId: 'call-invalid',
        name: 'daylink_write_test',
        arguments: {'value': 'ok', 'unexpected': true},
      ),
    );

    expect(result.success, isFalse);
    expect(result.redacted, isTrue);
    expect(approved, isFalse);
    expect(executed, isFalse);
  });

  test('decline returns a stable machine-readable result', () async {
    final registry = ToolRegistry(
      approvals: (_, _) async => ApprovalDecision.decline,
    )..register(_spec, (_) async => throw StateError('must not run'));

    final result = await registry.invoke(
      const ToolCall(
        callId: 'call-decline',
        name: 'daylink_write_test',
        arguments: {'value': 'no'},
      ),
    );

    expect(result.success, isFalse);
    expect(result.output, {'code': 'declined'});
  });

  test(
    'recursively validates types, array bounds, and numeric ranges',
    () async {
      var executed = false;
      final registry =
          ToolRegistry(approvals: (_, _) async => ApprovalDecision.accept)
            ..register(_spec, (_) async {
              executed = true;
              return null;
            });

      final result = await registry.invoke(
        const ToolCall(
          callId: 'call-invalid-nested',
          name: 'daylink_write_test',
          arguments: {
            'value': 'safe',
            'options': [1, 9],
          },
        ),
      );

      expect(result.success, isFalse);
      expect(executed, isFalse);
    },
  );
}
