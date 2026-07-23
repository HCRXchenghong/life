enum AssistantArtifactKind {
  document('Word 文档', 'docx'),
  spreadsheet('Excel 表格', 'xlsx'),
  presentation('PPT 演示文稿', 'pptx');

  const AssistantArtifactKind(this.label, this.extension);

  final String label;
  final String extension;

  static AssistantArtifactKind parse(String extension) => values.firstWhere(
    (kind) => kind.extension == extension.toLowerCase(),
    orElse: () => throw ArgumentError.value(
      extension,
      'extension',
      'unsupported assistant artifact',
    ),
  );
}

class AssistantGeneratedArtifact {
  const AssistantGeneratedArtifact({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.contentType,
    required this.byteSize,
    required this.localPath,
    required this.preview,
  });

  final String id;
  final AssistantArtifactKind kind;
  final String displayName;
  final String contentType;
  final int byteSize;

  /// This path remains local to the signed-in account and must never be sent
  /// back to the model, logs, analytics, or sync payloads.
  final String localPath;
  final AssistantArtifactPreview preview;
}

sealed class AssistantArtifactPreview {
  const AssistantArtifactPreview({required this.title});

  final String title;
}

class AssistantDocumentPreview extends AssistantArtifactPreview {
  const AssistantDocumentPreview({
    required super.title,
    required this.paragraphs,
  });

  final List<String> paragraphs;
}

class AssistantSpreadsheetPreview extends AssistantArtifactPreview {
  const AssistantSpreadsheetPreview({
    required super.title,
    required this.sheets,
  });

  final List<AssistantSpreadsheetSheet> sheets;
}

class AssistantSpreadsheetSheet {
  const AssistantSpreadsheetSheet({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;
}

class AssistantPresentationPreview extends AssistantArtifactPreview {
  const AssistantPresentationPreview({
    required super.title,
    required this.slides,
  });

  final List<AssistantPresentationSlide> slides;
}

class AssistantPresentationSlide {
  const AssistantPresentationSlide({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}
