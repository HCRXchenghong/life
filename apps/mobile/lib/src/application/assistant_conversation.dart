import '../domain/ai/assistant_artifact_models.dart';
import '../domain/ai/assistant_input_file.dart';
import '../domain/ai/tool_protocol.dart';
import 'assistant_settings.dart';

class AssistantConversationReply {
  const AssistantConversationReply({
    required this.text,
    this.artifacts = const [],
    this.conversationId,
  });

  final String text;
  final List<AssistantGeneratedArtifact> artifacts;
  final String? conversationId;
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

class AssistantConversationSummary {
  const AssistantConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
}

abstract interface class AssistantConversationHistorySource {
  String? get activeAssistantConversationId;

  Future<List<AssistantConversationSummary>> loadAssistantConversations();

  Future<void> selectAssistantConversation(String conversationId);

  Future<void> renameAssistantConversation(String conversationId, String title);

  Future<void> deleteAssistantConversation(String conversationId);
}
