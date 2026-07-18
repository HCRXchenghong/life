import 'package:daylink_mobile/src/domain/poster/poster_template_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

void main() {
  test('binds dynamic text and creates a friend-specific QR matrix', () {
    final first = _data(
      friendName: '小明',
      salutation: '小明，周末一起出发吧！',
      inviteUrl: Uri.parse('https://daylink.example/i/friend-one'),
    );
    final second = _data(
      friendName: '小雨',
      salutation: '小雨，这次一起去走走吧！',
      inviteUrl: Uri.parse('https://daylink.example/i/friend-two'),
    );
    final firstQR = _qrBits(first.inviteUrl);
    final secondQR = _qrBits(second.inviteUrl);

    expect(first.bindings['salutation'], contains('小明'));
    expect(second.bindings['privateHint'], contains('小雨'));
    expect(first.bindings['inviteUrl'], first.inviteUrl.toString());
    expect(second.bindings['inviteUrl'], second.inviteUrl.toString());
    expect(firstQR, isNot(equals(secondQR)));
  });

  test('rejects executable or remote-resource template layers', () {
    final json = _templateJson();
    final schema = json['schema']! as Map<String, Object?>;
    schema['layers'] = [
      {
        'type': 'html',
        'binding': 'inviteUrl',
        'x': 0,
        'y': 0,
        'width': 300,
        'height': 300,
      },
    ];

    expect(() => PosterTemplate.fromJson(json), throwsFormatException);
  });
}

List<bool> _qrBits(Uri value) {
  final code = QrCode(
    payload: QrPayload.fromString(value.toString()),
    errorCorrectLevel: QrErrorCorrectLevel.high,
  );
  final image = QrImage(code);
  return [
    for (var row = 0; row < image.moduleCount; row++)
      for (var column = 0; column < image.moduleCount; column++)
        image.isDark(row, column),
  ];
}

PosterRenderData _data({
  required String friendName,
  required String salutation,
  required Uri inviteUrl,
}) => PosterRenderData(
  friendName: friendName,
  salutation: salutation,
  activityTitle: '周末出游',
  activityDescription: '选择你方便的日期和时间',
  dateRange: '7月25日—7月26日 可选时段',
  deadline: '截止 7月23日 18:00',
  organizerName: '',
  inviteUrl: inviteUrl,
);

Map<String, Object?> _templateJson() => {
  'id': 'minimal-blue',
  'code': 'minimal-blue',
  'name': '极简蓝白',
  'status': 'published',
  'version': 1,
  'builtIn': true,
  'schemaHash':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'schema': {
    'schemaVersion': 1,
    'canvas': {'width': 360, 'height': 480, 'backgroundColor': '#FFFFFF'},
    'layers': [
      {
        'type': 'text',
        'binding': 'salutation',
        'x': 24,
        'y': 24,
        'width': 312,
        'height': 100,
        'fontSize': 36,
        'minFontSize': 18,
        'maxLines': 3,
        'fontWeight': 700,
        'color': '#1F2329',
        'align': 'start',
      },
      {
        'type': 'qr',
        'binding': 'inviteUrl',
        'x': 100,
        'y': 220,
        'width': 160,
        'height': 160,
        'quietZone': 12,
      },
    ],
  },
};
