import '../domain/ai/assistant_artifact_models.dart';
import '../domain/ai/assistant_input_file.dart';
import '../domain/ai/tool_protocol.dart';
import 'assistant_settings.dart';

class AssistantConversationReply {
  const AssistantConversationReply({
    required this.text,
    this.artifacts = const [],
  });

  final String text;
  final List<AssistantGeneratedArtifact> artifacts;
}

abstract interface class AssistantConversationSource {
  Future<AssistantConversationReply> sendAssistantMessage({
    required String input,
    required AssistantMode mode,
    required ApprovalDelegate approvals,
    List<AssistantInputFile> files = const [],
  });

  void cancelAssistantMessage();

  void startNewAssistantConversation();
}
