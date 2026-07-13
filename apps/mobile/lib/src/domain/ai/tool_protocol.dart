import 'dart:async';

enum ToolRisk { readOnly, low, medium, high, critical }

enum ToolApprovalPolicy { never, onRisk, always }

enum ToolSandbox { readOnly, localData, remoteHost }

enum ApprovalDecision { accept, acceptForSession, decline, cancel }

class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.risk,
    required this.approval,
    required this.sandbox,
    this.timeout = const Duration(seconds: 30),
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final ToolRisk risk;
  final ToolApprovalPolicy approval;
  final ToolSandbox sandbox;
  final Duration timeout;

  Map<String, Object?> toResponsesTool() => {
    'type': 'function',
    'name': name,
    'description': description,
    'strict': true,
    'parameters': inputSchema,
  };
}

class ToolCall {
  const ToolCall({
    required this.callId,
    required this.name,
    required this.arguments,
  });
  final String callId;
  final String name;
  final Map<String, Object?> arguments;
}

class ToolResult {
  const ToolResult({
    required this.callId,
    required this.success,
    required this.output,
    this.redacted = false,
  });
  final String callId;
  final bool success;
  final Object? output;
  final bool redacted;
}

typedef ToolHandler = Future<Object?> Function(Map<String, Object?> arguments);
typedef ApprovalDelegate =
    Future<ApprovalDecision> Function(ToolSpec spec, ToolCall call);

class ToolRegistry {
  ToolRegistry({required this._approvals});

  final ApprovalDelegate _approvals;
  final Map<String, (ToolSpec, ToolHandler)> _tools = {};
  final Set<String> _sessionApprovals = {};

  List<ToolSpec> get specs =>
      _tools.values.map((entry) => entry.$1).toList(growable: false);

  void register(ToolSpec spec, ToolHandler handler) {
    if (_tools.containsKey(spec.name)) {
      throw StateError('Duplicate tool ${spec.name}');
    }
    _tools[spec.name] = (spec, handler);
  }

  Future<ToolResult> invoke(ToolCall call) async {
    final entry = _tools[call.name];
    if (entry == null) {
      return ToolResult(
        callId: call.callId,
        success: false,
        output: {'code': 'tool_not_found'},
      );
    }
    final (spec, handler) = entry;
    try {
      _validateArguments(spec.inputSchema, call.arguments);
      if (_needsApproval(spec) && !_sessionApprovals.contains(spec.name)) {
        final decision = await _approvals(spec, call);
        if (decision == ApprovalDecision.acceptForSession) {
          _sessionApprovals.add(spec.name);
        }
        if (decision == ApprovalDecision.decline ||
            decision == ApprovalDecision.cancel) {
          return ToolResult(
            callId: call.callId,
            success: false,
            output: {
              'code': decision == ApprovalDecision.cancel
                  ? 'cancelled'
                  : 'declined',
            },
          );
        }
      }
      final output = await handler(call.arguments).timeout(spec.timeout);
      return ToolResult(callId: call.callId, success: true, output: output);
    } on TimeoutException {
      return ToolResult(
        callId: call.callId,
        success: false,
        output: {'code': 'timeout'},
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.callId,
        success: false,
        output: {'code': 'tool_failed', 'message': error.toString()},
        redacted: spec.risk.index >= ToolRisk.high.index,
      );
    }
  }

  bool _needsApproval(ToolSpec spec) => switch (spec.approval) {
    ToolApprovalPolicy.never => false,
    ToolApprovalPolicy.always => true,
    ToolApprovalPolicy.onRisk => spec.risk.index >= ToolRisk.medium.index,
  };

  void _validateArguments(
    Map<String, Object?> schema,
    Map<String, Object?> arguments,
  ) {
    _validateValue(r'$', schema, arguments);
  }

  void _validateValue(String path, Map<String, Object?> schema, Object? value) {
    final allowed = schema['enum'];
    if (allowed is List<Object?> && !allowed.contains(value)) {
      throw FormatException('$path is not an allowed value');
    }
    final type = schema['type'];
    if (type is String && !_hasType(value, type)) {
      throw FormatException('$path must be $type');
    }
    if (value is String) {
      final minimum = (schema['minLength'] as num?)?.toInt();
      final maximum = (schema['maxLength'] as num?)?.toInt();
      if (minimum != null && value.length < minimum) {
        throw FormatException('$path is shorter than $minimum characters');
      }
      if (maximum != null && value.length > maximum) {
        throw FormatException('$path is longer than $maximum characters');
      }
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) {
        throw FormatException('$path has an invalid format');
      }
    }
    if (value is num) {
      final minimum = schema['minimum'] as num?;
      final maximum = schema['maximum'] as num?;
      if (minimum != null && value < minimum) {
        throw FormatException('$path must be at least $minimum');
      }
      if (maximum != null && value > maximum) {
        throw FormatException('$path must be at most $maximum');
      }
    }
    if (value is List<Object?>) {
      final minimum = (schema['minItems'] as num?)?.toInt();
      final maximum = (schema['maxItems'] as num?)?.toInt();
      if (minimum != null && value.length < minimum) {
        throw FormatException('$path has fewer than $minimum items');
      }
      if (maximum != null && value.length > maximum) {
        throw FormatException('$path has more than $maximum items');
      }
      final itemSchema = schema['items'];
      if (itemSchema is Map<String, Object?>) {
        for (var index = 0; index < value.length; index++) {
          _validateValue('$path[$index]', itemSchema, value[index]);
        }
      }
    }
    if (value is Map<String, Object?>) {
      final properties = schema['properties'] is Map<String, Object?>
          ? schema['properties']! as Map<String, Object?>
          : const <String, Object?>{};
      final required = schema['required'] is List<Object?>
          ? (schema['required']! as List<Object?>).cast<String>()
          : const <String>[];
      for (final field in required) {
        if (!value.containsKey(field) || value[field] == null) {
          throw FormatException('Missing required tool argument: $path.$field');
        }
      }
      if (schema['additionalProperties'] == false) {
        final unknown = value.keys.where((key) => !properties.containsKey(key));
        if (unknown.isNotEmpty) {
          throw FormatException(
            'Unknown tool argument: $path.${unknown.first}',
          );
        }
      }
      for (final entry in value.entries) {
        final propertySchema = properties[entry.key];
        if (propertySchema is Map<String, Object?>) {
          _validateValue('$path.${entry.key}', propertySchema, entry.value);
        }
      }
    }
  }
}

bool _hasType(Object? value, String type) => switch (type) {
  'object' => value is Map<String, Object?>,
  'array' => value is List<Object?>,
  'string' => value is String,
  'integer' =>
    value is int ||
        value is double && value.isFinite && value == value.roundToDouble(),
  'number' => value is num && value.isFinite,
  'boolean' => value is bool,
  'null' => value == null,
  _ => throw FormatException('unsupported tool schema type: $type'),
};
