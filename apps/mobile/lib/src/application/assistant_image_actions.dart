import 'dart:io';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/ai/assistant_image_models.dart';

abstract interface class AssistantImageActionSource {
  Future<void> saveToGallery(AssistantGeneratedImage image);

  Future<void> share(
    AssistantGeneratedImage image, {
    required Rect sharePositionOrigin,
  });
}

class AssistantImageActions implements AssistantImageActionSource {
  const AssistantImageActions();

  @override
  Future<void> saveToGallery(AssistantGeneratedImage image) async {
    final file = await _writeTemporary(image);
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    if (!await Gal.hasAccess()) {
      throw const AssistantImageActionException('没有相册写入权限');
    }
    await Gal.putImage(file.path);
  }

  @override
  Future<void> share(
    AssistantGeneratedImage image, {
    required Rect sharePositionOrigin,
  }) async {
    final file = await _writeTemporary(image);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Daylink AI 图片',
        text: image.prompt,
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<File> _writeTemporary(AssistantGeneratedImage image) async {
    final directory = await getTemporaryDirectory();
    final stamp = image.createdAt.microsecondsSinceEpoch;
    final file = File(path.join(directory.path, 'daylink-ai-$stamp.png'));
    return file.writeAsBytes(image.bytes, flush: true);
  }
}

class AssistantImageActionException implements Exception {
  const AssistantImageActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
