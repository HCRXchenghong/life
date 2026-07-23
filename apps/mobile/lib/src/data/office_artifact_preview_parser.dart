import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/ai/assistant_artifact_models.dart';

const _maximumOfficeFileBytes = 24 << 20;
const _maximumExpandedOfficeBytes = 64 << 20;
const _maximumPackageEntries = 2048;
const _maximumXmlPartBytes = 8 << 20;

class ArtifactPreviewException implements Exception {
  const ArtifactPreviewException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ArtifactPreviewException($code): $message';
}

/// Reads the persisted OOXML payload itself. Preview content never comes from
/// model arguments or a sample fallback.
class OfficeArtifactPreviewParser {
  const OfficeArtifactPreviewParser();

  AssistantArtifactPreview parse({
    required Uint8List bytes,
    required AssistantArtifactKind kind,
    required String titleHint,
  }) {
    try {
      final package = _openPackage(bytes);
      return switch (kind) {
        AssistantArtifactKind.document => _parseDocument(package, titleHint),
        AssistantArtifactKind.spreadsheet => _parseSpreadsheet(
          package,
          titleHint,
        ),
        AssistantArtifactKind.presentation => _parsePresentation(
          package,
          titleHint,
        ),
      };
    } on ArtifactPreviewException {
      rethrow;
    } on Object {
      throw const ArtifactPreviewException('invalid_office_file', '文件内容无法解析');
    }
  }
}

Archive _openPackage(Uint8List bytes) {
  if (bytes.length < 4 ||
      bytes.length > _maximumOfficeFileBytes ||
      bytes[0] != 0x50 ||
      bytes[1] != 0x4b) {
    throw const ArtifactPreviewException(
      'invalid_office_file',
      '文件不是有效的 Office 文档',
    );
  }
  final package = ZipDecoder().decodeBytes(bytes);
  if (package.isEmpty || package.length > _maximumPackageEntries) {
    throw const ArtifactPreviewException(
      'unsafe_office_package',
      'Office 文件结构超出安全限制',
    );
  }
  var expandedBytes = 0;
  for (final entry in package) {
    if (_unsafePackagePath(entry.name) || entry.isSymbolicLink) {
      throw const ArtifactPreviewException(
        'unsafe_office_package',
        'Office 文件包含不安全的内部路径',
      );
    }
    expandedBytes += entry.size;
    if (entry.size < 0 || expandedBytes > _maximumExpandedOfficeBytes) {
      throw const ArtifactPreviewException(
        'unsafe_office_package',
        'Office 文件解压后超出安全限制',
      );
    }
  }
  if (package.find('[Content_Types].xml') == null) {
    throw const ArtifactPreviewException(
      'invalid_office_file',
      'Office 文件缺少必要结构',
    );
  }
  return package;
}

bool _unsafePackagePath(String value) {
  final normalized = value.replaceAll('\\', '/');
  return normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
      normalized.split('/').contains('..');
}

AssistantDocumentPreview _parseDocument(Archive package, String titleHint) {
  final document = _xmlPart(package, 'word/document.xml');
  final paragraphs = _elements(document, 'p')
      .map((paragraph) => _joinedText(paragraph))
      .where((text) => text.isNotEmpty)
      .take(200)
      .toList(growable: true);
  if (paragraphs.isEmpty) {
    throw const ArtifactPreviewException(
      'empty_office_file',
      'Word 文档没有可预览的正文',
    );
  }
  final metadataTitle = _coreTitle(package);
  final title = _firstNonEmpty([metadataTitle, titleHint, paragraphs.first]);
  if (paragraphs.isNotEmpty && paragraphs.first.trim() == title.trim()) {
    paragraphs.removeAt(0);
  }
  return AssistantDocumentPreview(
    title: title,
    paragraphs: List.unmodifiable(paragraphs),
  );
}

AssistantSpreadsheetPreview _parseSpreadsheet(
  Archive package,
  String titleHint,
) {
  final workbook = _xmlPart(package, 'xl/workbook.xml');
  final relationships = _relationships(
    package,
    'xl/_rels/workbook.xml.rels',
    basePart: 'xl/workbook.xml',
  );
  final sharedStrings = _sharedStrings(package);
  final sheets = <AssistantSpreadsheetSheet>[];
  for (final sheet in _elements(workbook, 'sheet').take(10)) {
    final name = _attribute(sheet, 'name').trim();
    final relationID = _attribute(sheet, 'id').trim();
    final target = relationships[relationID];
    if (name.isEmpty || target == null) {
      throw const ArtifactPreviewException(
        'invalid_office_file',
        'Excel 工作表关系无效',
      );
    }
    final worksheet = _xmlPart(package, target);
    sheets.add(
      AssistantSpreadsheetSheet(
        name: name,
        rows: _spreadsheetRows(worksheet, sharedStrings),
      ),
    );
  }
  if (sheets.isEmpty) {
    throw const ArtifactPreviewException(
      'empty_office_file',
      'Excel 文件没有可预览的工作表',
    );
  }
  return AssistantSpreadsheetPreview(
    title: _firstNonEmpty([_coreTitle(package), titleHint, sheets.first.name]),
    sheets: List.unmodifiable(sheets),
  );
}

List<List<String>> _spreadsheetRows(
  XmlDocument worksheet,
  List<String> sharedStrings,
) {
  final rows = <List<String>>[];
  for (final row in _elements(worksheet, 'row').take(1000)) {
    final values = <String>[];
    var sequentialColumn = 0;
    for (final cell in _childElements(row, 'c').take(50)) {
      final reference = _attribute(cell, 'r');
      final column = _spreadsheetColumnIndex(reference) ?? sequentialColumn;
      if (column >= 50) continue;
      while (values.length <= column) {
        values.add('');
      }
      values[column] = _spreadsheetCellValue(cell, sharedStrings);
      sequentialColumn = column + 1;
    }
    rows.add(List.unmodifiable(values));
  }
  return List.unmodifiable(rows);
}

