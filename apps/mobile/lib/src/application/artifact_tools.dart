import '../data/artifact_client.dart';
import '../data/artifact_repository.dart';
import '../domain/ai/tool_protocol.dart';

class ArtifactTools {
  ArtifactTools({required this.generator, required this.sink});

  final ArtifactGenerator generator;
  final ArtifactSink sink;

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
    final artifact = await generator.generate({'kind': kind, ...arguments});
    final saved = await sink.save(
      title: arguments['title']! as String,
      artifact: artifact,
    );
    return {
      'created': true,
      'artifact_ref': saved.id,
      'display_name': saved.displayName,
      'content_type': saved.contentType,
      'byte_size': saved.byteSize,
    };
  }
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
