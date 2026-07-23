import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'assistant_conversation.dart';

const maximumAssistantExportCharacters = 200000;
const maximumAssistantExportPages = 50;

abstract interface class AssistantConversationExportSource {
  Future<void> export(
    AssistantConversationExportDocument document, {
    required AssistantConversationExportFormat format,
    required Rect sharePositionOrigin,
  });
}

class AssistantConversationExportActions
    implements AssistantConversationExportSource {
  const AssistantConversationExportActions();

  @override
  Future<void> export(
    AssistantConversationExportDocument document, {
    required AssistantConversationExportFormat format,
    required Rect sharePositionOrigin,
  }) async {
    final encoder = const AssistantConversationExportEncoder();
    final bytes = switch (format) {
      AssistantConversationExportFormat.pdf => await encoder.buildPdf(document),
      AssistantConversationExportFormat.markdown => encoder.buildMarkdown(
        document,
      ),
    };
    final directory = await getTemporaryDirectory();
    final filename =
        '${_safeExportFilename(document.title)}.${format.extension}';
    final file = File(path.join(directory.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, name: filename, mimeType: format.contentType)],
        subject: document.title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

class AssistantConversationExportEncoder {
  const AssistantConversationExportEncoder();

  Uint8List buildMarkdown(AssistantConversationExportDocument document) {
    _validateDocument(document);
    final buffer = StringBuffer('# ${document.title.trim()}\n');
    for (var index = 0; index < document.turns.length; index++) {
      final turn = document.turns[index];
      buffer
        ..writeln()
        ..writeln('## 对话 ${index + 1}')
        ..writeln()
        ..writeln('### 你')
        ..writeln()
        ..writeln(turn.prompt.trim());
      if (turn.sourceFileNames.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln(
            '附件：${turn.sourceFileNames.map((name) => '`$name`').join('、')}',
          );
      }
      buffer
        ..writeln()
        ..writeln('### Daylink')
        ..writeln()
        ..writeln(turn.response.trim());
      if (turn.artifactNames.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln(
            '生成文件：${turn.artifactNames.map((name) => '`$name`').join('、')}',
          );
      }
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> buildPdf(
    AssistantConversationExportDocument document,
  ) async {
    _validateDocument(document);
    const pageWidth = 1240;
    const pageHeight = 1754;
    const horizontalMargin = 100.0;
    const topMargin = 105.0;
    const bottomMargin = 100.0;
    const contentWidth = pageWidth - horizontalMargin * 2;
    final lines = _pdfLines(document);
    final pages = <List<_PdfLine>>[];
    var page = <_PdfLine>[];
    var usedHeight = topMargin;
    for (final line in lines) {
      final painter = _linePainter(line, contentWidth);
      final requiredHeight = line.gapBefore + painter.height;
      if (page.isNotEmpty &&
          usedHeight + requiredHeight > pageHeight - bottomMargin) {
        pages.add(page);
        if (pages.length >= maximumAssistantExportPages) {
          throw const AssistantConversationExportException('对话内容过长，无法导出');
        }
        page = <_PdfLine>[];
        usedHeight = topMargin;
      }
      page.add(line);
      usedHeight += requiredHeight;
    }
    if (page.isNotEmpty) pages.add(page);

    final images = <_PdfImage>[];
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, pageWidth.toDouble(), pageHeight.toDouble()),
        Paint()..color = Colors.white,
      );
      var y = topMargin;
      for (final line in pages[pageIndex]) {
        y += line.gapBefore;
        final painter = _linePainter(line, contentWidth);
        painter.paint(canvas, Offset(horizontalMargin, y));
        y += painter.height;
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(pageWidth, pageHeight);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) {
        throw const AssistantConversationExportException('无法生成 PDF 页面');
      }
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final rgb = Uint8List(pageWidth * pageHeight * 3);
      for (var source = 0, target = 0; source < rgba.length; source += 4) {
        rgb[target++] = rgba[source];
        rgb[target++] = rgba[source + 1];
        rgb[target++] = rgba[source + 2];
      }
      images.add(
        _PdfImage(
          width: pageWidth,
          height: pageHeight,
          compressedRgb: Uint8List.fromList(zlib.encode(rgb)),
        ),
      );
    }
    return _buildImagePdf(images);
  }
}

List<_PdfLine> _pdfLines(AssistantConversationExportDocument document) {
  final lines = <_PdfLine>[
    _PdfLine(
      document.title.trim(),
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1F2329),
    ),
    const _PdfLine(
      'Daylink 对话导出',
      fontSize: 24,
      color: Color(0xFF8F959E),
      gapBefore: 16,
    ),
  ];
  for (var index = 0; index < document.turns.length; index++) {
    final turn = document.turns[index];
    lines
      ..add(
        _PdfLine(
          '你 · 对话 ${index + 1}',
          fontSize: 27,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3370FF),
          gapBefore: index == 0 ? 58 : 70,
        ),
      )
      ..addAll(
        _chunkText(turn.prompt).map(
          (text) => _PdfLine(
            text,
            fontSize: 27,
            color: const Color(0xFF1F2329),
            gapBefore: 12,
          ),
        ),
      );
    if (turn.sourceFileNames.isNotEmpty) {
      lines.add(
        _PdfLine(
          '附件：${turn.sourceFileNames.join('、')}',
          fontSize: 22,
          color: const Color(0xFF646A73),
          gapBefore: 12,
        ),
      );
    }
    lines
      ..add(
        const _PdfLine(
          'Daylink',
          fontSize: 27,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2329),
          gapBefore: 34,
        ),
      )
      ..addAll(
        _chunkText(turn.response).map(
          (text) => _PdfLine(
            text,
            fontSize: 27,
            color: const Color(0xFF1F2329),
            gapBefore: 12,
          ),
        ),
      );
    if (turn.artifactNames.isNotEmpty) {
      lines.add(
        _PdfLine(
          '生成文件：${turn.artifactNames.join('、')}',
          fontSize: 22,
          color: const Color(0xFF646A73),
          gapBefore: 12,
        ),
      );
    }
  }
  return lines;
}

