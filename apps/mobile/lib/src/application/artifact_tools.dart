import '../data/artifact_client.dart';
import '../data/artifact_repository.dart';
import '../data/office_artifact_preview_parser.dart';
import '../domain/ai/assistant_artifact_models.dart';
import '../domain/ai/tool_protocol.dart';

class ArtifactTools {
  ArtifactTools({
    required this.generator,
    required this.sink,
    this.previewParser = const OfficeArtifactPreviewParser(),
    this.onCreated,
  });

  final ArtifactGenerator generator;
  final ArtifactSink sink;
  final OfficeArtifactPreviewParser previewParser;
  final void Function(AssistantGeneratedArtifact artifact)? onCreated;

  void register(ToolRegistry registry) {
    registry
      ..register(
        _spec(
          name: 'daylink_create_word_document',
          description:
              'Create a Word document only from content supplied in this request. It never reads a server or SSH host.',
          properties: {
            'title': _text(1, 160),
            'paragraphs': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 200,
              'items': _text(0, 5000),
            },
          },
          required: const ['title', 'paragraphs'],
        ),
        (arguments) => _create('docx', arguments),
      )
      ..register(
        _spec(
          name: 'daylink_create_spreadsheet',
          description:
              'Create an Excel workbook only from cells supplied in this request. It never reads a server or SSH host.',
          properties: {
            'title': _text(1, 160),
            'sheets': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 10,
              'items': {
                'type': 'object',
                'properties': {
                  'name': _text(1, 31),
                  'rows': {
                    'type': 'array',
                    'maxItems': 1000,
                    'items': {
                      'type': 'array',
                      'maxItems': 50,
                      'items': _text(0, 4000),
                    },
                  },
                },
                'required': ['name', 'rows'],
                'additionalProperties': false,
              },
            },
          },
          required: const ['title', 'sheets'],
        ),
        (arguments) => _create('xlsx', arguments),
      )
      ..register(
        _spec(
          name: 'daylink_create_presentation',
          description:
              'Create a PowerPoint presentation only from slides supplied in this request. It never reads a server or SSH host.',
          properties: {
            'title': _text(1, 160),
            'slides': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 50,
              'items': {
                'type': 'object',
                'properties': {
                  'title': _text(1, 240),
                  'bullets': {
                    'type': 'array',
                    'maxItems': 30,
                    'items': _text(0, 1000),
                  },
                },
                'required': ['title', 'bullets'],
                'additionalProperties': false,
              },
            },
          },
          required: const ['title', 'slides'],
        ),
        (arguments) => _create('pptx', arguments),
      );
  }

  Future<Object?> _create(String kind, Map<String, Object?> arguments) async {
    try {
      final artifact = await generator.generate({'kind': kind, ...arguments});
      if (artifact.extension != kind) {
        throw StateError('artifact type did not match the requested format');
      }
      final artifactKind = AssistantArtifactKind.parse(artifact.extension);
      final preview = previewParser.parse(
        bytes: artifact.bytes,
        kind: artifactKind,
        titleHint: arguments['title']! as String,
      );
      final saved = await sink.save(
        title: arguments['title']! as String,
        artifact: artifact,
      );
      onCreated?.call(
        AssistantGeneratedArtifact(
          id: saved.id,
          kind: artifactKind,
          displayName: saved.displayName,
          contentType: saved.contentType,
          byteSize: saved.byteSize,
          localPath: saved.localPath,
          preview: preview,
        ),
      );
      return {
        'created': true,
        'artifact_ref': saved.id,
        'display_name': saved.displayName,
        'content_type': saved.contentType,
        'byte_size': saved.byteSize,
      };
    } on Object {
      // File-system exceptions often include a private sandbox path. Never
      // return that path to the model through a tool error.
      throw const ArtifactToolException('artifact_creation_failed');
    }
  }
}

class ArtifactToolException implements Exception {
  const ArtifactToolException(this.code);

  final String code;

  @override
  String toString() => 'ArtifactToolException($code)';
}

ToolSpec _spec({
  required String name,
  required String description,
  required Map<String, Object?> properties,
  required List<String> required,
}) => ToolSpec(
  name: name,
  description: description,
  inputSchema: {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': false,
  },
  risk: ToolRisk.medium,
  approval: ToolApprovalPolicy.always,
  sandbox: ToolSandbox.localData,
  timeout: const Duration(seconds: 45),
);

Map<String, Object?> _text(int minimum, int maximum) => {
  'type': 'string',
  'minLength': minimum,
  'maxLength': maximum,
};
