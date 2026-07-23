import 'dart:typed_data';

const maximumAssistantInputFileBytes = 10 << 20;
const maximumAssistantInputFilesBytes = 20 << 20;
const maximumAssistantInputFiles = 5;

class AssistantInputFile {
  AssistantInputFile({
    required String filename,
    required this.contentType,
    required Uint8List bytes,
  }) : filename = _safeFilename(filename),
       bytes = Uint8List.fromList(bytes) {
    if (contentType.isEmpty || contentType.length > 160) {
      throw ArgumentError('invalid file content type');
    }
    if (this.bytes.isEmpty ||
        this.bytes.length > maximumAssistantInputFileBytes) {
      throw ArgumentError('file size is outside the allowed range');
    }
    if (!_matchesDeclaredType(contentType, this.bytes)) {
      throw ArgumentError('file content does not match its declared type');
    }
  }

  final String filename;
  final String contentType;
  bool get isImage => contentType.startsWith('image/');

  /// Kept only in memory for the current request. No local path is included in
  /// the model payload, logs, conversation state, or sync data.
  final Uint8List bytes;
}

bool _matchesDeclaredType(
  String contentType,
  Uint8List bytes,
) => switch (contentType) {
  'application/pdf' =>
    bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
  'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b,
  'image/png' =>
    bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a,
  'image/jpeg' =>
    bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff,
  'image/webp' =>
    bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50,
  _ => true,
};

String _safeFilename(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty || normalized == '.' || normalized == '..') {
    throw ArgumentError('invalid file name');
  }
  return normalized.length <= 160
      ? normalized
      : normalized.substring(normalized.length - 160);
}
