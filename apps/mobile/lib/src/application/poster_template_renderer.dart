import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../domain/poster/poster_template_models.dart';

class PosterTemplateRenderer {
  const PosterTemplateRenderer();

  Future<Uint8List> render({
    required PosterTemplate template,
    required PosterRenderData data,
    String? fontFamily,
  }) async {
    final schema = template.schema;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(schema.canvas.width, schema.canvas.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _color(schema.canvas.backgroundColor),
    );
    for (final layer in schema.layers) {
      switch (layer.type) {
        case PosterLayerType.shape:
          _paintShape(canvas, layer);
        case PosterLayerType.text:
          _paintText(
            canvas,
            layer,
            data.bindings[layer.binding] ?? '',
            fontFamily,
          );
        case PosterLayerType.qr:
          _paintQR(canvas, layer, data.inviteUrl.toString());
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('poster PNG encoding failed');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }

  void _paintShape(Canvas canvas, PosterLayer layer) {
    final rect = Rect.fromLTWH(layer.x, layer.y, layer.width, layer.height);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = _color(layer.fillColor);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = layer.strokeWidth
      ..color = _color(layer.strokeColor);
    if (layer.shape == 'ellipse') {
      canvas.drawOval(rect, fill);
      if (layer.strokeWidth > 0) canvas.drawOval(rect, stroke);
      return;
    }
    canvas.drawRect(rect, fill);
    if (layer.strokeWidth > 0) canvas.drawRect(rect, stroke);
  }

  void _paintText(
    Canvas canvas,
    PosterLayer layer,
    String value,
    String? fontFamily,
  ) {
    var fontSize = layer.fontSize;
    late TextPainter painter;
    while (true) {
      painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: _color(layer.color),
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight
                .values[(layer.fontWeight ~/ 100 - 1).clamp(0, 8).toInt()],
            height: 1.18,
            letterSpacing: -0.4,
          ),
        ),
        textAlign: switch (layer.align) {
          'center' => TextAlign.center,
          'end' => TextAlign.end,
          _ => TextAlign.start,
        },
        textDirection: TextDirection.ltr,
        maxLines: layer.maxLines,
        ellipsis: '…',
      )..layout(maxWidth: layer.width);
      if ((painter.height <= layer.height && !painter.didExceedMaxLines) ||
          fontSize <= layer.minFontSize) {
        break;
      }
      fontSize = (fontSize - 2)
          .clamp(layer.minFontSize, layer.fontSize)
          .toDouble();
    }
    painter.paint(canvas, Offset(layer.x, layer.y));
  }

  void _paintQR(Canvas canvas, PosterLayer layer, String value) {
    final rect = Rect.fromLTWH(layer.x, layer.y, layer.width, layer.height);
    canvas.drawRect(rect, Paint()..color = Colors.white);
    final qrCode = QrCode(
      payload: QrPayload.fromString(value),
      errorCorrectLevel: QrErrorCorrectLevel.high,
    );
    final qr = QrImage(qrCode);
    final contentSize = layer.width - layer.quietZone * 2;
    final moduleSize = contentSize / qr.moduleCount;
    final paint = Paint()
      ..color = const Color(0xFF090A0B)
      ..isAntiAlias = false;
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var column = 0; column < qr.moduleCount; column++) {
        if (!qr.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            layer.x + layer.quietZone + column * moduleSize,
            layer.y + layer.quietZone + row * moduleSize,
            moduleSize + 0.08,
            moduleSize + 0.08,
          ),
          paint,
        );
      }
    }
  }
}

Color _color(String value) {
  final raw = value.substring(1);
  if (raw.length == 6) return Color(int.parse('FF$raw', radix: 16));
  final red = raw.substring(0, 2);
  final green = raw.substring(2, 4);
  final blue = raw.substring(4, 6);
  final alpha = raw.substring(6, 8);
  return Color(int.parse('$alpha$red$green$blue', radix: 16));
}
