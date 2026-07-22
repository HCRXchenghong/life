import 'dart:convert';

import 'package:daylink_mobile/src/application/assistant_image_actions.dart';
import 'package:daylink_mobile/src/application/assistant_settings.dart';
import 'package:daylink_mobile/src/domain/ai/ai_models.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_image_models.dart';
import 'package:daylink_mobile/src/presentation/app_navigation.dart';
import 'package:daylink_mobile/src/presentation/assistant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved GPT-style assistant layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _FakeAssistantSettings();

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: settings,
          onDestinationSelected: (_) {},
          onOpenHistory: () {},
          onNewConversation: () {},
          onOpenMore: () {},
          onAddAttachment: () {},
          onVoiceInput: () {},
          onSubmit: (_) async {},
          onMessage: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地助手'), findsOneWidget);
    expect(find.text('有什么可以帮忙的？'), findsOneWidget);
    expect(find.text('自动选择'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
    expect(find.byKey(const Key('assistant-input')), findsOneWidget);
    expect(find.text('询问 Daylink'), findsOneWidget);
    expect(find.text('工具箱'), findsOneWidget);
    expect(find.text('助手'), findsOneWidget);

    final assistantIcon = tester.widget<Icon>(
      find.byIcon(Icons.auto_awesome_outlined),
    );
    final toolboxIcon = tester.widget<Icon>(
      find.byIcon(Icons.grid_view_rounded),
    );
    expect(assistantIcon.color, const Color(0xFF3370FF));
    expect(toolboxIcon.color, const Color(0xFF646A73));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode, model, reasoning and composer controls are functional', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _FakeAssistantSettings();
    final submitted = <String>[];
    final actions = <String>[];
    final destinations = <AppDestination>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: settings,
          onDestinationSelected: destinations.add,
          onOpenHistory: () => actions.add('history'),
          onNewConversation: () => actions.add('new'),
          onOpenMore: () => actions.add('more'),
          onAddAttachment: () => actions.add('attachment'),
          onVoiceInput: () => actions.add('voice'),
          onSubmit: (input) async => submitted.add(input),
          onMessage: (message) => actions.add(message),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH Agent').last);
    await tester.pumpAndSettle();
    expect(find.text('SSH Agent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5-codex').last);
    await tester.pumpAndSettle();
    expect(find.text('gpt-5-codex'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-reasoning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('极高').last);
    await tester.pumpAndSettle();
    expect(find.text('极高'), findsOneWidget);
    expect(settings.lastModel, 'gpt-5-codex');
    expect(settings.lastEffort, AiReasoningEffort.xhigh);

    await tester.tap(find.byKey(const Key('assistant-history')));
    await tester.tap(find.byKey(const Key('assistant-new-conversation')));
    await tester.tap(find.byKey(const Key('assistant-more')));
    await tester.tap(find.byKey(const Key('assistant-add')));
    await tester.pumpAndSettle();
    expect(find.text('添加到对话'), findsOneWidget);
    expect(find.text('生成图片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-add-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-microphone')));
    expect(actions, ['history', 'new', 'more', 'attachment', 'voice']);

    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '帮我安排明天的日程',
    );
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-primary-action')));
    await tester.pumpAndSettle();
    expect(submitted, ['帮我安排明天的日程']);

    await tester.tap(find.byKey(const Key('nav-schedule')));
    await tester.tap(find.byKey(const Key('nav-toolbox')));
    expect(destinations, [AppDestination.schedule, AppDestination.toolbox]);
  });

  testWidgets('generates, saves and shares an image inside the conversation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final images = _FakeImageSource();
    final actions = _FakeImageActions();
    final messages = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          images: images,
          imageActions: actions,
          onDestinationSelected: (_) {},
          onOpenHistory: () {},
          onNewConversation: () {},
          onOpenMore: () {},
          onAddAttachment: () {},
          onVoiceInput: () {},
          onSubmit: (_) async {},
          onMessage: messages.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-generate-image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-image-mode')), findsOneWidget);
    expect(find.text('描述要生成的图片'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '一张蓝色的极简日程海报',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-primary-action')));
    await tester.pumpAndSettle();

    expect(images.lastPrompt, '一张蓝色的极简日程海报');
    expect(find.byKey(const Key('assistant-generated-image')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('assistant-save-image')));
    await tester.tap(find.byKey(const Key('assistant-save-image')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('assistant-share-image')));
    await tester.tap(find.byKey(const Key('assistant-share-image')));
    await tester.pumpAndSettle();

    expect(actions.saved, 1);
    expect(actions.shared, 1);
    expect(messages, contains('图片已保存到相册'));
    expect(tester.takeException(), isNull);
  });
}

class _FakeAssistantSettings implements AssistantSettingsSource {
  String? lastModel;
  AiReasoningEffort? lastEffort;

  @override
  Future<AssistantPreferences> loadAssistantPreferences() async =>
      const AssistantPreferences(
        availableModels: ['gpt-5', 'gpt-5-codex'],
        selectedModel: 'gpt-5',
        reasoningEffort: AiReasoningEffort.high,
        supportedModes: {AssistantMode.local, AssistantMode.sshAgent},
      );

  @override
  Future<void> updateAssistantPreferences({
    required String model,
    required AiReasoningEffort reasoningEffort,
  }) async {
    lastModel = model;
    lastEffort = reasoningEffort;
  }
}

class _FakeImageSource implements AssistantImageGenerationSource {
  String? lastPrompt;
  var cancelled = false;

  @override
  void cancelAssistantImageGeneration() => cancelled = true;

  @override
  Future<AssistantGeneratedImage> generateAssistantImage({
    required String prompt,
    required AssistantImageSize size,
    required AssistantImageQuality quality,
  }) async {
    lastPrompt = prompt;
    return AssistantGeneratedImage(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      prompt: prompt,
      size: size,
      quality: quality,
      createdAt: DateTime.utc(2026, 7, 22),
    );
  }
}

class _FakeImageActions implements AssistantImageActionSource {
  var saved = 0;
  var shared = 0;

  @override
  Future<void> saveToGallery(AssistantGeneratedImage image) async => saved++;

  @override
  Future<void> share(
    AssistantGeneratedImage image, {
    required Rect sharePositionOrigin,
  }) async => shared++;
}
