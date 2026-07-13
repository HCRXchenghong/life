enum AiProviderKind {
  openaiResponses,
  openaiCompatible,
  anthropicCompatible,
  daylinkGateway,
}

class AiProviderModel {
  const AiProviderModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    required this.textModel,
    required this.secretRef,
    this.imageModel,
    this.enabled = true,
  });

  final String id;
  final String name;
  final AiProviderKind kind;
  final Uri baseUrl;
  final String textModel;
  final String? imageModel;
  final String secretRef;
  final bool enabled;
}

class AiTurnResult {
  const AiTurnResult({
    required this.responseId,
    required this.text,
    required this.toolCalls,
  });
  final String responseId;
  final String text;
  final int toolCalls;
}
