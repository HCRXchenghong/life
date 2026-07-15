import 'dart:typed_data';

import 'package:daylink_mobile/src/application/artifact_tools.dart';
import 'package:daylink_mobile/src/data/artifact_client.dart';
import 'package:daylink_mobile/src/data/artifact_repository.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Office tools require approval and never expose an internal path',
    () async {
      var approvals = 0;
      final generator = _Generator();
      final sink = _Sink();
      final registry = ToolRegistry(
        approvals: (_, _) async {
          approvals++;
          return ApprovalDecision.accept;
        },
      );
      ArtifactTools(generator: generator, sink: sink).register(registry);

      final result = await registry.invoke(
        const ToolCall(
          callId: 'document-1',
          name: 'daylink_create_word_document',
          arguments: {
            'title': '周计划',
            'paragraphs': ['按用户提供的内容生成'],
          },
        ),
      );

      expect(result.success, isTrue);
      expect(approvals, 1);
      expect(generator.request?['kind'], 'docx');
      expect(result.output.toString(), isNot(contains('/srv/daylink/private')));
      expect(result.output.toString(), isNot(contains('localPath')));
      expect(
        registry.specs.map((spec) => spec.name),
        containsAll(const [
          'daylink_create_word_document',
          'daylink_create_spreadsheet',
          'daylink_create_presentation',
        ]),
      );
    },
  );
}

class _Generator implements ArtifactGenerator {
  Map<String, Object?>? request;

  @override
  Future<GeneratedArtifactPayload> generate(
    Map<String, Object?> request,
  ) async {
    this.request = request;
    return GeneratedArtifactPayload(
      bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
      contentType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      extension: 'docx',
    );
  }
}

class _Sink implements ArtifactSink {
  @override
  Future<SavedArtifact> save({
    required String title,
    required GeneratedArtifactPayload artifact,
  }) async => SavedArtifact(
    id: '0edb14f1-926c-4e3b-ac27-aab19ee5f62d',
    displayName: '$title.docx',
    contentType: artifact.contentType,
    byteSize: artifact.bytes.length,
    localPath: '/srv/daylink/private/never-return-this.docx',
  );
}
