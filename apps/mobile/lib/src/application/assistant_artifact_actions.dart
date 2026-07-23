import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/ai/assistant_artifact_models.dart';

abstract interface class AssistantArtifactActionSource {
  Future<void> download(
    AssistantGeneratedArtifact artifact, {
    required Rect sharePositionOrigin,
  });
}

class AssistantArtifactActions implements AssistantArtifactActionSource {
  const AssistantArtifactActions();

  @override
  Future<void> download(
    AssistantGeneratedArtifact artifact, {
    required Rect sharePositionOrigin,
  }) async {
    final file = File(artifact.localPath);
    if (!await file.exists()) {
      throw const FileSystemException('artifact is no longer available');
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            artifact.localPath,
            name: artifact.displayName,
            mimeType: artifact.contentType,
          ),
        ],
        subject: artifact.displayName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
