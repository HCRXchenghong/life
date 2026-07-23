import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../domain/ai/assistant_input_file.dart';

abstract interface class AssistantInputFileSource {
  Future<List<AssistantInputFile>> pickFiles();
}

class AssistantFileSelectionException implements Exception {
  const AssistantFileSelectionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AssistantFileSelectionException($code): $message';
}

class DeviceAssistantInputFileSource implements AssistantInputFileSource {
  const DeviceAssistantInputFileSource();

  static const allowedExtensions = [
    'pdf',
    'txt',
    'text',
    'md',
    'markdown',
    'json',
    'xml',
    'html',
    'csv',
    'tsv',
    'doc',
    'docx',
    'rtf',
    'odt',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'c',
    'cc',
    'cpp',
    'h',
    'go',
    'java',
    'js',
    'mjs',
    'ts',
    'py',
    'rb',
    'rs',
    'swift',
    'dart',
    'sql',
    'yaml',
    'yml',
  ];

  @override
  Future<List<AssistantInputFile>> pickFiles() async {
    final result = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Daylink 支持的文件', extensions: allowedExtensions),
      ],
    );
    if (result.isEmpty) return const [];
    if (result.length > maximumAssistantInputFiles) {
      throw const AssistantFileSelectionException(
        'too_many_files',
        '一次最多添加 5 个文件',
      );
    }
    var totalBytes = 0;
    final files = <AssistantInputFile>[];
    for (final selected in result) {
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty) {
        throw const AssistantFileSelectionException(
          'file_unavailable',
          '无法读取所选文件',
        );
      }
      if (bytes.length > maximumAssistantInputFileBytes) {
        throw AssistantFileSelectionException(
          'file_too_large',
          '${selected.name} 超过 10 MB',
        );
      }
      totalBytes += bytes.length;
      if (totalBytes > maximumAssistantInputFilesBytes) {
        throw const AssistantFileSelectionException(
          'files_too_large',
          '所选文件合计不能超过 20 MB',
        );
      }
      final extension = p
          .extension(selected.name)
          .replaceFirst('.', '')
          .toLowerCase();
      final contentType = _contentTypes[extension];
      if (contentType == null) {
        throw AssistantFileSelectionException(
          'unsupported_file',
          '${selected.name} 的格式暂不支持',
        );
      }
      try {
        files.add(
          AssistantInputFile(
            filename: selected.name,
            contentType: contentType,
            bytes: bytes,
          ),
        );
      } on ArgumentError {
        throw AssistantFileSelectionException(
          'invalid_file',
          '${selected.name} 的内容与文件格式不匹配',
        );
      }
    }
    return List.unmodifiable(files);
  }
}

const _contentTypes = <String, String>{
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'text': 'text/plain',
  'md': 'text/markdown',
  'markdown': 'text/markdown',
  'json': 'application/json',
  'xml': 'text/xml',
  'html': 'text/html',
  'csv': 'text/csv',
  'tsv': 'text/tsv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'rtf': 'application/rtf',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'c': 'text/x-c',
  'cc': 'text/x-c++',
  'cpp': 'text/x-c++',
  'h': 'text/x-c',
  'go': 'text/x-golang',
  'java': 'text/x-java',
  'js': 'text/javascript',
  'mjs': 'text/javascript',
  'ts': 'application/typescript',
  'py': 'text/x-python',
  'rb': 'text/x-ruby',
  'rs': 'text/x-rust',
  'swift': 'text/x-swift',
  'dart': 'text/plain',
  'sql': 'application/x-sql',
  'yaml': 'application/yaml',
  'yml': 'application/yaml',
};
