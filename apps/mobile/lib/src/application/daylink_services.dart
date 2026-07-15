import 'dart:async';

import '../data/ai_provider_repository.dart';
import '../data/ai_gateway_client.dart';
import '../data/app_session_monitor.dart';
import '../data/app_database.dart';
import '../data/artifact_client.dart';
import '../data/artifact_repository.dart';
import '../data/operations_repository.dart';
import '../data/schedule_repository.dart';
import '../data/secret_vault.dart';
import '../data/share_poll_client.dart';
import '../data/share_poll_repository.dart';
import '../domain/ai/agent_codex_transport.dart';
import '../domain/ai/openai_responses_client.dart';
import '../domain/ai/tool_protocol.dart';
import '../platform/native_core_service.dart';
import '../platform/notification_coordinator.dart';
import 'artifact_tools.dart';
import 'remote_operation_tools.dart';
import 'schedule_tools.dart';
import 'share_poll_coordinator.dart';
import 'share_poll_tools.dart';

class DaylinkServices {
  DaylinkServices._({
    required this.accountId,
    required this.database,
    required this.nativeCore,
    required this.notifications,
    required this.secrets,
    required this.schedules,
    required this.operations,
    required this.aiProviders,
    required this.responses,
  });

  final String accountId;
  final AppDatabase database;
  final NativeCoreService nativeCore;
  final NotificationCoordinator notifications;
  final SecretStore secrets;
  final ScheduleRepository schedules;
  final OperationsRepository operations;
  final AiProviderRepository aiProviders;
  final OpenAiResponsesClient responses;
  final List<AppSessionMonitor> _sessionMonitors = [];
  bool _closed = false;

  static Future<DaylinkServices> start({required String accountId}) async {
    final nativeCore = await NativeCoreService.initialize();
    final database = AppDatabase.openForAccount(accountId);
    final secrets = SecretVault(accountId: accountId);
    final schedules = ScheduleRepository(database);
    final notifications = NotificationCoordinator(
      accountId: accountId,
      repository: schedules,
    );
    final responses = OpenAiResponsesClient();
    final services = DaylinkServices._(
      accountId: accountId,
      database: database,
      nativeCore: nativeCore,
      notifications: notifications,
      secrets: secrets,
      schedules: schedules,
      operations: OperationsRepository(database),
      aiProviders: AiProviderRepository(database, secrets),
      responses: responses,
    );
    try {
      await notifications.initialize(
        onForegroundAction: (response) {
          unawaited(notifications.handleAction(response));
        },
      );
      await notifications.reconcile();
      return services;
    } on Object {
      responses.close();
      await database.close();
      rethrow;
    }
  }

  ConfiguredShareService configureShare({
    required Uri apiBaseUri,
    required String mobileToken,
  }) {
    final client = SharePollClient(
      apiBaseUri: apiBaseUri,
      mobileToken: mobileToken,
    );
    final repository = SharePollRepository(database, secrets);
    return ConfiguredShareService(
      client: client,
      repository: repository,
      coordinator: SharePollCoordinator(
        client: client,
        polls: repository,
        schedules: schedules,
        reconcileNotifications: notifications.reconcile,
      ),
    );
  }

  ConfiguredArtifactService configureArtifacts({
    required Uri apiBaseUri,
    required String mobileToken,
  }) {
    final client = ArtifactClient(
      apiBaseUri: apiBaseUri,
      mobileToken: mobileToken,
    );
    return ConfiguredArtifactService(
      client: client,
      repository: ArtifactRepository(accountId: accountId),
    );
  }

  ToolRegistry createToolRegistry({
    required ApprovalDelegate approvals,
    ConfiguredShareService? share,
    ConfiguredArtifactService? artifacts,
    NativeAgentChannel? remoteAgent,
  }) {
    final registry = ToolRegistry(approvals: approvals);
    ScheduleTools(
      repository: schedules,
      reconcileNotifications: notifications.reconcile,
    ).register(registry);
    if (share != null) {
      SharePollTools(
        coordinator: share.coordinator,
        repository: share.repository,
      ).register(registry);
    }
    if (artifacts != null) {
      ArtifactTools(
        generator: artifacts.client,
        sink: artifacts.repository,
      ).register(registry);
    }
    if (remoteAgent != null) {
      RemoteOperationTools.forChannel(remoteAgent).register(registry);
    }
    return registry;
  }

  Future<AgentCodexAppServerTransport> startRemoteCodex({
    required NativeAgentChannel channel,
    required String cwd,
    required Uri apiBaseUri,
    required String mobileToken,
  }) async {
    final gateway = AiGatewayClient(
      apiBaseUri: apiBaseUri,
      mobileToken: mobileToken,
    );
    try {
      final credential = await gateway.createRemoteCredential();
      return AgentCodexAppServerTransport.start(
        request: channel.requestPayload,
        cwd: cwd,
        gatewayBaseUrl: credential.baseUrl,
        gatewayToken: credential.token,
        model: credential.model,
        reasoningEffort: credential.reasoningEffort,
      );
    } finally {
      gateway.close();
    }
  }

  AiGatewayClient configureAI({
    required Uri apiBaseUri,
    required String mobileToken,
  }) => AiGatewayClient(apiBaseUri: apiBaseUri, mobileToken: mobileToken);

  AppSessionMonitor monitorSession({
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
    required ForcedSignOutCallback onForcedSignOut,
  }) {
    if (_closed) throw StateError('Daylink services are closed');
    final monitor = AppSessionMonitor(
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
      clearCredentials: clearCredentials,
      onForcedSignOut: onForcedSignOut,
      onChanges: reconcile,
    );
    _sessionMonitors.add(monitor);
    monitor.start();
    return monitor;
  }

  Future<void> reconcile() async {
    if (_closed) return;
    for (final monitor in _sessionMonitors) {
      await monitor.reconcile();
    }
    if (!_closed) await notifications.reconcile();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final monitor in _sessionMonitors) {
      await monitor.close();
    }
    _sessionMonitors.clear();
    responses.close();
    await database.close();
  }
}

class ConfiguredArtifactService {
  const ConfiguredArtifactService({
    required this.client,
    required this.repository,
  });

  final ArtifactClient client;
  final ArtifactRepository repository;

  void close() => client.close();
}

class ConfiguredShareService {
  const ConfiguredShareService({
    required this.client,
    required this.repository,
    required this.coordinator,
  });

  final SharePollClient client;
  final SharePollRepository repository;
  final SharePollCoordinator coordinator;

  void close() => client.close();
}
