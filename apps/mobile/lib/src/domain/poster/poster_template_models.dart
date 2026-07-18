import 'dart:convert';

enum PosterTemplateStatus { draft, published, disabled }

class PosterTemplate {
  const PosterTemplate({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.version,
    required this.builtIn,
    required this.schemaHash,
    required this.schema,
  });

  final String id;
  final String code;
  final String name;
  final PosterTemplateStatus status;
  final int version;
  final bool builtIn;
  final String schemaHash;
  final PosterTemplateSchema schema;

  factory PosterTemplate.fromJson(Map<String, Object?> json) => PosterTemplate(
    id: _string(json, 'id'),
    code: _string(json, 'code'),
    name: _string(json, 'name'),
    status: _posterStatus(json),
    version: _integer(json, 'version'),
    builtIn: json['builtIn'] == true,
    schemaHash: _string(json, 'schemaHash'),
    schema: PosterTemplateSchema.fromJson(_map(json['schema'], 'schema')),
  );
}

class PosterTemplateSchema {
  const PosterTemplateSchema({
    required this.schemaVersion,
    required this.canvas,
    required this.layers,
  });

  final int schemaVersion;
  final PosterCanvas canvas;
  final List<PosterLayer> layers;

  factory PosterTemplateSchema.fromJson(Map<String, Object?> json) {
    final schema = PosterTemplateSchema(
      schemaVersion: _integer(json, 'schemaVersion'),
      canvas: PosterCanvas.fromJson(_map(json['canvas'], 'canvas')),
      layers: _list(json, 'layers')
          .map((value) => PosterLayer.fromJson(_map(value, 'layer')))
          .toList(growable: false),
    );
    schema.validate();
    return schema;
  }

  void validate() {
    if (schemaVersion != 1 ||
        canvas.width < 320 ||
        canvas.width > 4096 ||
        canvas.height < 480 ||
        canvas.height > 4096 ||
        layers.isEmpty ||
        layers.length > 40) {
      throw const FormatException('poster template schema is unsupported');
    }
    var qrCount = 0;
    for (final layer in layers) {
      layer.validate(canvas);
      if (layer.type == PosterLayerType.qr) qrCount++;
    }
    if (qrCount != 1) {
      throw const FormatException('poster template must contain one QR layer');
    }
  }
}

class PosterCanvas {
  const PosterCanvas({
    required this.width,
    required this.height,
    required this.backgroundColor,
  });

  final double width;
  final double height;
  final String backgroundColor;

  factory PosterCanvas.fromJson(Map<String, Object?> json) => PosterCanvas(
    width: _number(json, 'width'),
    height: _number(json, 'height'),
    backgroundColor: _color(json, 'backgroundColor'),
  );
}

enum PosterLayerType { text, qr, shape }

class PosterLayer {
  const PosterLayer({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.binding = '',
    this.shape = '',
    this.fontSize = 0,
    this.minFontSize = 0,
    this.maxLines = 0,
    this.fontWeight = 400,
    this.color = '#000000',
    this.align = 'start',
    this.fillColor = '#00000000',
    this.strokeColor = '#00000000',
    this.strokeWidth = 0,
    this.quietZone = 0,
  });

  final PosterLayerType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String binding;
  final String shape;
  final double fontSize;
  final double minFontSize;
  final int maxLines;
  final int fontWeight;
  final String color;
  final String align;
  final String fillColor;
  final String strokeColor;
  final double strokeWidth;
  final double quietZone;

  factory PosterLayer.fromJson(Map<String, Object?> json) => PosterLayer(
    type: _posterLayerType(json),
    x: _number(json, 'x'),
    y: _number(json, 'y'),
    width: _number(json, 'width'),
    height: _number(json, 'height'),
    binding: json['binding'] as String? ?? '',
    shape: json['shape'] as String? ?? '',
    fontSize: _optionalNumber(json, 'fontSize'),
    minFontSize: _optionalNumber(json, 'minFontSize'),
    maxLines: (json['maxLines'] as num?)?.toInt() ?? 0,
    fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
    color: json['color'] == null ? '#000000' : _color(json, 'color'),
    align: json['align'] as String? ?? 'start',
    fillColor: json['fillColor'] == null
        ? '#00000000'
        : _color(json, 'fillColor'),
    strokeColor: json['strokeColor'] == null
        ? '#00000000'
        : _color(json, 'strokeColor'),
    strokeWidth: _optionalNumber(json, 'strokeWidth'),
    quietZone: _optionalNumber(json, 'quietZone'),
  );

