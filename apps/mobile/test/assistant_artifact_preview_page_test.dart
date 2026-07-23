import 'package:daylink_mobile/src/domain/ai/assistant_artifact_models.dart';
import 'package:daylink_mobile/src/presentation/assistant_artifact_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('previews generated Word content without opening a Work editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewPage(
          artifact: _artifact(
            kind: AssistantArtifactKind.document,
            preview: const AssistantDocumentPreview(
              title: '项目周报',
              paragraphs: ['本周完成了文件卡片', '下周继续完善助手'],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('artifact-document-preview')), findsOneWidget);
    expect(find.text('项目周报'), findsOneWidget);
    expect(find.text('本周完成了文件卡片'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('previews generated spreadsheet cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewPage(
          artifact: _artifact(
            kind: AssistantArtifactKind.spreadsheet,
            preview: const AssistantSpreadsheetPreview(
              title: '项目预算',
              sheets: [
                AssistantSpreadsheetSheet(
                  name: '预算',
                  rows: [
                    ['项目', '金额'],
                    ['交通', '120'],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('artifact-spreadsheet-preview')),
      findsOneWidget,
    );
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('previews generated presentation slides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewPage(
          artifact: _artifact(
            kind: AssistantArtifactKind.presentation,
            preview: const AssistantPresentationPreview(
              title: '项目汇报',
              slides: [
                AssistantPresentationSlide(
                  title: '本周目标',
                  bullets: ['保持简洁', '支持预览与下载'],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('artifact-presentation-preview')),
      findsOneWidget,
    );
    expect(find.text('本周目标'), findsOneWidget);
    expect(find.text('支持预览与下载'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}

AssistantGeneratedArtifact _artifact({
  required AssistantArtifactKind kind,
  required AssistantArtifactPreview preview,
}) => AssistantGeneratedArtifact(
  id: 'artifact-id',
  kind: kind,
  displayName: '测试.${kind.extension}',
  contentType: 'application/octet-stream',
  byteSize: 26624,
  localPath: '/private/daylink/test.${kind.extension}',
  preview: preview,
);
