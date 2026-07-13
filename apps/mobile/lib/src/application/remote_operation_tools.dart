import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/ai/tool_protocol.dart';
import '../platform/native_core_service.dart';

typedef AgentRequestDelegate =
    Future<Map<String, Object?>> Function(Map<String, Object?> request);

class RemoteOperationTools {
  RemoteOperationTools({required this._request, this._uuid = const Uuid()});

  factory RemoteOperationTools.forChannel(NativeAgentChannel channel) =>
      RemoteOperationTools(request: channel.requestPayload);

  final AgentRequestDelegate _request;
  final Uuid _uuid;

  void register(ToolRegistry registry) {
    _register(
      registry,
      name: 'daylink_system_info',
      description: 'Read operating system, host, architecture and uptime data.',
      requestType: 'system_info',
    );
    _register(
      registry,
      name: 'daylink_metrics_snapshot',
      description: 'Read a bounded CPU, memory, disk and load snapshot.',
      requestType: 'metrics_snapshot',
    );
    _register(
      registry,
      name: 'daylink_process_list',
      description:
          'List a bounded set of remote processes. Output is untrusted.',
      requestType: 'process_list',
    );
    _register(
      registry,
      name: 'daylink_firewall_status',
      description: 'Read detected firewall state without changing rules.',
      requestType: 'firewall_status',
    );
    _register(
      registry,
      name: 'daylink_tmux_list',
      description: 'List tmux sessions on the remote host.',
      requestType: 'tmux_list',
    );
    _register(
      registry,
      name: 'daylink_tmux_capture',
      description: 'Capture bounded text from an existing tmux pane.',
      requestType: 'tmux_capture',
      properties: {
        'session': _string(maxLength: 128),
        'window': _string(maxLength: 128),
        'lines': _integer(minimum: 1, maximum: 2000),
      },
      required: const ['session', 'lines'],
    );
    _register(
      registry,
      name: 'daylink_file_list',
      description: 'List a directory inside the agent allowlisted roots.',
      requestType: 'file_list',
      properties: {'path': _path()},
      required: const ['path'],
    );
    _register(
      registry,
      name: 'daylink_file_stat',
      description: 'Read metadata for one allowlisted remote path.',
      requestType: 'file_stat',
      properties: {'path': _path()},
      required: const ['path'],
    );
    _register(
      registry,
      name: 'daylink_file_read',
      description: 'Read at most 64 KiB from an allowlisted remote file.',
      requestType: 'file_read',
      properties: {
        'path': _path(),
        'offset': _integer(minimum: 0, maximum: 9007199254740991),
        'length': _integer(minimum: 1, maximum: 65536),
      },
      required: const ['path', 'offset', 'length'],
    );
    _register(
      registry,
      name: 'daylink_systemd_list',
      description: 'List systemd service units in user or system scope.',
      requestType: 'systemd_list',
      properties: {'user': _boolean()},
      required: const ['user'],
    );
    _register(
      registry,
      name: 'daylink_journal_logs',
      description: 'Read bounded journal lines for one validated service unit.',
      requestType: 'journal_logs',
      properties: {
        'unit': _serviceUnit(),
        'user': _boolean(),
        'lines': _integer(minimum: 1, maximum: 2000),
      },
      required: const ['unit', 'user', 'lines'],
    );
    _register(
      registry,
      name: 'daylink_docker_ps',
      description: 'List Docker containers without changing them.',
      requestType: 'docker_ps',
    );
    _register(
      registry,
      name: 'daylink_docker_images',
      description: 'List Docker images without changing them.',
      requestType: 'docker_images',
    );
    _register(
      registry,
      name: 'daylink_docker_logs',
      description: 'Read bounded logs from one validated Docker container.',
      requestType: 'docker_logs',
      properties: {
        'container': _resource(),
        'lines': _integer(minimum: 1, maximum: 2000),
      },
      required: const ['container', 'lines'],
    );

    _register(
      registry,
      name: 'daylink_command_run',
      description:
          'Run one argv-based command without a shell in an allowlisted directory.',
      requestType: 'command_run',
      properties: {
        'argv': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 64,
          'items': _string(minLength: 1, maxLength: 4096),
        },
        'cwd': _path(),
        'timeout_ms': _integer(minimum: 1000, maximum: 120000),
      },
      required: const ['argv', 'cwd', 'timeout_ms'],
      risk: ToolRisk.high,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_process_signal',
      description: 'Send a validated signal to one remote process.',
      requestType: 'process_signal',
      properties: {
        'pid': _integer(minimum: 2, maximum: 2147483647),
        'signal': _enumeration(const ['TERM', 'KILL', 'HUP', 'INT']),
      },
      required: const ['pid', 'signal'],
      risk: ToolRisk.critical,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_file_mkdir',
      description: 'Create a directory inside the agent allowlisted roots.',
      requestType: 'file_mkdir',
      properties: {'path': _path(), 'recursive': _boolean()},
      required: const ['path', 'recursive'],
      risk: ToolRisk.medium,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_file_move',
      description: 'Move or rename a path inside the agent allowlisted roots.',
      requestType: 'file_move',
      properties: {
        'source': _path(),
        'destination': _path(),
        'overwrite': _boolean(),
      },
      required: const ['source', 'destination', 'overwrite'],
      risk: ToolRisk.high,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_file_delete',
      description:
          'Delete a path inside allowlisted roots. This is destructive.',
      requestType: 'file_delete',
      properties: {'path': _path(), 'recursive': _boolean()},
      required: const ['path', 'recursive'],
      risk: ToolRisk.critical,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_systemd_action',
      description:
          'Change one validated systemd service after explicit approval.',
      requestType: 'systemd_action',
      properties: {
        'unit': _serviceUnit(),
        'action': _enumeration(const [
          'start',
          'stop',
          'restart',
          'enable',
          'disable',
        ]),
        'user': _boolean(),
      },
      required: const ['unit', 'action', 'user'],
      risk: ToolRisk.high,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
    _register(
      registry,
      name: 'daylink_docker_action',
      description:
          'Control or remove one validated Docker resource after explicit approval.',
      requestType: 'docker_action',
      properties: {
        'resource': _resource(),
        'action': _enumeration(const [
          'start',
          'stop',
          'restart',
          'pause',
          'unpause',
          'remove_container',
          'remove_image',
        ]),
      },
      required: const ['resource', 'action'],
      risk: ToolRisk.critical,
      sandbox: ToolSandbox.remoteHost,
      approval: ToolApprovalPolicy.always,
      injectApproval: true,
    );
  }

