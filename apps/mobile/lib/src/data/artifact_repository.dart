import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'artifact_client.dart';

abstract interface class ArtifactSink {
  Future<SavedArtifact> save({
    required String title,
    required GeneratedArtifactPayload artifact,
  });
}

class SavedArtifact {
  const SavedArtifact({
    required this.id,
    required this.displayName,
    required this.contentType,
    required this.byteSize,
    required this.localPath,
  });

  final String id;
  final String displayName;
  final String contentType;
  final int byteSize;
  final String localPath;
}

class ArtifactRepository implements ArtifactSink {
  ArtifactRepository({
    required String accountId,
    this.rootDirectory,
    this.uuid = const Uuid(),
  }) : _accountId = _validateAccountId(accountId);

  final String _accountId;
  final Directory? rootDirectory;
  final Uuid uuid;

  @override
  Future<SavedArtifact> save({
    required String title,
    required GeneratedArtifactPayload artifact,
  }) async {
    final id = uuid.v4();
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(root.path, 'daylink', 'accounts', _accountId, 'artifacts'),
    );
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '$id.${artifact.extension}'));
    await file.writeAsBytes(artifact.bytes, flush: true);
    return SavedArtifact(
      id: id,
      displayName: '${_safeDisplayName(title)}.${artifact.extension}',
      contentType: artifact.contentType,
      byteSize: artifact.bytes.length,
      localPath: file.path,
    );
  }

  Future<File> resolve(String artifactId, String extension) async {
    if (!Uuid.isValidUUID(fromString: artifactId) ||
        !const {'docx', 'xlsx', 'pptx'}.contains(extension)) {
      throw ArgumentError('invalid artifact reference');
    }
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    return File(
      p.join(
        root.path,
        'daylink',
        'accounts',
        _accountId,
        'artifacts',
        '$artifactId.$extension',
      ),
    );
  }
}

String _validateAccountId(String value) {
  if (!Uuid.isValidUUID(fromString: value)) {
    throw ArgumentError('accountId must be a UUID');
  }
  return value.toLowerCase();
}

String _safeDisplayName(String title) {
  final normalized = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^[. ]+'), '')
      .trim();
  if (normalized.isEmpty) return 'Daylink 文档';
  return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
}
