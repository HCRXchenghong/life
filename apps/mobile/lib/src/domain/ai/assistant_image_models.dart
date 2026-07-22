import 'dart:typed_data';

enum AssistantImageSize {
  square('1024x1024', '1:1'),
  landscape('1536x1024', '3:2'),
  portrait('1024x1536', '2:3');

  const AssistantImageSize(this.wireName, this.label);

  final String wireName;
  final String label;
}

enum AssistantImageQuality {
  low('low', '快速'),
  medium('medium', '标准'),
  high('high', '高清');

  const AssistantImageQuality(this.wireName, this.label);

  final String wireName;
  final String label;
}

class AssistantGeneratedImage {
  const AssistantGeneratedImage({
    required this.bytes,
    required this.prompt,
    required this.size,
    required this.quality,
    required this.createdAt,
    this.revisedPrompt,
  });

  final Uint8List bytes;
  final String prompt;
  final String? revisedPrompt;
  final AssistantImageSize size;
  final AssistantImageQuality quality;
  final DateTime createdAt;
}