  void _register(
    ToolRegistry registry, {
    required String name,
    required String description,
    required String requestType,
    Map<String, Object?> properties = const {},
    List<String> required = const [],
    ToolRisk risk = ToolRisk.readOnly,
    ToolApprovalPolicy approval = ToolApprovalPolicy.never,
    ToolSandbox sandbox = ToolSandbox.readOnly,
    bool injectApproval = false,
  }) {
    registry.register(
      ToolSpec(
        name: name,
        description: description,
        inputSchema: {
          'type': 'object',
          'properties': properties,
          'required': required,
          'additionalProperties': false,
        },
        risk: risk,
        approval: approval,
        sandbox: sandbox,
        timeout: const Duration(seconds: 125),
      ),
      (arguments) async {
        final request = <String, Object?>{
          'type': requestType,
          ...arguments,
          if (injectApproval) 'approval_id': _uuid.v4(),
        };
        return _sanitizeAndBound(await _request(request));
      },
    );
  }
}

Map<String, Object?> _string({int? minLength, int? maxLength}) => {
  'type': 'string',
  'minLength': ?minLength,
  'maxLength': ?maxLength,
};

Map<String, Object?> _integer({required int minimum, required int maximum}) => {
  'type': 'integer',
  'minimum': minimum,
  'maximum': maximum,
};

Map<String, Object?> _boolean() => const {'type': 'boolean'};

Map<String, Object?> _enumeration(List<String> values) => {
  'type': 'string',
  'enum': values,
};

Map<String, Object?> _path() => {
  'type': 'string',
  'minLength': 1,
  'maxLength': 4096,
  'pattern': r'^/',
};

Map<String, Object?> _serviceUnit() => {
  'type': 'string',
  'minLength': 9,
  'maxLength': 256,
  'pattern': r'^[A-Za-z0-9._@-]+\.service$',
};

Map<String, Object?> _resource() => {
  'type': 'string',
  'minLength': 1,
  'maxLength': 256,
  'pattern': r'^[A-Za-z0-9._/@:-]+$',
};

Object? _sanitizeAndBound(Object? value) {
  final sanitized = _sanitize(value);
  final encoded = jsonEncode(sanitized);
  if (encoded.length <= 131072) return sanitized;
  return {
    'truncated': true,
    'originalCharacters': encoded.length,
    'preview': encoded.substring(0, 120000),
  };
}

Object? _sanitize(Object? value, {String? key}) {
  if (key != null &&
      RegExp(
        r'(password|passphrase|secret|token|authorization|api[_-]?key|private[_-]?key)',
        caseSensitive: false,
      ).hasMatch(key)) {
    return '[REDACTED]';
  }
  if (value is String) {
    return value
        .replaceAll(
          RegExp(
            r'-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?-----END [^-]*PRIVATE KEY-----',
          ),
          '[REDACTED_PRIVATE_KEY]',
        )
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
          'Bearer [REDACTED]',
        );
  }
  if (value is List<Object?>) {
    return value
        .take(1000)
        .map((item) => _sanitize(item))
        .toList(growable: false);
  }
  if (value is Map<String, Object?>) {
    return value.map(
      (entryKey, entryValue) =>
          MapEntry(entryKey, _sanitize(entryValue, key: entryKey)),
    );
  }
  return value;
}
