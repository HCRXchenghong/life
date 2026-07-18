import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/recovery_key_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved recovery key management layout', (
    tester,
  ) async {
    final source = _FakeSource();
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryKeyManagementPage(
          source: source,
          onRotationReady: (_) async {},
        ),
      ),
    );

    expect(find.text('恢复密钥'), findsOneWidget);
    expect(find.text('恢复密钥已保存'), findsOneWidget);
    expect(find.text('保存状态'), findsOneWidget);
    expect(find.text('已确认'), findsOneWidget);
    expect(find.text('恢复范围'), findsOneWidget);
    expect(find.text('日程、对话与主机内容'), findsOneWidget);
    expect(find.text('重新生成恢复密钥'), findsOneWidget);
    expect(find.text(source.encodedKey), findsNothing);
  });

  testWidgets('requires confirmation and opens only the new one-time key', (
    tester,
  ) async {
    final source = _FakeSource();
    RecoveryKeyRotationDraft? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryKeyManagementPage(
          source: source,
          onRotationReady: (draft) async => opened = draft,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-key-rotate')));
    await tester.pumpAndSettle();
    expect(source.prepareCalls, 0);
    expect(find.text('重新生成恢复密钥？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recovery-key-rotate-confirm')));
    await tester.pumpAndSettle();
    expect(source.prepareCalls, 1);
    expect(opened?.rotationId, _FakeSource.rotationId);
    expect(opened?.recoveryKey.encodedKey, source.encodedKey);
  });
}

class _FakeSource implements ContentEncryptionSource {
  static const rotationId = '56ad19d3-04ec-4380-b56d-1c82663a5ddd';
  final encodedKey = RecoveryKeyDraft.fromBytes(
    List<int>.filled(32, 9),
  ).encodedKey;
  var prepareCalls = 0;

  @override
  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation() async {
    prepareCalls++;
    return RecoveryKeyRotationDraft(
      rotationId: rotationId,
      recoveryKey: RecoveryKeyDraft.fromBytes(List<int>.filled(32, 9)),
    );
  }

  @override
  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId) async {}

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {}

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async =>
      const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.enabled,
      );

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() async =>
      RecoveryKeyDraft.fromBytes(List<int>.filled(32, 1));

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) async {}
}
