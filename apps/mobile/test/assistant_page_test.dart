import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:daylink_mobile/src/application/assistant_artifact_actions.dart';
import 'package:daylink_mobile/src/application/assistant_conversation.dart';
import 'package:daylink_mobile/src/application/assistant_conversation_export.dart';
import 'package:daylink_mobile/src/application/assistant_file_picker.dart';
import 'package:daylink_mobile/src/application/assistant_image_actions.dart';
import 'package:daylink_mobile/src/application/assistant_image_picker.dart';
import 'package:daylink_mobile/src/application/assistant_settings.dart';
import 'package:daylink_mobile/src/application/assistant_speech_input.dart';
import 'package:daylink_mobile/src/domain/ai/ai_models.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_artifact_models.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_image_models.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_input_file.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
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
          imageSource: _FakeInputImageSource(),
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
    final speech = _FakeSpeechInputSource();
    addTearDown(speech.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: settings,
          imageSource: _FakeInputImageSource(),
          speechSource: speech,
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
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-conversation-options-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant-options-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-add')));
    await tester.pumpAndSettle();
    expect(find.text('添加到对话'), findsOneWidget);
    expect(find.text('生成图片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-add-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-microphone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-speech-panel')), findsOneWidget);
    expect(find.text('周六下午和朋友出去'), findsOneWidget);
    expect(find.byKey(const Key('assistant-speech-waveform')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-speech-finish')));
    await tester.pumpAndSettle();
    expect(speech.stopCount, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-input')))
          .controller
          ?.text,
      '周六下午和朋友出去',
    );
    expect(actions, ['history', 'new']);

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

  testWidgets(
    'generated Office file stays in chat and supports preview and download',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final conversation = _FakeConversationSource();
      final artifactActions = _FakeArtifactActions();
      final messages = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPage(
            settings: _FakeAssistantSettings(),
            conversation: conversation,
            artifactActions: artifactActions,
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

      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        '根据项目资料生成一份简洁的周报',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant-primary-action')));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('允许生成文件？'), findsOneWidget);
      expect(find.textContaining('项目周报'), findsOneWidget);
      await tester.tap(find.byKey(const Key('assistant-tool-approve')));
      await tester.pumpAndSettle();

      expect(find.text('根据项目资料生成一份简洁的周报'), findsOneWidget);
      expect(find.text('已生成文档'), findsOneWidget);
      expect(find.text('项目周报.docx'), findsOneWidget);
      expect(find.text('Word 文档 · 26 KB'), findsOneWidget);
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('下载'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('assistant-artifact-preview-artifact-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assistant-artifact-preview-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('artifact-document-preview')),
        findsOneWidget,
      );
      expect(find.text('本周完成'), findsOneWidget);
      await tester.tap(find.byKey(const Key('artifact-preview-close')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('assistant-artifact-download-artifact-1')),
      );
      await tester.pumpAndSettle();
      expect(artifactActions.downloads, 1);
      expect(messages, contains('已打开系统保存面板'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reads selected files and sends their real bytes to the model', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final conversation = _FileConversationSource();

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          conversation: conversation,
          fileSource: _FakeFileSource(),
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

    await tester.tap(find.byKey(const Key('assistant-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-add-file')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-input-files')), findsOneWidget);
    expect(find.text('真实资料.pdf'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('assistant-input')), '总结文件');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-primary-action')));
    await tester.pumpAndSettle();

    expect(conversation.files.single.filename, '真实资料.pdf');
    expect(conversation.files.single.bytes, [0x25, 0x50, 0x44, 0x46]);
    expect(find.text('已读取真实文件'), findsOneWidget);
    expect(find.text('真实资料.pdf'), findsNWidgets(2));
  });

  testWidgets(
    'renders selected image thumbnails and sends images without typed text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final conversation = _FileConversationSource();

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPage(
            settings: _FakeAssistantSettings(),
            conversation: conversation,
            imageSource: _FakeInputImageSource(),
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

      await tester.tap(find.byKey(const Key('assistant-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-add-image')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-input-images')), findsOneWidget);
      expect(
        find.byKey(const Key('assistant-input-image-preview-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('assistant-input-image-preview-1')),
        findsOneWidget,
      );
      expect(find.text('工作台.png'), findsOneWidget);
      expect(find.text('日程照片.png'), findsOneWidget);
      expect(find.text('你可以发送图片，让助手查看并处理'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-input-image-remove-0')));
      await tester.pump();
      expect(find.text('工作台.png'), findsNothing);
      expect(find.text('日程照片.png'), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-primary-action')));
      await tester.pumpAndSettle();
      expect(conversation.files, hasLength(1));
      expect(conversation.files.single.isImage, isTrue);
      expect(conversation.input, '请查看并说明这些图片。');
      expect(find.byKey(const Key('assistant-input-images')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancels speech input without writing its transcript', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final speech = _FakeSpeechInputSource();
    addTearDown(speech.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          speechSource: speech,
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

    await tester.tap(find.byKey(const Key('assistant-microphone')));
    await tester.pumpAndSettle();
    expect(find.text('周六下午和朋友出去'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-speech-cancel')));
    await tester.pumpAndSettle();
    expect(speech.cancelCount, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-input')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.byKey(const Key('assistant-speech-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders approved compact file cards by real Office type', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          fileSource: _OfficeFileSource(),
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

    expect(find.byKey(const Key('assistant-greeting-icon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-add-file')));
    await tester.pumpAndSettle();

    expect(find.text('产品需求文档.docx'), findsOneWidget);
    expect(find.text('预算明细.xlsx'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.byKey(const Key('assistant-input-file-0')), findsOneWidget);
    expect(find.byKey(const Key('assistant-input-file-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-input-file-remove-0')));
    await tester.pump();
    expect(find.text('产品需求文档.docx'), findsNothing);
    expect(find.text('预算明细.xlsx'), findsOneWidget);
  });

  testWidgets(
    'renders approved real file analysis result inside the conversation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final conversation = _OfficeAnalysisConversationSource();

      await tester.pumpWidget(
        MaterialApp(
          home: AssistantPage(
            settings: _FakeAssistantSettings(),
            conversation: conversation,
            fileSource: _OfficeFileSource(),
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

      await tester.tap(find.byKey(const Key('assistant-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-add-file')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        '总结重点并整理待办',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant-primary-action')));
      await tester.pumpAndSettle();

      expect(conversation.files, hasLength(2));
      expect(find.byKey(const Key('assistant-input-files')), findsNothing);
      expect(find.byKey(const Key('assistant-sent-file-0')), findsOneWidget);
      expect(find.byKey(const Key('assistant-sent-file-1')), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('总结重点并整理待办'), findsOneWidget);
      expect(find.byKey(const Key('assistant-response-card')), findsOneWidget);
      expect(find.text('已读取 2 个文件。'), findsOneWidget);
      expect(find.text('重点'), findsOneWidget);
      expect(find.text('本月预算合计 12 万元'), findsOneWidget);
      expect(find.text('待办'), findsOneWidget);
      expect(find.text('确认首期功能范围'), findsOneWidget);
      expect(
        find.byKey(const Key('assistant-response-sources')),
        findsOneWidget,
      );
      expect(find.text('产品需求文档.docx'), findsNWidgets(2));
      expect(find.text('预算明细.xlsx'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens, searches and restores the approved history drawer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _HistoryConversationSource();

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          conversation: source,
          history: source,
          accountName: 'chenghong',
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

    await tester.tap(find.byKey(const Key('assistant-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-history-drawer')), findsOneWidget);
    expect(find.text('Daylink'), findsOneWidget);
    expect(find.text('搜索对话'), findsOneWidget);
    expect(find.text('新建对话'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('过去 7 天'), findsOneWidget);
    expect(find.text('整理产品需求和预算'), findsOneWidget);
    expect(find.text('chenghong'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('assistant-history-search')),
      '服务器',
    );
    await tester.pump();
    expect(find.text('服务器巡检总结'), findsOneWidget);
    expect(find.text('整理产品需求和预算'), findsNothing);

    await tester.tap(find.text('服务器巡检总结'));
    await tester.pumpAndSettle();
    expect(source.selectedId, _HistoryConversationSource.yesterdayId);
    expect(find.byKey(const Key('assistant-history-drawer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renames and confirms deletion from conversation history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _HistoryConversationSource();

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          conversation: source,
          history: source,
          accountName: 'chenghong',
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
    await tester.tap(find.byKey(const Key('assistant-history')));
    await tester.pumpAndSettle();

    final menuKey = Key(
      'assistant-history-menu-${_HistoryConversationSource.todayId}',
    );
    await tester.tap(find.byKey(menuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-history-rename-input')),
      '产品规划与预算',
    );
    await tester.tap(find.byKey(const Key('assistant-history-rename-confirm')));
    await tester.pumpAndSettle();
    expect(source.renamedTitle, '产品规划与预算');
    expect(find.text('产品规划与预算'), findsOneWidget);

    await tester.tap(find.byKey(menuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-history-delete-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant-history-delete-confirm')));
    await tester.pumpAndSettle();
    expect(source.deletedId, _HistoryConversationSource.todayId);
    expect(find.text('产品规划与预算'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runs every approved current conversation option', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _HistoryConversationSource();
    final exports = _FakeConversationExports();
    final messages = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantPage(
          settings: _FakeAssistantSettings(),
          conversation: source,
          history: source,
          conversationExports: exports,
          accountName: 'chenghong',
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
    await tester.enterText(find.byKey(const Key('assistant-input')), '总结需求');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-primary-action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant-more')));
    await tester.pumpAndSettle();
    expect(find.text('对话选项'), findsOneWidget);
    expect(find.text('重命名对话'), findsOneWidget);
    expect(find.text('导出对话'), findsOneWidget);
    expect(find.text('清空当前内容'), findsOneWidget);
    expect(find.text('删除对话'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-options-export')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-export-format-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant-export-markdown')));
    await tester.pumpAndSettle();
    expect(exports.format, AssistantConversationExportFormat.markdown);
    expect(exports.document?.title, '整理产品需求和预算');
    expect(exports.document?.turns.single.prompt, '总结需求');
    expect(exports.document?.turns.single.response, '完成');

    await tester.tap(find.byKey(const Key('assistant-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-options-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-options-rename-input')),
      '需求总结',
    );
    await tester.tap(find.byKey(const Key('assistant-options-rename-confirm')));
    await tester.pumpAndSettle();
    expect(source.renamedTitle, '需求总结');

    await tester.tap(find.byKey(const Key('assistant-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-options-clear')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-options-clear-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant-options-clear-confirm')));
    await tester.pumpAndSettle();
    expect(source.clearedId, _HistoryConversationSource.todayId);
    expect(find.text('有什么可以帮忙的？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-options-delete')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant-options-delete-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant-options-delete-confirm')));
    await tester.pumpAndSettle();
    expect(source.deletedId, _HistoryConversationSource.todayId);
    expect(messages, contains('已打开系统保存面板'));
    expect(messages, contains('对话已重命名'));
    expect(messages, contains('当前对话内容已清空'));
    expect(messages, contains('对话已删除'));
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

class _FakeConversationSource implements AssistantConversationSource {
  @override
  void cancelAssistantMessage() {}

  @override
  Future<AssistantConversationReply> sendAssistantMessage({
    required String input,
    required AssistantMode mode,
    required ApprovalDelegate approvals,
    List<AssistantInputFile> files = const [],
  }) async {
    final decision = await approvals(
      const ToolSpec(
        name: 'daylink_create_word_document',
        description: 'Create a Word document',
        inputSchema: {'type': 'object'},
        risk: ToolRisk.medium,
        approval: ToolApprovalPolicy.always,
        sandbox: ToolSandbox.localData,
      ),
      const ToolCall(
        callId: 'artifact-call-1',
        name: 'daylink_create_word_document',
        arguments: {'title': '项目周报'},
      ),
    );
    if (decision != ApprovalDecision.accept) {
      return const AssistantConversationReply(text: '已取消');
    }
    return const AssistantConversationReply(
      text: '已生成文档',
      artifacts: [
        AssistantGeneratedArtifact(
          id: 'artifact-1',
          kind: AssistantArtifactKind.document,
          displayName: '项目周报.docx',
          contentType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          byteSize: 26624,
          localPath: '/private/daylink/artifact-1.docx',
          preview: AssistantDocumentPreview(
            title: '项目周报',
            paragraphs: ['本周完成', '下周计划'],
          ),
        ),
      ],
    );
  }

  @override
  void startNewAssistantConversation() {}
}

class _FakeArtifactActions implements AssistantArtifactActionSource {
  var downloads = 0;

  @override
  Future<void> download(
    AssistantGeneratedArtifact artifact, {
    required Rect sharePositionOrigin,
  }) async {
    downloads++;
  }
}

class _FakeFileSource implements AssistantInputFileSource {
  @override
  Future<List<AssistantInputFile>> pickFiles() async => [
    AssistantInputFile(
      filename: '真实资料.pdf',
      contentType: 'application/pdf',
      bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
    ),
  ];
}

class _FakeInputImageSource implements AssistantInputImageSource {
  @override
  Future<List<AssistantInputFile>> pickImages() async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    return [
      AssistantInputFile(
        filename: '工作台.png',
        contentType: 'image/png',
        bytes: bytes,
      ),
      AssistantInputFile(
        filename: '日程照片.png',
        contentType: 'image/png',
        bytes: bytes,
      ),
    ];
  }
}

class _FakeSpeechInputSource implements AssistantSpeechInputSource {
  final _updates = StreamController<AssistantSpeechUpdate>.broadcast();
  var startCount = 0;
  var stopCount = 0;
  var cancelCount = 0;

  @override
  Stream<AssistantSpeechUpdate> get updates => _updates.stream;

  @override
  Future<void> start({String locale = 'zh-CN'}) async {
    startCount++;
    _updates.add(
      const AssistantSpeechUpdate(
        transcript: '周六下午和朋友出去',
        level: 0.72,
        isFinal: false,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() => _updates.close();
}

class _OfficeFileSource implements AssistantInputFileSource {
  @override
  Future<List<AssistantInputFile>> pickFiles() async => [
    AssistantInputFile(
      filename: '产品需求文档.docx',
      contentType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
    ),
    AssistantInputFile(
      filename: '预算明细.xlsx',
      contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
    ),
  ];
}

class _OfficeAnalysisConversationSource implements AssistantConversationSource {
  List<AssistantInputFile> files = const [];

  @override
  void cancelAssistantMessage() {}

  @override
  Future<AssistantConversationReply> sendAssistantMessage({
    required String input,
    required AssistantMode mode,
    required ApprovalDelegate approvals,
    List<AssistantInputFile> files = const [],
  }) async {
    this.files = files;
    return const AssistantConversationReply(
      text: '''
已读取 2 个文件。

## 重点
- 产品目标聚焦团队日程协作
- 首期需要完成邀请、提醒与同步
- 本月预算合计 12 万元

## 待办
- [ ] 确认首期功能范围
- [ ] 补充邀请流程验收标准
- [ ] 核对预算负责人和截止时间''',
    );
  }

  @override
  void startNewAssistantConversation() {}
}

class _FileConversationSource implements AssistantConversationSource {
  List<AssistantInputFile> files = const [];
  String? input;

  @override
  void cancelAssistantMessage() {}

  @override
  Future<AssistantConversationReply> sendAssistantMessage({
    required String input,
    required AssistantMode mode,
    required ApprovalDelegate approvals,
    List<AssistantInputFile> files = const [],
  }) async {
    this.files = files;
    this.input = input;
    return const AssistantConversationReply(text: '已读取真实文件');
  }

  @override
  void startNewAssistantConversation() {}
}

class _HistoryConversationSource
    implements AssistantConversationSource, AssistantConversationHistorySource {
  static const todayId = '550e8400-e29b-41d4-a716-446655440000';
  static const yesterdayId = '550e8400-e29b-41d4-a716-446655440001';
  static const olderId = '550e8400-e29b-41d4-a716-446655440002';

  String? selectedId = todayId;
  String? renamedTitle;
  String? clearedId;
  String? deletedId;
  late final List<AssistantConversationSummary> _items = [
    AssistantConversationSummary(
      id: todayId,
      title: '整理产品需求和预算',
      updatedAt: DateTime.now().toUtc(),
    ),
    AssistantConversationSummary(
      id: yesterdayId,
      title: '服务器巡检总结',
      updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    ),
    AssistantConversationSummary(
      id: olderId,
      title: 'SSH 日志问题排查',
      updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  String? get activeAssistantConversationId => selectedId;

  @override
  void cancelAssistantMessage() {}

  @override
  Future<void> clearAssistantConversation(String conversationId) async {
    clearedId = conversationId;
  }

  @override
  Future<void> deleteAssistantConversation(String conversationId) async {
    deletedId = conversationId;
    _items.removeWhere((item) => item.id == conversationId);
    if (selectedId == conversationId) selectedId = null;
  }

  @override
  Future<List<AssistantConversationSummary>>
  loadAssistantConversations() async => List.unmodifiable(_items);

  @override
  Future<void> renameAssistantConversation(
    String conversationId,
    String title,
  ) async {
    renamedTitle = title;
    final index = _items.indexWhere((item) => item.id == conversationId);
    final current = _items[index];
    _items[index] = AssistantConversationSummary(
      id: current.id,
      title: title,
      updatedAt: current.updatedAt,
    );
  }

  @override
  Future<void> selectAssistantConversation(String conversationId) async {
    selectedId = conversationId;
  }

  @override
  Future<AssistantConversationReply> sendAssistantMessage({
    required String input,
    required AssistantMode mode,
    required ApprovalDelegate approvals,
    List<AssistantInputFile> files = const [],
  }) async =>
      const AssistantConversationReply(text: '完成', conversationId: todayId);

  @override
  void startNewAssistantConversation() => selectedId = null;
}

class _FakeConversationExports implements AssistantConversationExportSource {
  AssistantConversationExportDocument? document;
  AssistantConversationExportFormat? format;

  @override
  Future<void> export(
    AssistantConversationExportDocument document, {
    required AssistantConversationExportFormat format,
    required Rect sharePositionOrigin,
  }) async {
    this.document = document;
    this.format = format;
  }
}
