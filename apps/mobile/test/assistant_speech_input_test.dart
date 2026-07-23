import 'dart:async';

import 'package:daylink_mobile/src/application/assistant_speech_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bridges a bounded native transcript without exposing audio', () async {
    const channel = MethodChannel('test.daylink/speech');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final source = NativeAssistantSpeechInputSource(channel: channel);
    addTearDown(() async {
      await source.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await source.start(locale: '../../invalid');
    final start = calls.single;
    expect(start.method, 'start');
    final arguments = Map<Object?, Object?>.from(start.arguments as Map);
    final sessionId = arguments['sessionId']! as String;
    expect(arguments['locale'], 'zh-CN');
    expect(arguments, isNot(contains('audio')));
    expect(arguments, isNot(contains('path')));

    final update = source.updates.first;
    await _sendNativeCall(
      channel,
      MethodCall('onPartial', {
        'sessionId': sessionId,
        'transcript': '  周六下午\n和朋友出去  ',
      }),
    );
    expect(
      await update,
      isA<AssistantSpeechUpdate>()
          .having((value) => value.transcript, 'transcript', '周六下午 和朋友出去')
          .having((value) => value.isFinal, 'isFinal', isFalse),
    );

    await source.stop();
    expect(calls.last.method, 'stop');
    expect(
      (calls.last.arguments as Map<Object?, Object?>)['sessionId'],
      sessionId,
    );
  });

  test('maps native permission denial to a safe Chinese error', () async {
    const channel = MethodChannel('test.daylink/speech-denied');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'permission_denied');
        });
    final source = NativeAssistantSpeechInputSource(channel: channel);
    addTearDown(() async {
      await source.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await expectLater(
      source.start(),
      throwsA(
        isA<AssistantSpeechException>()
            .having((error) => error.code, 'code', 'permission_denied')
            .having((error) => error.message, 'message', '需要开启麦克风和语音识别权限'),
      ),
    );
  });
}

Future<void> _sendNativeCall(MethodChannel channel, MethodCall call) async {
  final completer = Completer<void>();
  final data = const StandardMethodCodec().encodeMethodCall(call);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel.name, data, (ByteData? _) {
        completer.complete();
      });
  await completer.future;
}
