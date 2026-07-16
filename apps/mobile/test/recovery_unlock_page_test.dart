import 'dart:async';

import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/recovery_unlock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the approved recovery unlock layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RecoveryUnlockPage(source: _FakeSource())),
    );

    expect(find.byKey(const Key('recovery-unlock-title')), findsOneWidget);
    expect(find.text('输入恢复密钥'), findsOneWidget);
    expect(find.text('验证后，将在此设备恢复已同步的加密内容。'), findsOneWidget);
    expect(find.text('恢复密钥'), findsOneWidget);
    expect(find.text('粘贴或输入恢复密钥'), findsOneWidget);
    expect(find.text('XXXX-XXXX-XXXX-XXXX'), findsOneWidget);
    expect(find.text('粘贴恢复密钥'), findsOneWidget);
    expect(find.text('仅在此设备上验证'), findsOneWidget);
    expect(find.text('服务器无法读取，也不会保存你的恢复密钥。'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('recovery-unlock-scroll')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('验证并恢复'), findsOneWidget);
    expect(find.text('验证失败不会删除本机数据。'), findsOneWidget);
  });

  testWidgets('submits the entered recovery key and closes on success', (
    tester,
  ) async {
    final source = _FakeSource();
    await tester.pumpWidget(_UnlockHost(source: source));
    await tester.tap(find.byKey(const Key('open-recovery-unlock')));
    await tester.pumpAndSettle();
    final encoded = _encodedKey(4);
    await tester.enterText(
      find.byKey(const Key('recovery-unlock-input')),
      encoded.toLowerCase(),
    );
    await _scrollToSubmit(tester);
    await tester.tap(find.byKey(const Key('recovery-unlock-submit')));
    await tester.pumpAndSettle();

    expect(source.restoreCalls, 1);
    expect(source.receivedKey, encoded);
    expect(find.byKey(const Key('recovery-unlock-title')), findsNothing);
    expect(find.text('已恢复'), findsOneWidget);
  });

  testWidgets('shows a safe error and preserves input when recovery fails', (
    tester,
  ) async {
    final source = _FakeSource(
      error: const ContentEncryptionException('恢复密钥不正确，请重新检查'),
    );
    await tester.pumpWidget(
      MaterialApp(home: RecoveryUnlockPage(source: source)),
    );
    final encoded = _encodedKey(5);
    await tester.enterText(
      find.byKey(const Key('recovery-unlock-input')),
      encoded,
    );
    await _scrollToSubmit(tester);
    await tester.tap(find.byKey(const Key('recovery-unlock-submit')));
    await tester.pumpAndSettle();

    expect(source.restoreCalls, 1);
    expect(find.byKey(const Key('recovery-unlock-title')), findsOneWidget);
    expect(find.text('恢复密钥不正确，请重新检查'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      encoded,
    );
  });

  testWidgets('pastes a valid key and clears only that clipboard value', (
    tester,
  ) async {
    final encoded = _encodedKey(6);
    String? clipboard = encoded.toLowerCase();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': clipboard};
      }
      if (call.method == 'Clipboard.setData') {
        clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryUnlockPage(
          source: _FakeSource(),
          clipboardClearDelay: const Duration(seconds: 1),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-unlock-paste')));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      encoded,
    );
    expect(find.textContaining('剪贴板将在 2 分钟后清除'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(clipboard, '');
  });

  testWidgets('rejects malformed clipboard content before submission', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': 'not-a-valid-key'}
          : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(home: RecoveryUnlockPage(source: _FakeSource())),
    );

    await tester.tap(find.byKey(const Key('recovery-unlock-paste')));
    await tester.pump();
    expect(find.text('剪贴板中的恢复密钥格式不正确'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets('removes the editable secret from the inactive render tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RecoveryUnlockPage(source: _FakeSource())),
    );
    final encoded = _encodedKey(7);
    await tester.enterText(
      find.byKey(const Key('recovery-unlock-input')),
      encoded,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('recovery-unlock-input')), findsNothing);
    expect(find.text('••••-••••-••••-••••'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('recovery-unlock-input')), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      encoded,
    );
  });

  testWidgets('blocks route dismissal while local key restoration is active', (
    tester,
  ) async {
    final gate = Completer<void>();
    final source = _FakeSource(restoreGate: gate);
    await tester.pumpWidget(_UnlockHost(source: source));
    await tester.tap(find.byKey(const Key('open-recovery-unlock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recovery-unlock-input')),
      _encodedKey(8),
    );
    await _scrollToSubmit(tester);
    await tester.tap(find.byKey(const Key('recovery-unlock-submit')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const Key('recovery-unlock-title')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-unlock-title')), findsNothing);
  });
}

String _encodedKey(int byte) =>
    RecoveryKeyDraft.fromBytes(List<int>.filled(32, byte)).encodedKey;

Future<void> _scrollToSubmit(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('recovery-unlock-scroll')),
    const Offset(0, -140),
  );
  await tester.pumpAndSettle();
}

class _UnlockHost extends StatefulWidget {
  const _UnlockHost({required this.source});

  final ContentEncryptionSource source;

  @override
  State<_UnlockHost> createState() => _UnlockHostState();
}

class _UnlockHostState extends State<_UnlockHost> {
  var _restored = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: const Key('open-recovery-unlock'),
              onPressed: () async {
                final restored = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => RecoveryUnlockPage(source: widget.source),
                  ),
                );
                if (mounted && restored == true) {
                  setState(() => _restored = true);
                }
              },
              child: const Text('打开'),
            ),
            if (_restored) const Text('已恢复'),
          ],
        ),
      ),
    ),
  );
}

class _FakeSource implements ContentEncryptionSource {
  _FakeSource({this.error, this.restoreGate});

  final ContentEncryptionException? error;
  final Completer<void>? restoreGate;
  var restoreCalls = 0;
  String? receivedKey;

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {}

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async =>
      const ContentEncryptionState(status: ContentEncryptionSetupStatus.locked);

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() async =>
      RecoveryKeyDraft.fromBytes(List<int>.filled(32, 1));

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) async {
    restoreCalls++;
    receivedKey = encodedKey;
    final error = this.error;
    if (error != null) throw error;
    await restoreGate?.future;
  }
}
