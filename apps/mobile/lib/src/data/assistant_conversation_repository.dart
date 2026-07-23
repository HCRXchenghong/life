import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../application/assistant_conversation.dart';
import '../domain/ai/ai_models.dart';
import 'app_database.dart';

class StoredAssistantConversation {
  const StoredAssistantConversation({
    required this.id,
    required this.providerId,
    required this.title,
    required this.previousResponseId,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final String title;
  final String? previousResponseId;
  final DateTime updatedAt;

  AssistantConversationSummary get summary =>
      AssistantConversationSummary(id: id, title: title, updatedAt: updatedAt);
}

class AssistantConversationRepository {
  AssistantConversationRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<AssistantConversationSummary>> list() async {
    final query = _db.select(_db.aiConversations)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.updatedAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => AssistantConversationSummary(
            id: row.id,
            title: row.title,
            updatedAt: row.updatedAt.toUtc(),
          ),
        )
        .toList(growable: false);
  }

  Future<StoredAssistantConversation?> find(String id) async {
    _requireId(id);
    final row = await (_db.select(
      _db.aiConversations,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _stored(row);
  }

  Future<StoredAssistantConversation> create({
    required AiProviderModel provider,
    required String firstPrompt,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final title = _conversationTitle(firstPrompt);
    await _db.transaction(() async {
      await _db
          .into(_db.aiProviderConfigs)
          .insertOnConflictUpdate(
            AiProviderConfigsCompanion.insert(
              id: provider.id,
              name: provider.name,
              kind: provider.kind.name,
              baseUrl: provider.baseUrl.toString().replaceFirst(
                RegExp(r'/$'),
                '',
              ),
              textModel: provider.textModel,
              imageModel: Value(provider.imageModel),
              secretRef: provider.secretRef,
              enabled: Value(provider.enabled),
              updatedAt: Value(now),
            ),
          );
      await _db
          .into(_db.aiConversations)
          .insert(
            AiConversationsCompanion.insert(
              id: id,
              providerId: provider.id,
              title: Value(title),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
    return StoredAssistantConversation(
      id: id,
      providerId: provider.id,
      title: title,
      previousResponseId: null,
      updatedAt: now,
    );
  }

  Future<void> updateResponse({
    required String id,
    required String? previousResponseId,
  }) async {
    _requireId(id);
    final updated =
        await (_db.update(
          _db.aiConversations,
        )..where((table) => table.id.equals(id))).write(
          AiConversationsCompanion(
            previousResponseId: Value(previousResponseId),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (updated != 1) {
      throw StateError('Assistant conversation no longer exists');
    }
  }

  Future<void> rename(String id, String title) async {
    _requireId(id);
    final normalized = _normalizedTitle(title);
    final updated =
        await (_db.update(
          _db.aiConversations,
        )..where((table) => table.id.equals(id))).write(
          AiConversationsCompanion(
            title: Value(normalized),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (updated != 1) {
      throw StateError('Assistant conversation no longer exists');
    }
  }

  Future<void> clear(String id) async {
    _requireId(id);
    final updated =
        await (_db.update(
          _db.aiConversations,
        )..where((table) => table.id.equals(id))).write(
          AiConversationsCompanion(
            previousResponseId: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (updated != 1) {
      throw StateError('Assistant conversation no longer exists');
    }
  }

  Future<void> delete(String id) async {
    _requireId(id);
    await (_db.delete(
      _db.aiConversations,
    )..where((table) => table.id.equals(id))).go();
  }

  StoredAssistantConversation _stored(AiConversation row) =>
      StoredAssistantConversation(
        id: row.id,
        providerId: row.providerId,
        title: row.title,
        previousResponseId: row.previousResponseId,
        updatedAt: row.updatedAt.toUtc(),
      );
}

String _conversationTitle(String prompt) {
  final normalized = prompt
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\p{P}\p{S}\s]+', unicode: true), '')
      .trim();
  if (normalized.isEmpty) return '新对话';
  return normalized.length <= 24
      ? normalized
      : '${normalized.substring(0, 24)}…';
}

String _normalizedTitle(String title) {
  final normalized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty || normalized.length > 80) {
    throw ArgumentError.value(title, 'title', 'Title must be 1–80 characters');
  }
  return normalized;
}

void _requireId(String id) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid conversation ID');
  }
}
