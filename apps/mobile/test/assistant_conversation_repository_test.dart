import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/assistant_conversation_repository.dart';
import 'package:daylink_mobile/src/domain/ai/ai_models.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conversation history stays account-scoped and resumes safely',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      });
      final accountOne = AppDatabase.inMemory();
      final accountTwo = AppDatabase.inMemory();
      addTearDown(accountOne.close);
      addTearDown(accountTwo.close);
      final first = AssistantConversationRepository(accountOne);
      final second = AssistantConversationRepository(accountTwo);
      final provider = AiProviderModel(
        id: 'provider-1',
        name: 'Daylink',
        kind: AiProviderKind.daylinkGateway,
        baseUrl: Uri.parse('https://api.example.com/v1'),
        textModel: 'gpt-5',
        secretRef: 'daylink-session',
      );

      final created = await first.create(
        provider: provider,
        firstPrompt: '  整理产品需求和预算，并给我待办  ',
      );

      expect((await first.list()).single.title, '整理产品需求和预算，并给我待办');
      expect(await second.list(), isEmpty);
      expect(created.previousResponseId, isNull);

      await first.updateResponse(
        id: created.id,
        previousResponseId: 'resp_account_one',
      );
      final resumed = await first.find(created.id);
      expect(resumed?.previousResponseId, 'resp_account_one');
      expect(resumed?.providerId, provider.id);

      await first.rename(created.id, '产品与预算');
      expect((await first.list()).single.title, '产品与预算');

      await first.delete(created.id);
      expect(await first.list(), isEmpty);
    },
  );

  test(
    'conversation history rejects untrusted identifiers and titles',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repository = AssistantConversationRepository(database);

      await expectLater(
        repository.find('../../another-account/app.db'),
        throwsArgumentError,
      );
      await expectLater(
        repository.rename('550e8400-e29b-41d4-a716-446655440000', '   '),
        throwsArgumentError,
      );
    },
  );
}
