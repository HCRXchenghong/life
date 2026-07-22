import '../data/ai_gateway_client.dart';
import '../data/app_session_monitor.dart';
import '../domain/ai/ai_models.dart';
import '../domain/ai/assistant_image_models.dart';

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

abstract interface class AssistantImageGenerationSource {
  Future<AssistantGeneratedImage> generateAssistantImage({
    required String prompt,
    required AssistantImageSize size,
    required AssistantImageQuality quality,
  });

  void cancelAssistantImageGeneration();
}

class DaylinkAssistantSettings
    implements
        AssistantSettingsSource,
        AccountEntitlementSource,
        AssistantImageGenerationSource {
  DaylinkAssistantSettings({
    required this.apiBaseUri,
    required this.accessToken,
  });

  final Uri apiBaseUri;
  final AccessTokenProvider accessToken;
  AiGatewayClient? _activeImageClient;

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

  @override
  Future<AssistantGeneratedImage> generateAssistantImage({
    required String prompt,
    required AssistantImageSize size,
    required AssistantImageQuality quality,
  }) async {
    if (_activeImageClient != null) {
      throw const AiGatewayException(
        'request_in_progress',
        'An image request is already in progress',
      );
    }
    final client = await _client();
    _activeImageClient = client;
    try {
      final configuration = await client.localConfiguration();
      if (configuration.provider.imageModel == null) {
        throw const AiGatewayException(
          'image_model_unavailable',
          'The configured AI provider does not expose an image model',
        );
      }
      return await client.generateImage(
        providerId: configuration.provider.id,
        prompt: prompt,
        size: size,
        quality: quality,
      );
    } finally {
      if (identical(_activeImageClient, client)) {
        _activeImageClient = null;
      }
      client.close();
    }
  }

  @override
  void cancelAssistantImageGeneration() {
    _activeImageClient?.close();
    _activeImageClient = null;
  }

  Future<AiGatewayClient> _client() async {
    final token = await accessToken();
    if (token == null) {
      throw const AiGatewayException('session_rejected', '登录已失效，请重新登录');
    }
    return AiGatewayClient(apiBaseUri: apiBaseUri, mobileToken: token);
  }
}
