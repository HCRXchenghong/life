import 'dart:async';

import 'package:flutter/services.dart';

const _speechChannelName = 'app.daylink.daylink_mobile/speech';
const _maximumSpeechTranscriptLength = 32768;

class AssistantSpeechUpdate {
  const AssistantSpeechUpdate({
    required this.transcript,
    required this.level,
    required this.isFinal,
  });

  final String transcript;
  final double level;
  final bool isFinal;
}

abstract interface class AssistantSpeechInputSource {
  Stream<AssistantSpeechUpdate> get updates;

  Future<void> start({String locale = 'zh-CN'});

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class AssistantSpeechException implements Exception {
  const AssistantSpeechException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AssistantSpeechException($code): $message';
}

class NativeAssistantSpeechInputSource implements AssistantSpeechInputSource {
  NativeAssistantSpeechInputSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_speechChannelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final _updates = StreamController<AssistantSpeechUpdate>.broadcast();
  String? _activeSessionId;
  String _transcript = '';
  double _level = 0;
  var _disposed = false;
  var _nextSession = 0;

  @override
  Stream<AssistantSpeechUpdate> get updates => _updates.stream;

  @override
  Future<void> start({String locale = 'zh-CN'}) async {
    if (_disposed) {
      throw const AssistantSpeechException('disposed', '语音输入已经关闭');
    }
    if (_activeSessionId != null) {
      throw const AssistantSpeechException('already_listening', '语音输入正在运行');
    }
    final sessionId =
        '${DateTime.now().microsecondsSinceEpoch}-${_nextSession++}';
    _activeSessionId = sessionId;
    _transcript = '';
    _level = 0;
    try {
      await _channel.invokeMethod<void>('start', {
        'sessionId': sessionId,
        'locale': _safeLocale(locale),
      });
    } on PlatformException catch (error) {
      if (_activeSessionId == sessionId) _activeSessionId = null;
      throw AssistantSpeechException(error.code, _platformMessage(error.code));
    } on MissingPluginException {
      if (_activeSessionId == sessionId) _activeSessionId = null;
      throw const AssistantSpeechException('unavailable', '当前设备暂不支持语音输入');
    }
  }

  @override
  Future<void> stop() => _end('stop');

  @override
  Future<void> cancel() => _end('cancel');

  Future<void> _end(String method) async {
    final sessionId = _activeSessionId;
    _activeSessionId = null;
    _level = 0;
    if (sessionId == null || _disposed) return;
    try {
      await _channel.invokeMethod<void>(method, {'sessionId': sessionId});
    } on PlatformException {
      // The UI already owns the bounded transcript. Native teardown failures
      // must not re-open or persist a completed/cancelled voice session.
    } on MissingPluginException {
      // The platform session is already unreachable.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (_disposed || call.arguments is! Map) return;
    final arguments = Map<Object?, Object?>.from(call.arguments as Map);
    final sessionId = arguments['sessionId'] as String?;
    if (sessionId == null || sessionId != _activeSessionId) return;
    switch (call.method) {
      case 'onPartial':
      case 'onFinal':
        final text = arguments['transcript'] as String? ?? '';
        _transcript = _boundedTranscript(text);
        if (call.method == 'onFinal') _level = 0;
        _emit(isFinal: call.method == 'onFinal');
      case 'onLevel':
        final raw = arguments['level'];
        if (raw is num) {
          _level = raw.toDouble().clamp(0, 1);
          _emit(isFinal: false);
        }
      case 'onError':
        final code = arguments['code'] as String? ?? 'recognition_failed';
        _activeSessionId = null;
        _level = 0;
        _updates.addError(
          AssistantSpeechException(code, _platformMessage(code)),
        );
    }
  }

  void _emit({required bool isFinal}) {
    if (_disposed) return;
    _updates.add(
      AssistantSpeechUpdate(
        transcript: _transcript,
        level: _level,
        isFinal: isFinal,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await cancel();
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await _updates.close();
  }
}

String _safeLocale(String value) {
  final normalized = value.trim();
  if (RegExp(r'^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2,4})?$').hasMatch(normalized)) {
    return normalized.replaceAll('_', '-');
  }
  return 'zh-CN';
}

String _boundedTranscript(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.length <= _maximumSpeechTranscriptLength) return normalized;
  return normalized.substring(0, _maximumSpeechTranscriptLength);
}

String _platformMessage(String code) => switch (code) {
  'permission_denied' => '需要开启麦克风和语音识别权限',
  'recognizer_unavailable' || 'unavailable' => '当前设备暂不支持语音输入',
  'network' => '语音识别网络不可用，请稍后重试',
  'no_match' => '没有识别到清晰的语音',
  'busy' || 'already_listening' => '语音识别正在使用中',
  _ => '语音识别失败，请重试',
};
