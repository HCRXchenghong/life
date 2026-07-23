import 'dart:convert';

import 'package:daylink_mobile/src/application/assistant_conversation.dart';
import 'package:daylink_mobile/src/application/assistant_conversation_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const document = AssistantConversationExportDocument(
    title: '产品规划',
    turns: [
      AssistantConversationExportTurn(
        prompt: '总结产品需求和预算',
        response: '重点：完成邀请、提醒与同步。\n待办：确认功能范围。',
        sourceFileNames: ['产品需求文档.docx', '预算明细.xlsx'],
        artifactNames: ['项目周报.pdf'],
      ),
    ],
  );

  test('builds a real UTF-8 Markdown conversation export', () {
    final bytes = const AssistantConversationExportEncoder().buildMarkdown(
      document,
    );
    final text = utf8.decode(bytes);

    expect(text, startsWith('# 产品规划'));
    expect(text, contains('### 你'));
    expect(text, contains('总结产品需求和预算'));
    expect(text, contains('附件：`产品需求文档.docx`、`预算明细.xlsx`'));
    expect(text, contains('### Daylink'));
    expect(text, contains('生成文件：`项目周报.pdf`'));
  });

  testWidgets('builds a paginated image-backed PDF with Chinese text', (
    tester,
  ) async {
    final generated = await tester.runAsync(
      () => const AssistantConversationExportEncoder().buildPdf(document),
    );
    final bytes = generated!;
    final prefix = ascii.decode(bytes.sublist(0, 8), allowInvalid: true);
    final source = latin1.decode(bytes);

    expect(prefix, startsWith('%PDF-1.4'));
    expect(source, contains('/Type /Catalog'));
    expect(source, contains('/Type /Pages /Count 1'));
    expect(source, contains('/Subtype /Image'));
    expect(source, contains('/Filter /FlateDecode'));
    expect(source, contains('xref'));
    expect(source, endsWith('%%EOF\n'));
    expect(bytes.length, greaterThan(5000));
  });

  test('rejects empty exports instead of creating placeholder files', () {
    expect(
      () => const AssistantConversationExportEncoder().buildMarkdown(
        AssistantConversationExportDocument(title: '空对话', turns: const []),
      ),
      throwsA(isA<AssistantConversationExportException>()),
    );
  });
}
