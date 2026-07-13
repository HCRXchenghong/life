import 'dart:async';

import '../data/ai_provider_repository.dart';
import '../data/app_database.dart';
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
import 'remote_operation_tools.dart';
import 'schedule_tools.dart';
import 'share_poll_coordinator.dart';
import 'share_poll_tools.dart';

class DaylinkServices {
  DaylinkServices._({
    required this.database,
    required this.nativeCore,
    required this.notifications,
    required this.secrets,
    required this.schedules,
    required this.operations,
    required this.aiProviders,
    required this.responses,
  });

  final AppDatabase database;
  final NativeCoreService nativeCore;
  final NotificationCoordinator notifications;
  final SecretStore secrets;
  final ScheduleRepository schedules;
  final OperationsRepository operations;
  final AiProviderRepository aiProviders;
  final OpenAiResponsesClient responses;

  static Future<DaylinkServices> start() async {
    final nativeCore = await NativeCoreService.initialize();
    final database = AppDatabase.open();
    final secrets = SecretVault();
    final schedules = ScheduleRepository(database);
    final notifications = NotificationCoordinator(repository: schedules);
    final responses = OpenAiResponsesClient();
    final services = DaylinkServices._(
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

  ToolRegistry createToolRegistry({
    required ApprovalDelegate approvals,
    ConfiguredShareService? share,
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
    if (remoteAgent != null) {
      RemoteOperationTools.forChannel(remoteAgent).register(registry);
    }
    return registry;
  }

  Future<AgentCodexAppServerTransport> startRemoteCodex({
    required NativeAgentChannel channel,
    required String cwd,
    String? model,
  }) => AgentCodexAppServerTransport.start(
    request: channel.requestPayload,
    cwd: cwd,
    model: model,
  );

  Future<void> reconcile() => notifications.reconcile();

  Future<void> close() async {
    responses.close();
    await database.close();
  }
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
