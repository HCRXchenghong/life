enum TerminalMode { direct, persistent }

enum HostKeyObservation { firstSeen, trusted, changed }

enum ForwardState { stopped, starting, running, stopping, failed }

enum TransferDirection { upload, download }

enum TransferState { queued, running, paused, completed, failed, cancelled }

enum CommandBatchStatus {
  queued,
  running,
  completed,
  partialFailure,
  failed,
  cancelled,
}

enum CommandResultStatus {
  queued,
  running,
  succeeded,
  failed,
  timedOut,
  cancelled,
}

class HostProfileModel {
  const HostProfileModel({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.username,
    required this.terminalMode,
    this.groupId,
    this.credentialRef,
    this.notes = '',
    this.favorite = false,
    this.agentState = 'unknown',
  });

  final String id;
  final String name;
  final String address;
  final int port;
  final String username;
  final String? groupId;
  final String? credentialRef;
  final String notes;
  final bool favorite;
  final TerminalMode terminalMode;
  final String agentState;
}

class HostGroupModel {
  const HostGroupModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });
  final String id;
  final String name;
  final int sortOrder;
}

class OperationTagModel {
  const OperationTagModel({
    required this.id,
    required this.name,
    this.colorArgb,
  });
  final String id;
  final String name;
  final int? colorArgb;
}

class HostSearchResult {
  const HostSearchResult({required this.host, required this.tags});
  final HostProfileModel host;
  final List<OperationTagModel> tags;
}

class HostKeyCheck {
  const HostKeyCheck({
    required this.observation,
    required this.algorithm,
    required this.receivedFingerprintSha256,
    this.acceptedFingerprintSha256,
  });

  final HostKeyObservation observation;
  final String algorithm;
  final String receivedFingerprintSha256;
  final String? acceptedFingerprintSha256;
}

class AgentStateModel {
  const AgentStateModel({
    required this.hostId,
    required this.protocolVersion,
    required this.agentVersion,
    required this.architecture,
    required this.capabilitiesJson,
    required this.transport,
    required this.health,
    required this.lastSeenAt,
  });

  final String hostId;
  final int protocolVersion;
  final String agentVersion;
  final String architecture;
  final String capabilitiesJson;
  final String transport;
  final String health;
  final DateTime lastSeenAt;
}

class PortForwardProfileModel {
  const PortForwardProfileModel({
    required this.id,
    required this.hostId,
    required this.name,
    required this.bindAddress,
    required this.localPort,
    required this.targetHost,
    required this.targetPort,
    this.autoStart = false,
    this.state = ForwardState.stopped,
    this.lastError,
  });

  final String id;
  final String hostId;
  final String name;
  final String bindAddress;
  final int localPort;
  final String targetHost;
  final int targetPort;
  final bool autoStart;
  final ForwardState state;
  final String? lastError;
}

class CommandSnippetModel {
  const CommandSnippetModel({
    required this.id,
    required this.name,
    required this.command,
    this.tags = const [],
    this.timeoutSeconds = 60,
  });

  final String id;
  final String name;
  final String command;
  final List<String> tags;
  final int timeoutSeconds;
}

class TransferJobModel {
  const TransferJobModel({
    required this.id,
    required this.hostId,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    required this.totalBytes,
    this.confirmedOffset = 0,
    this.expectedSha256,
    this.remoteIdentityJson,
    this.state = TransferState.queued,
    this.lastError,
  });

  final String id;
  final String hostId;
  final TransferDirection direction;
  final String localPath;
  final String remotePath;
  final int totalBytes;
  final int confirmedOffset;
  final String? expectedSha256;
  final String? remoteIdentityJson;
  final TransferState state;
  final String? lastError;
}
