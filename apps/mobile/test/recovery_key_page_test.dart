import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/recovery_key_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the approved recovery-key layout with the real key', (
    tester,
  ) async {
    final draft = _draft();
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryKeyPage(
          source: _FakeContentEncryptionSource(),
          draft: draft,
        ),
      ),
    );

    expect(find.byKey(const Key('recovery-key-title')), findsOneWidget);
    expect(find.text('保存你的恢复密钥'), findsOneWidget);
    expect(find.text('新设备登录时，用它恢复加密内容。'), findsOneWidget);
    expect(find.text('恢复密钥'), findsOneWidget);
    final groups = draft.encodedKey.split('-');
    expect(find.text(groups.take(5).join('-')), findsOneWidget);
    expect(find.text(groups.skip(5).take(4).join('-')), findsOneWidget);
    expect(find.text(groups.skip(9).join('-')), findsOneWidget);
    expect(find.text('复制恢复密钥'), findsOneWidget);
    expect(find.text('请离线妥善保存'), findsOneWidget);
    expect(find.textContaining('服务器不会保存这串恢复密钥'), findsOneWidget);
    expect(find.text('我已安全保存'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('recovery-key-scroll')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('遗失恢复密钥和全部受信设备'), findsOneWidget);
  });

  testWidgets('copies the key and clears only its own clipboard value', (
    tester,
  ) async {
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': clipboard};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final draft = _draft();
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryKeyPage(
          source: _FakeContentEncryptionSource(),
          draft: draft,
          clipboardClearDelay: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('recovery-key-copy')));
    await tester.pump();

    expect(clipboard, draft.encodedKey);
    expect(find.textContaining('剪贴板将在 2 分钟后清除'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(clipboard, '');
  });

  testWidgets(
    'requires confirmation before acknowledging and closes on success',
    (tester) async {
      final source = _FakeContentEncryptionSource();
      await tester.pumpWidget(
        _RecoveryKeyHost(source: source, draft: _draft()),
      );
      await tester.tap(find.byKey(const Key('open-recovery-key')));
      await tester.pumpAndSettle();

      await _scrollToPrimaryAction(tester);
      await tester.tap(find.byKey(const Key('recovery-key-saved')));
      await tester.pumpAndSettle();
      expect(find.text('确认已安全保存？'), findsOneWidget);
      expect(source.acknowledgeCalls, 0);

      await tester.tap(find.byKey(const Key('recovery-key-confirm')));
      await tester.pumpAndSettle();
      expect(source.acknowledgeCalls, 1);
      expect(find.byKey(const Key('recovery-key-title')), findsNothing);
      expect(find.text('已确认'), findsOneWidget);
    },
  );

  testWidgets('back and confirmation cancellation keep the pending key', (
    tester,
  ) async {
    final source = _FakeContentEncryptionSource();
    await tester.pumpWidget(_RecoveryKeyHost(source: source, draft: _draft()));
    await tester.tap(find.byKey(const Key('open-recovery-key')));
    await tester.pumpAndSettle();

    await _scrollToPrimaryAction(tester);
    await tester.tap(find.byKey(const Key('recovery-key-saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.acknowledgeCalls, 0);

    await tester.tap(find.byKey(const Key('recovery-key-back')));
    await tester.pumpAndSettle();
    expect(source.acknowledgeCalls, 0);
    expect(find.text('未确认'), findsOneWidget);
  });

  testWidgets('acknowledgement failure leaves the recovery key available', (
    tester,
  ) async {
    final source = _FakeContentEncryptionSource(failAcknowledgement: true);
    await tester.pumpWidget(_RecoveryKeyHost(source: source, draft: _draft()));
    await tester.tap(find.byKey(const Key('open-recovery-key')));
    await tester.pumpAndSettle();
    await _scrollToPrimaryAction(tester);
    await tester.tap(find.byKey(const Key('recovery-key-saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-key-confirm')));
    await tester.pumpAndSettle();

    expect(source.acknowledgeCalls, 1);
    expect(find.byKey(const Key('recovery-key-title')), findsOneWidget);
    expect(find.textContaining('恢复密钥仍保留在此设备'), findsOneWidget);
  });

  testWidgets('obscures the recovery key while the app is inactive', (
    tester,
  ) async {
    final draft = _draft();
    final firstLine = draft.encodedKey.split('-').take(5).join('-');
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryKeyPage(
          source: _FakeContentEncryptionSource(),
          draft: draft,
        ),
      ),
    );
    expect(find.text(firstLine), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text(firstLine), findsNothing);
    expect(find.text('••••-••••-••••-••••-••••'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(firstLine), findsOneWidget);
  });
}

RecoveryKeyDraft _draft() =>
    RecoveryKeyDraft.fromBytes(List<int>.generate(32, (index) => index));

Future<void> _scrollToPrimaryAction(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('recovery-key-scroll')),
    const Offset(0, -150),
  );
  await tester.pumpAndSettle();
}

class _RecoveryKeyHost extends StatefulWidget {
  const _RecoveryKeyHost({required this.source, required this.draft});

  final ContentEncryptionSource source;
  final RecoveryKeyDraft draft;

  @override
  State<_RecoveryKeyHost> createState() => _RecoveryKeyHostState();
}

class _RecoveryKeyHostState extends State<_RecoveryKeyHost> {
  bool? _confirmed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: const Key('open-recovery-key'),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => RecoveryKeyPage(
                      source: widget.source,
                      draft: widget.draft,
                    ),
                  ),
                );
                if (mounted) setState(() => _confirmed = result);
              },
              child: const Text('打开'),
            ),
            if (_confirmed == true) const Text('已确认'),
            if (_confirmed == null) const Text('未确认'),
          ],
        ),
      ),
    ),
  );
}

class _FakeContentEncryptionSource implements ContentEncryptionSource {
  _FakeContentEncryptionSource({this.failAcknowledgement = false});

  final bool failAcknowledgement;
  var acknowledgeCalls = 0;

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {
    acknowledgeCalls++;
    if (failAcknowledgement) throw StateError('failed');
  }

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async =>
      const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.recoveryPending,
      );

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() async => _draft();

  @override
  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation() async =>
      RecoveryKeyRotationDraft(
        rotationId: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
        recoveryKey: _draft(),
      );

  @override
  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId) async {}

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) async {}
}
