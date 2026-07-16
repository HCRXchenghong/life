import '../data/ai_gateway_client.dart';
import '../data/app_session_monitor.dart';
import '../domain/ai/ai_models.dart';

enum AssistantMode { local, sshAgent }

class AssistantPreferences {
  const AssistantPreferences({
    required this.availableModels,
    required this.selectedModel,
    required this.reasoningEffort,
    required this.supportedModes,
  });

  final List<String> availableModels;
  final String selectedModel;
  final AiReasoningEffort reasoningEffort;
  final Set<AssistantMode> supportedModes;
}

abstract interface class AssistantSettingsSource {
  Future<AssistantPreferences> loadAssistantPreferences();

  Future<void> updateAssistantPreferences({
    required String model,
    required AiReasoningEffort reasoningEffort,
  });
}

abstract interface class AccountEntitlementSource {
  Future<AiEntitlement> loadAccountEntitlement();
}

class DaylinkAssistantSettings
    implements AssistantSettingsSource, AccountEntitlementSource {
  const DaylinkAssistantSettings({
    required this.apiBaseUri,
    required this.accessToken,
  });

  final Uri apiBaseUri;
  final AccessTokenProvider accessToken;

  @override
  Future<AiEntitlement> loadAccountEntitlement() async {
    final client = await _client();
    try {
      return await client.entitlement();
    } finally {
      client.close();
    }
  }

  @override
  Future<AssistantPreferences> loadAssistantPreferences() async {
    final client = await _client();
    try {
      final configuration = await client.localConfiguration();
      final entitlement = await client.entitlement();
      final selectedModel = configuration.provider.textModel;
      final models = <String>{
        ...configuration.provider.availableTextModels,
        selectedModel,
      }.toList(growable: false);
      return AssistantPreferences(
        availableModels: models,
        selectedModel: selectedModel,
        reasoningEffort: configuration.provider.reasoningEffort,
        supportedModes: entitlement.supportedModes
            .map(
              (mode) => switch (mode) {
                AiExecutionMode.localAI => AssistantMode.local,
                AiExecutionMode.sshAgent => AssistantMode.sshAgent,
              },
            )
            .toSet(),
      );
    } finally {
      client.close();
    }
  }

  @override
  Future<void> updateAssistantPreferences({
    required String model,
    required AiReasoningEffort reasoningEffort,
  }) async {
    final client = await _client();
    try {
      await client.updatePreferences(
        model: model,
        reasoningEffort: reasoningEffort,
      );
    } finally {
      client.close();
    }
  }

  Future<AiGatewayClient> _client() async {
    final token = await accessToken();
    if (token == null) {
      throw const AiGatewayException('session_rejected', '登录已失效，请重新登录');
    }
    return AiGatewayClient(apiBaseUri: apiBaseUri, mobileToken: token);
  }
}
