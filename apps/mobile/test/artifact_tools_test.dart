import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daylink_mobile/src/application/artifact_tools.dart';
import 'package:daylink_mobile/src/data/artifact_client.dart';
import 'package:daylink_mobile/src/data/artifact_repository.dart';
import 'package:daylink_mobile/src/domain/ai/assistant_artifact_models.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Office tools require approval and never expose an internal path',
    () async {
      var approvals = 0;
      final generator = _Generator();
      final sink = _Sink();
      final created = <AssistantGeneratedArtifact>[];
      final registry = ToolRegistry(
        approvals: (_, _) async {
          approvals++;
          return ApprovalDecision.accept;
        },
      );
      ArtifactTools(
        generator: generator,
        sink: sink,
        onCreated: created.add,
      ).register(registry);

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
      expect(created.single.displayName, '周计划.docx');
      expect((created.single.preview as AssistantDocumentPreview).paragraphs, [
        '从实际 DOCX 读取的正文',
      ]);
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

  test(
    'artifact failures never return a private local path to the model',
    () async {
      final registry = ToolRegistry(
        approvals: (_, _) async => ApprovalDecision.accept,
      );
      ArtifactTools(
        generator: _Generator(),
        sink: _FailingSink(),
      ).register(registry);

      final result = await registry.invoke(
        const ToolCall(
          callId: 'document-failure',
          name: 'daylink_create_word_document',
          arguments: {
            'title': '周计划',
            'paragraphs': ['正文'],
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.output.toString(), contains('artifact_creation_failed'));
      expect(result.output.toString(), isNot(contains('/private/daylink')));
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
      bytes: _documentBytes(),
      contentType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      extension: 'docx',
    );
  }
}

Uint8List _documentBytes() {
  final package = Archive()
    ..add(
      ArchiveFile.string(
        '[Content_Types].xml',
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
      ),
    )
    ..add(
      ArchiveFile.string(
        'word/document.xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:body><w:p><w:r><w:t>周计划</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>从实际 DOCX 读取的正文</w:t></w:r></w:p>'
            '</w:body></w:document>',
      ),
    );
  return ZipEncoder().encodeBytes(package);
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

class _FailingSink implements ArtifactSink {
  @override
  Future<SavedArtifact> save({
    required String title,
    required GeneratedArtifactPayload artifact,
  }) {
    throw const FileSystemException(
      'write failed',
      '/private/daylink/account/artifacts/secret.docx',
    );
  }
}
