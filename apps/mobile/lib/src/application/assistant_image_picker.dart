import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../domain/ai/assistant_input_file.dart';
import 'assistant_file_picker.dart';

abstract interface class AssistantInputImageSource {
  Future<List<AssistantInputFile>> pickImages();
}

class DeviceAssistantInputImageSource implements AssistantInputImageSource {
  const DeviceAssistantInputImageSource();

  static const allowedExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  @override
  Future<List<AssistantInputFile>> pickImages() async {
    final result = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Daylink 支持的图片', extensions: allowedExtensions),
      ],
    );
    if (result.isEmpty) return const [];
    if (result.length > maximumAssistantInputFiles) {
      throw const AssistantFileSelectionException(
        'too_many_images',
        '一次最多添加 5 张图片',
      );
    }

    var totalBytes = 0;
    final images = <AssistantInputFile>[];
    for (final selected in result) {
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty) {
        throw const AssistantFileSelectionException(
          'image_unavailable',
          '无法读取所选图片',
        );
      }
      if (bytes.length > maximumAssistantInputFileBytes) {
        throw AssistantFileSelectionException(
          'image_too_large',
          '${selected.name} 超过 10 MB',
        );
      }
      totalBytes += bytes.length;
      if (totalBytes > maximumAssistantInputFilesBytes) {
        throw const AssistantFileSelectionException(
          'images_too_large',
          '所选图片合计不能超过 20 MB',
        );
      }
      final extension = p
          .extension(selected.name)
          .replaceFirst('.', '')
          .toLowerCase();
      final contentType = _contentTypes[extension];
      if (contentType == null) {
        throw AssistantFileSelectionException(
          'unsupported_image',
          '${selected.name} 的图片格式暂不支持',
        );
      }
      try {
        images.add(
          AssistantInputFile(
            filename: selected.name,
            contentType: contentType,
            bytes: bytes,
          ),
        );
      } on ArgumentError {
        throw AssistantFileSelectionException(
          'invalid_image',
          '${selected.name} 的内容与图片格式不匹配',
        );
      }
    }
    return List.unmodifiable(images);
  }
}

const _contentTypes = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
};
