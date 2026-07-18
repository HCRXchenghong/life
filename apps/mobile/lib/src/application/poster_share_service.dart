import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PosterShareService {
  const PosterShareService();

  Future<void> saveToGallery({
    required Uint8List bytes,
    required String inviteId,
  }) async {
    final file = await _writeTemporary(bytes, inviteId);
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    if (!await Gal.hasAccess()) {
      throw const PosterShareException('没有相册写入权限');
    }
    await Gal.putImage(file.path);
  }

  Future<void> share({
    required Uint8List bytes,
    required String inviteId,
    required Uri inviteUrl,
    required String activityTitle,
    required Rect sharePositionOrigin,
  }) async {
    final file = await _writeTemporary(bytes, inviteId);
    await SharePlus.instance.share(
      ShareParams(
        title: '$activityTitle · Daylink',
        text: inviteUrl.toString(),
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<File> _writeTemporary(Uint8List bytes, String inviteId) async {
    final directory = await getTemporaryDirectory();
    final safeID = inviteId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    final file = File(path.join(directory.path, 'daylink-poster-$safeID.png'));
    return file.writeAsBytes(bytes, flush: true);
  }
}

class PosterShareException implements Exception {
  const PosterShareException(this.message);

  final String message;

  @override
  String toString() => message;
}