Iterable<String> _chunkText(String value) sync* {
  for (final paragraph in value.replaceAll('\r\n', '\n').split('\n')) {
    if (paragraph.isEmpty) {
      yield ' ';
      continue;
    }
    final runes = paragraph.runes.toList(growable: false);
    for (var offset = 0; offset < runes.length; offset += 500) {
      final end = (offset + 500).clamp(0, runes.length);
      yield String.fromCharCodes(runes.sublist(offset, end));
    }
  }
}

TextPainter _linePainter(_PdfLine line, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: line.text,
      style: TextStyle(
        color: line.color,
        fontSize: line.fontSize,
        fontWeight: line.fontWeight,
        height: 1.48,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  return painter;
}

Uint8List _buildImagePdf(List<_PdfImage> images) {
  if (images.isEmpty) {
    throw const AssistantConversationExportException('没有可导出的对话');
  }
  final objectCount = 2 + images.length * 3;
  final objects = List<Uint8List?>.filled(objectCount + 1, null);
  objects[1] = _ascii('<< /Type /Catalog /Pages 2 0 R >>');
  final pageIds = <int>[];
  for (var index = 0; index < images.length; index++) {
    pageIds.add(3 + index * 3);
  }
  objects[2] = _ascii(
    '<< /Type /Pages /Count ${images.length} '
    '/Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] >>',
  );
  for (var index = 0; index < images.length; index++) {
    final image = images[index];
    final pageId = 3 + index * 3;
    final imageId = pageId + 1;
    final contentId = pageId + 2;
    objects[pageId] = _ascii(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      '/Resources << /XObject << /Im$imageId $imageId 0 R >> >> '
      '/Contents $contentId 0 R >>',
    );
    objects[imageId] = _streamObject(
      '<< /Type /XObject /Subtype /Image /Width ${image.width} '
      '/Height ${image.height} /ColorSpace /DeviceRGB '
      '/BitsPerComponent 8 /Filter /FlateDecode '
      '/Length ${image.compressedRgb.length} >>',
      image.compressedRgb,
    );
    final content = _ascii('q\n595 0 0 842 0 0 cm\n/Im$imageId Do\nQ\n');
    objects[contentId] = _streamObject(
      '<< /Length ${content.length} >>',
      content,
    );
  }

  final output = BytesBuilder(copy: false);
  output.add([...ascii.encode('%PDF-1.4\n%'), 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  final offsets = List<int>.filled(objectCount + 1, 0);
  for (var id = 1; id <= objectCount; id++) {
    offsets[id] = output.length;
    output
      ..add(_ascii('$id 0 obj\n'))
      ..add(objects[id]!)
      ..add(_ascii('\nendobj\n'));
  }
  final xrefOffset = output.length;
  output.add(_ascii('xref\n0 ${objectCount + 1}\n'));
  output.add(_ascii('0000000000 65535 f \n'));
  for (var id = 1; id <= objectCount; id++) {
    output.add(_ascii('${offsets[id].toString().padLeft(10, '0')} 00000 n \n'));
  }
  output.add(
    _ascii(
      'trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n',
    ),
  );
  return output.takeBytes();
}

Uint8List _streamObject(String dictionary, Uint8List contents) {
  final builder = BytesBuilder(copy: false)
    ..add(_ascii('$dictionary\nstream\n'))
    ..add(contents)
    ..add(_ascii('\nendstream'));
  return builder.takeBytes();
}

Uint8List _ascii(String value) => Uint8List.fromList(ascii.encode(value));

void _validateDocument(AssistantConversationExportDocument document) {
  final title = document.title.trim();
  if (title.isEmpty || title.length > 160 || document.turns.isEmpty) {
    throw const AssistantConversationExportException('没有可导出的对话');
  }
  var characters = title.length;
  for (final turn in document.turns) {
    characters += turn.prompt.length + turn.response.length;
    characters += turn.sourceFileNames.fold<int>(
      0,
      (total, value) => total + value.length,
    );
    characters += turn.artifactNames.fold<int>(
      0,
      (total, value) => total + value.length,
    );
  }
  if (characters > maximumAssistantExportCharacters) {
    throw const AssistantConversationExportException('对话内容过长，无法导出');
  }
}

String _safeExportFilename(String value) {
  final safe = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final normalized = safe.isEmpty ? 'Daylink 对话' : safe;
  return normalized.length <= 80
      ? normalized
      : normalized.substring(0, 80).trim();
}

class _PdfLine {
  const _PdfLine(
    this.text, {
    required this.fontSize,
    required this.color,
    this.fontWeight = FontWeight.w400,
    this.gapBefore = 0,
  });

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double gapBefore;
}

class _PdfImage {
  const _PdfImage({
    required this.width,
    required this.height,
    required this.compressedRgb,
  });

  final int width;
  final int height;
  final Uint8List compressedRgb;
}

class AssistantConversationExportException implements Exception {
  const AssistantConversationExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
