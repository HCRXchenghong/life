import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/end_to_end_encryption_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved first-time encryption layout', (
    tester,
  ) async {
    final source = _FakeContentEncryptionSource();
    await tester.pumpWidget(
      MaterialApp(
        home: EndToEndEncryptionPage(
          source: source,
          onRecoveryKeyReady: (_) async {},
          onOpenUnlock: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('e2ee-title')), findsOneWidget);
    expect(find.text('开启端到端加密'), findsOneWidget);
    expect(find.text('日程、对话与主机内容会在离开设备前加密。'), findsOneWidget);
    expect(find.text('安全密钥'), findsOneWidget);
    expect(find.text('内容主密钥'), findsOneWidget);
    expect(find.text('仅保存在受信设备中'), findsOneWidget);
    expect(find.text('未创建'), findsOneWidget);
    expect(find.text('恢复密钥'), findsOneWidget);
    expect(find.text('用于在新设备恢复内容'), findsOneWidget);
    expect(find.text('未生成'), findsOneWidget);
    expect(find.text('开启并生成恢复密钥'), findsOneWidget);
    expect(find.textContaining('遗失全部受信设备'), findsOneWidget);
  });

  testWidgets('prepares the key once and continues to recovery-key saving', (
    tester,
  ) async {
    final source = _FakeContentEncryptionSource();
    RecoveryKeyDraft? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: EndToEndEncryptionPage(
          source: source,
          onRecoveryKeyReady: (value) async => draft = value,
          onOpenUnlock: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('e2ee-enable')));
    await tester.pumpAndSettle();

    expect(source.prepareCalls, 1);
    expect(draft, isNotNull);
    expect(find.text('已创建'), findsOneWidget);
    expect(find.text('待保存'), findsOneWidget);
    expect(find.text('继续保存恢复密钥'), findsOneWidget);
  });

  testWidgets(
    'locked account routes to recovery unlock and reloads on success',
    (tester) async {
      final source = _FakeContentEncryptionSource(
        status: ContentEncryptionSetupStatus.locked,
      );
      var unlockCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EndToEndEncryptionPage(
            source: source,
            onRecoveryKeyReady: (_) async {},
            onOpenUnlock: () async {
              unlockCalls++;
              await source.restoreWithRecoveryKey(
                RecoveryKeyDraft.fromBytes(List<int>.filled(32, 1)).encodedKey,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('e2ee-enable')));
      await tester.pumpAndSettle();
      expect(unlockCalls, 1);
      expect(source.prepareCalls, 0);
      expect(find.text('已开启'), findsOneWidget);
    },
  );
}

class _FakeContentEncryptionSource implements ContentEncryptionSource {
  _FakeContentEncryptionSource({
    ContentEncryptionSetupStatus status =
        ContentEncryptionSetupStatus.notConfigured,
  }) : state = ContentEncryptionState(status: status);

  ContentEncryptionState state;
  var prepareCalls = 0;

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {
    state = const ContentEncryptionState(
      status: ContentEncryptionSetupStatus.enabled,
    );
  }

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async => state;

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() async {
    prepareCalls++;
    state = const ContentEncryptionState(
      status: ContentEncryptionSetupStatus.recoveryPending,
    );
    return RecoveryKeyDraft.fromBytes(List<int>.generate(32, (index) => index));
  }

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) async {
    state = const ContentEncryptionState(
      status: ContentEncryptionSetupStatus.enabled,
    );
  }
}
