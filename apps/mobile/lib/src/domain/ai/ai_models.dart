enum AiProviderKind {
  openaiResponses,
  openaiCompatible,
  anthropicCompatible,
  daylinkGateway,
}

enum AiReasoningEffort {
  low,
  medium,
  high,
  xhigh;

  static AiReasoningEffort parse(String value) => values.firstWhere(
    (effort) => effort.name == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'unsupported reasoning effort',
    ),
  );
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
    this.availableTextModels = const [],
    this.reasoningEffort = AiReasoningEffort.medium,
    this.enabled = true,
  });

  final String id;
  final String name;
  final AiProviderKind kind;
  final Uri baseUrl;
  final String textModel;
  final String? imageModel;
  final List<String> availableTextModels;
  final AiReasoningEffort reasoningEffort;
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
