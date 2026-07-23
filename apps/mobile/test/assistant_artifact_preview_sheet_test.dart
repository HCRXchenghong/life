import 'package:daylink_mobile/src/domain/ai/assistant_artifact_models.dart';
import 'package:daylink_mobile/src/presentation/assistant_artifact_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('previews generated Word content without opening a Work editor', (
    tester,
  ) async {
    var downloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewSheet(
          artifact: _artifact(
            kind: AssistantArtifactKind.document,
            preview: const AssistantDocumentPreview(
              title: '项目周报',
              paragraphs: ['本周完成了文件卡片', '下周继续完善助手'],
            ),
          ),
          onDownload: () => downloads++,
        ),
      ),
    );

    expect(
      find.byKey(const Key('assistant-artifact-preview-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('artifact-document-preview')), findsOneWidget);
    expect(find.text('项目周报'), findsOneWidget);
    expect(find.text('本周完成了文件卡片'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('artifact-preview-download')));
    expect(downloads, 1);
  });

  testWidgets('previews generated spreadsheet cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewSheet(
          artifact: _artifact(
            kind: AssistantArtifactKind.spreadsheet,
            preview: const AssistantSpreadsheetPreview(
              title: '项目预算',
              sheets: [
                AssistantSpreadsheetSheet(
                  name: '预算',
                  rows: [
                    ['项目', '预算', '实际', '状态'],
                    ['交通', '¥1,200', '¥980', '正常'],
                    ['住宿', '¥2,000', '¥2,180', '超出'],
                    ['合计', '¥3,200', '¥3,160', ''],
                  ],
                ),
                AssistantSpreadsheetSheet(
                  name: '明细',
                  rows: [
                    ['日期', '项目'],
                    ['7 月 24 日', '交通'],
                  ],
                ),
                AssistantSpreadsheetSheet(
                  name: '说明',
                  rows: [
                    ['说明'],
                    ['金额为含税价格'],
                  ],
                ),
              ],
            ),
          ),
          onDownload: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('artifact-spreadsheet-preview')),
      findsOneWidget,
    );
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('¥1,200'), findsOneWidget);
    expect(find.text('正常'), findsOneWidget);
    expect(find.text('超出'), findsOneWidget);
    expect(find.text('合计'), findsOneWidget);
    expect(find.text('工作表 1 / 3'), findsOneWidget);
    expect(
      find.byKey(const Key('artifact-spreadsheet-horizontal-scroll')),
      findsOneWidget,
    );

    final normal = tester.widget<Text>(find.text('正常'));
    final overBudget = tester.widget<Text>(find.text('超出'));
    expect(normal.style?.color, const Color(0xFF12A150));
    expect(overBudget.style?.color, const Color(0xFFE65C19));

    await tester.tap(find.byKey(const Key('artifact-spreadsheet-sheet-1')));
    await tester.pumpAndSettle();
    expect(find.text('工作表 2 / 3'), findsOneWidget);
    expect(find.text('7 月 24 日'), findsOneWidget);
  });

  testWidgets('previews generated presentation slides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantArtifactPreviewSheet(
          artifact: _artifact(
            kind: AssistantArtifactKind.presentation,
            preview: const AssistantPresentationPreview(
              title: '项目汇报',
              slides: [
                AssistantPresentationSlide(
                  title: 'Daylink 项目进展\n本周交付与下一步计划',
                  bullets: [
                    '助手文件能力\n支持文件卡片、预览与下载',
                    '日程与邀请体验\n持续优化好友选时间流程',
                    '双端稳定性\n完成 Android 与 iOS 构建验证',
                  ],
                ),
                AssistantPresentationSlide(title: '下一步计划', bullets: ['保持简洁']),
                AssistantPresentationSlide(title: '风险', bullets: []),
                AssistantPresentationSlide(title: '数据', bullets: []),
                AssistantPresentationSlide(title: '总结', bullets: []),
              ],
            ),
          ),
          onDownload: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('artifact-presentation-preview')),
      findsOneWidget,
    );
    expect(find.text('Daylink 项目进展'), findsOneWidget);
    expect(find.text('支持文件卡片、预览与下载'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(
      find.byKey(const Key('artifact-presentation-page-dots')),
      findsOneWidget,
    );

    await tester.fling(find.byType(PageView), const Offset(-430, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('下一步计划'), findsOneWidget);
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