  void validate(PosterCanvas canvas) {
    final partiallyVisibleShape =
        type == PosterLayerType.shape &&
        x < canvas.width &&
        y < canvas.height &&
        x + width > 0 &&
        y + height > 0;
    final fullyInside =
        x >= 0 &&
        y >= 0 &&
        width > 0 &&
        height > 0 &&
        x + width <= canvas.width + 0.01 &&
        y + height <= canvas.height + 0.01;
    if ((!fullyInside && !partiallyVisibleShape) || width <= 0 || height <= 0) {
      throw const FormatException('poster layer is outside the canvas');
    }
    switch (type) {
      case PosterLayerType.text:
        if (!_textBindings.contains(binding) ||
            fontSize < 8 ||
            minFontSize < 8 ||
            minFontSize > fontSize ||
            maxLines < 1 ||
            maxLines > 6 ||
            !const {400, 500, 600, 700}.contains(fontWeight) ||
            !const {'start', 'center', 'end'}.contains(align)) {
          throw const FormatException('poster text layer is invalid');
        }
      case PosterLayerType.qr:
        if (binding != 'inviteUrl' ||
            width != height ||
            quietZone < 0 ||
            quietZone > 64 ||
            quietZone * 2 >= width) {
          throw const FormatException('poster QR layer is invalid');
        }
      case PosterLayerType.shape:
        if (!const {'rect', 'ellipse'}.contains(shape) ||
            strokeWidth < 0 ||
            strokeWidth > 160) {
          throw const FormatException('poster shape layer is invalid');
        }
    }
  }
}

class PosterRenderData {
  const PosterRenderData({
    required this.friendName,
    required this.salutation,
    required this.activityTitle,
    required this.activityDescription,
    required this.dateRange,
    required this.deadline,
    required this.organizerName,
    required this.inviteUrl,
  });

  final String friendName;
  final String salutation;
  final String activityTitle;
  final String activityDescription;
  final String dateRange;
  final String deadline;
  final String organizerName;
  final Uri inviteUrl;

  Map<String, String> get bindings => {
    'brandName': 'Daylink',
    'friendName': friendName,
    'salutation': salutation,
    'activityTitle': activityTitle,
    'activityDescription': activityDescription,
    'dateRange': dateRange,
    'deadline': deadline,
    'organizerName': organizerName,
    'inviteUrl': inviteUrl.toString(),
    'qrLabel': '扫码选择时间',
    'privateHint': '此邀请仅供$friendName使用',
  };
}

const _textBindings = {
  'brandName',
  'friendName',
  'salutation',
  'activityTitle',
  'activityDescription',
  'dateRange',
  'deadline',
  'organizerName',
  'qrLabel',
  'privateHint',
};

PosterTemplateStatus _posterStatus(Map<String, Object?> json) {
  try {
    return PosterTemplateStatus.values.byName(_string(json, 'status'));
  } on ArgumentError {
    throw const FormatException('poster template status is unsupported');
  }
}

PosterLayerType _posterLayerType(Map<String, Object?> json) {
  try {
    return PosterLayerType.values.byName(_string(json, 'type'));
  } on ArgumentError {
    throw const FormatException('poster layer type is unsupported');
  }
}

Map<String, Object?> decodePosterTemplateResponse(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('poster template response must be an object');
  }
  return decoded;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('poster field $key must be a non-empty string');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('poster field $key must be numeric');
  return value.toInt();
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('poster field $key must be numeric');
  }
  return value.toDouble();
}

double _optionalNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return 0;
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('poster field $key must be numeric');
  }
  return value.toDouble();
}

String _color(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(value)) {
    throw FormatException('poster field $key must be a color');
  }
  return value;
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('poster field $name must be an object');
  }
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('poster field $key must be a list');
  }
  return value;
}
