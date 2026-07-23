import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daylink_mobile/src/data/office_artifact_preview_parser.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_artifact_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = OfficeArtifactPreviewParser();

  test('reads document preview from actual DOCX XML', () {
    final preview =
        parser.parse(
              bytes: _zip({
                '[Content_Types].xml': '<Types/>',
                'docProps/core.xml':
                    '<cp:coreProperties xmlns:cp="core" xmlns:dc="dc"><dc:title>真实周报</dc:title></cp:coreProperties>',
                'word/document.xml':
                    '<w:document xmlns:w="word"><w:body>'
                    '<w:p><w:r><w:t>真实周报</w:t></w:r></w:p>'
                    '<w:p><w:r><w:t>第一段</w:t></w:r><w:r><w:t>来自文件</w:t></w:r></w:p>'
                    '</w:body></w:document>',
              }),
              kind: AssistantArtifactKind.document,
              titleHint: '模型参数里的假标题',
            )
            as AssistantDocumentPreview;

    expect(preview.title, '真实周报');
    expect(preview.paragraphs, ['第一段来自文件']);
  });

  test('reads sheet names and cells from actual XLSX XML', () {
    final preview =
        parser.parse(
              bytes: _zip({
                '[Content_Types].xml': '<Types/>',
                'xl/workbook.xml':
                    '<workbook xmlns:r="rel"><sheets>'
                    '<sheet name="真实预算" r:id="rId1"/>'
                    '</sheets></workbook>',
                'xl/_rels/workbook.xml.rels':
                    '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
                'xl/sharedStrings.xml':
                    '<sst><si><t>项目</t></si><si><t>交通</t></si></sst>',
                'xl/worksheets/sheet1.xml':
                    '<worksheet><sheetData>'
                    '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="inlineStr"><is><t>金额</t></is></c></row>'
                    '<row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2"><v>120</v></c></row>'
                    '</sheetData></worksheet>',
              }),
              kind: AssistantArtifactKind.spreadsheet,
              titleHint: '预算',
            )
            as AssistantSpreadsheetPreview;

    expect(preview.sheets.single.name, '真实预算');
    expect(preview.sheets.single.rows, [
      ['项目', '金额'],
      ['交通', '120'],
    ]);
  });

  test('reads slide order and text from actual PPTX XML', () {
    final preview =
        parser.parse(
              bytes: _zip({
                '[Content_Types].xml': '<Types/>',
                'docProps/core.xml':
                    '<cp:coreProperties xmlns:cp="core" xmlns:dc="dc"><dc:title>真实汇报</dc:title></cp:coreProperties>',
                'ppt/presentation.xml':
                    '<p:presentation xmlns:p="ppt" xmlns:r="rel"><p:sldIdLst>'
                    '<p:sldId r:id="rId2"/>'
                    '</p:sldIdLst></p:presentation>',
                'ppt/_rels/presentation.xml.rels':
                    '<Relationships><Relationship Id="rId2" Target="slides/slide1.xml"/></Relationships>',
                'ppt/slides/slide1.xml':
                    '<p:sld xmlns:p="ppt" xmlns:a="draw"><p:sp>'
                    '<p:txBody><a:p><a:r><a:t>真实标题</a:t></a:r></a:p>'
                    '<a:p><a:r><a:t>真实要点一</a:t></a:r></a:p>'
                    '</p:txBody></p:sp></p:sld>',
              }),
              kind: AssistantArtifactKind.presentation,
              titleHint: '汇报',
            )
            as AssistantPresentationPreview;

    expect(preview.title, '真实汇报');
    expect(preview.slides.single.title, '真实标题');
    expect(preview.slides.single.bullets, ['真实要点一']);
  });

  test('fails closed instead of returning a placeholder preview', () {
    expect(
      () => parser.parse(
        bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
        kind: AssistantArtifactKind.document,
        titleHint: '不能显示这个占位标题',
      ),
      throwsA(isA<ArtifactPreviewException>()),
    );
  });
}

Uint8List _zip(Map<String, String> parts) {
  final archive = Archive();
  for (final part in parts.entries) {
    archive.add(ArchiveFile.string(part.key, part.value));
  }
  return ZipEncoder().encodeBytes(archive);
}