String _spreadsheetCellValue(XmlElement cell, List<String> sharedStrings) {
  final type = _attribute(cell, 't');
  if (type == 'inlineStr') return _joinedText(cell);
  final raw = _firstElementText(cell, 'v');
  if (type == 's') {
    final index = int.tryParse(raw);
    if (index == null || index < 0 || index >= sharedStrings.length) {
      throw const ArtifactPreviewException(
        'invalid_office_file',
        'Excel 共享文本索引无效',
      );
    }
    return sharedStrings[index];
  }
  if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';
  return raw;
}

List<String> _sharedStrings(Archive package) {
  if (package.find('xl/sharedStrings.xml') == null) return const [];
  final document = _xmlPart(package, 'xl/sharedStrings.xml');
  return _elements(
    document,
    'si',
  ).map(_joinedText).take(10000).toList(growable: false);
}

int? _spreadsheetColumnIndex(String reference) {
  final match = RegExp(r'^([A-Za-z]+)').firstMatch(reference);
  if (match == null) return null;
  var value = 0;
  for (final code in match.group(1)!.toUpperCase().codeUnits) {
    value = value * 26 + code - 64;
  }
  return value - 1;
}

AssistantPresentationPreview _parsePresentation(
  Archive package,
  String titleHint,
) {
  final presentation = _xmlPart(package, 'ppt/presentation.xml');
  final relationships = _relationships(
    package,
    'ppt/_rels/presentation.xml.rels',
    basePart: 'ppt/presentation.xml',
  );
  final slides = <AssistantPresentationSlide>[];
  for (final slideID in _elements(presentation, 'sldId').take(50)) {
    final relationID = _attribute(slideID, 'id');
    final target = relationships[relationID];
    if (target == null) {
      throw const ArtifactPreviewException('invalid_office_file', 'PPT 页面关系无效');
    }
    final slide = _xmlPart(package, target);
    final blocks = _elements(slide, 'sp')
        .expand((shape) => _elements(shape, 'p'))
        .map(_joinedText)
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final text = blocks.isNotEmpty
        ? blocks
        : _elements(slide, 't')
              .map((element) => element.innerText.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
    if (text.isEmpty) {
      slides.add(
        AssistantPresentationSlide(
          title: '第 ${slides.length + 1} 页',
          bullets: const [],
        ),
      );
    } else {
      slides.add(
        AssistantPresentationSlide(
          title: text.first,
          bullets: List.unmodifiable(text.skip(1).take(30)),
        ),
      );
    }
  }
  if (slides.isEmpty) {
    throw const ArtifactPreviewException('empty_office_file', 'PPT 文件没有可预览的页面');
  }
  return AssistantPresentationPreview(
    title: _firstNonEmpty([_coreTitle(package), titleHint, slides.first.title]),
    slides: List.unmodifiable(slides),
  );
}

Map<String, String> _relationships(
  Archive package,
  String relationshipPart, {
  required String basePart,
}) {
  final document = _xmlPart(package, relationshipPart);
  final result = <String, String>{};
  for (final relationship in _elements(document, 'Relationship')) {
    final id = _attribute(relationship, 'Id');
    final target = _attribute(relationship, 'Target');
    final targetMode = _attribute(relationship, 'TargetMode');
    if (id.isEmpty ||
        target.isEmpty ||
        targetMode.toLowerCase() == 'external') {
      continue;
    }
    final resolved = Uri.parse(basePart).resolve(target).path;
    if (_unsafePackagePath(resolved)) {
      throw const ArtifactPreviewException(
        'unsafe_office_package',
        'Office 文件关系包含不安全路径',
      );
    }
    result[id] = resolved;
  }
  return result;
}

String _coreTitle(Archive package) {
  if (package.find('docProps/core.xml') == null) return '';
  final document = _xmlPart(package, 'docProps/core.xml');
  return _elements(document, 'title').firstOrNull?.innerText.trim() ?? '';
}

XmlDocument _xmlPart(Archive package, String name) {
  final entry = package.find(name);
  if (entry == null ||
      !entry.isFile ||
      entry.size < 0 ||
      entry.size > _maximumXmlPartBytes) {
    throw ArtifactPreviewException(
      'invalid_office_file',
      'Office 文件缺少必要内容：$name',
    );
  }
  try {
    return XmlDocument.parse(utf8.decode(entry.content));
  } on Object {
    throw const ArtifactPreviewException(
      'invalid_office_file',
      'Office 文件包含无效 XML',
    );
  }
}

Iterable<XmlElement> _elements(XmlNode node, String localName) => node
    .descendants
    .whereType<XmlElement>()
    .where((element) => element.name.local == localName);

Iterable<XmlElement> _childElements(XmlNode node, String localName) => node
    .children
    .whereType<XmlElement>()
    .where((element) => element.name.local == localName);

String _attribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return '';
}

String _joinedText(XmlElement element) =>
    _elements(element, 't').map((node) => node.innerText).join().trim();

String _firstElementText(XmlElement element, String localName) =>
    _elements(element, localName).firstOrNull?.innerText.trim() ?? '';

String _firstNonEmpty(Iterable<String> values) => values
    .map((value) => value.trim())
    .firstWhere((value) => value.isNotEmpty, orElse: () => 'Daylink 文档');
