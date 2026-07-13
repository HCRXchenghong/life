import 'dart:convert';
import 'dart:typed_data';

import '../rust/api/mobile.dart' as rust;
import '../rust/frb_generated.dart';

sealed class SshCredential {
  const SshCredential();
}

class PasswordCredential extends SshCredential {
  const PasswordCredential(this.password);
  final String password;
}

class PrivateKeyCredential extends SshCredential {
  const PrivateKeyCredential(this.pem, {this.passphrase});
  final String pem;
  final String? passphrase;
}

class NativeHostKey {
  const NativeHostKey({
    required this.algorithm,
    required this.fingerprintSha256,
  });
  final String algorithm;
  final String fingerprintSha256;
}

class NativeCommandOutput {
  const NativeCommandOutput({
    required this.stdout,
    required this.stderr,
    required this.exitStatus,
  });
  final Uint8List stdout;
  final Uint8List stderr;
  final int? exitStatus;
}

class NativeAgentInstallResult {
  const NativeAgentInstallResult({
    required this.version,
    required this.remotePath,
    required this.sha256,
  });

  final String version;
  final String remotePath;
  final String sha256;
}

class NativeCoreService {
  NativeCoreService._(this.apiVersion);

  final String apiVersion;

  static Future<NativeCoreService> initialize() async {
    await RustLib.init();
    final version = await rust.coreApiVersion();
    if (version.trim().isEmpty) {
      throw StateError('Rust mobile core returned an empty API version');
    }
    return NativeCoreService._(version);
  }

  Future<NativeHostKey> probeHostKey({
    required String host,
    int port = 22,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final key = await rust.probeHostKeyMobile(
      host: host,
      port: port,
      timeoutMs: BigInt.from(timeout.inMilliseconds),
    );
    return NativeHostKey(
      algorithm: key.algorithm,
      fingerprintSha256: key.fingerprintSha256,
    );
  }

  Future<NativeSshConnection> connect({
    required String host,
    int port = 22,
    required String username,
    required String acceptedHostKeySha256,
    required SshCredential credential,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration inactivityTimeout = const Duration(minutes: 2),
  }) async {
    final authentication = switch (credential) {
      PasswordCredential(:final password) => rust.BridgeAuthentication.password(
        password: password,
      ),
      PrivateKeyCredential(:final pem, :final passphrase) =>
        rust.BridgeAuthentication.privateKey(pem: pem, passphrase: passphrase),
    };
    final session = await rust.MobileSshSession.connect(
      config: rust.BridgeConnectionConfig(
        host: host,
        port: port,
        username: username,
        acceptedHostKeySha256: acceptedHostKeySha256,
        connectTimeoutMs: BigInt.from(connectTimeout.inMilliseconds),
        inactivityTimeoutMs: BigInt.from(inactivityTimeout.inMilliseconds),
      ),
      authentication: authentication,
    );
    return NativeSshConnection._(session);
  }
}

class NativeSshConnection {
  NativeSshConnection._(this._session);
  final rust.MobileSshSession _session;

  Future<NativeCommandOutput> execute(String command) async {
    final output = await _session.execute(command: command);
    return NativeCommandOutput(
      stdout: output.stdout,
      stderr: output.stderr,
      exitStatus: output.exitStatus,
    );
  }

  Future<NativeAgentInstallResult> installAgent({
    required Uint8List binary,
    required String version,
    required String expectedSha256,
  }) async {
    final result = await _session.installAgent(
      binary: binary,
      version: version,
      expectedSha256: expectedSha256,
    );
    return NativeAgentInstallResult(
      version: result.version,
      remotePath: result.remotePath,
      sha256: result.sha256,
    );
  }

  Future<NativeTerminal> openTerminal({
    String term = 'xterm-256color',
    required int columns,
    required int rows,
  }) async => NativeTerminal._(
    await _session.openTerminal(term: term, columns: columns, rows: rows),
  );

  Future<NativeAgentChannel> openAgent() async =>
      NativeAgentChannel._(await _session.openAgent());

  Future<NativePortForward> startLocalForward({
    String bindAddress = '127.0.0.1',
    required int localPort,
    required String targetHost,
    required int targetPort,
  }) async => NativePortForward._(
    await _session.startLocalForward(
      bindAddress: bindAddress,
      localPort: localPort,
      targetHost: targetHost,
      targetPort: targetPort,
    ),
  );

  Future<void> disconnect() => _session.disconnect();
}

class NativeTerminal {
  NativeTerminal._(this._terminal);
  final rust.MobileTerminal _terminal;

  Future<void> write(Uint8List bytes) => _terminal.write(bytes: bytes);
  Future<void> resize({required int columns, required int rows}) =>
      _terminal.resize(columns: columns, rows: rows);
  Future<rust.BridgeTerminalEvent> nextEvent() => _terminal.nextEvent();
  Future<void> close() => _terminal.close();
}

class NativeAgentChannel {
  NativeAgentChannel._(this._channel);
  final rust.MobileAgentChannel _channel;

  Future<Map<String, Object?>> request(Map<String, Object?> request) async {
    final response = await _channel.requestJson(
      sentAtUnixMs: DateTime.now().millisecondsSinceEpoch,
      requestJson: jsonEncode(request),
    );
    return jsonDecode(response) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> requestPayload(
    Map<String, Object?> request,
  ) async {
    final envelope = await this.request(request);
    if (envelope['protocol_version'] != 1 || envelope['kind'] != 'response') {
      throw const RemoteAgentException(
        'protocol_mismatch',
        'Remote agent returned an incompatible response envelope',
      );
    }
    final payload = envelope['payload'];
    if (payload is! Map<String, Object?>) {
      throw const RemoteAgentException(
        'invalid_response',
        'Remote agent returned an invalid response payload',
      );
    }
    if (payload['type'] == 'error') {
      throw RemoteAgentException(
        payload['code'] as String? ?? 'remote_failure',
        payload['message'] as String? ?? 'Remote agent request failed',
        retryable: payload['retryable'] as bool? ?? false,
        sensitive: payload['sensitive'] as bool? ?? false,
      );
    }
    return payload;
  }
}

class RemoteAgentException implements Exception {
  const RemoteAgentException(
    this.code,
    this.message, {
    this.retryable = false,
    this.sensitive = false,
  });

  final String code;
  final String message;
  final bool retryable;
  final bool sensitive;

  @override
  String toString() => 'RemoteAgentException($code): $message';
}

class NativePortForward {
  NativePortForward._(this._forward);
  final rust.MobilePortForward _forward;

  Future<String> get localAddress => _forward.localAddress();
  Future<void> stop() => _forward.stop();
}
