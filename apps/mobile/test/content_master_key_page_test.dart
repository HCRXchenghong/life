import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/content_master_key_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved unlocked content master key layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContentMasterKeyPage(
          source: _FakeSource(
            const ContentEncryptionState(
              status: ContentEncryptionSetupStatus.enabled,
              keyVersion: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('内容主密钥'), findsOneWidget);
    expect(find.text('内容主密钥已保护'), findsOneWidget);
    expect(find.textContaining('密钥本身不会显示'), findsOneWidget);
    expect(find.text('密钥状态'), findsOneWidget);
    expect(find.text('当前状态'), findsOneWidget);
    expect(find.text('已解锁'), findsOneWidget);
    expect(find.text('密钥版本'), findsOneWidget);
    expect(find.text('第 1 版'), findsOneWidget);
    expect(find.text('加密方式'), findsOneWidget);
    expect(find.text('内容加密'), findsOneWidget);
    expect(find.text('AES-256-GCM'), findsOneWidget);
    expect(find.text('内容主密钥不可查看或导出'), findsOneWidget);
    expect(find.textContaining('sk-'), findsNothing);
  });

  testWidgets('shows the real locked state without exposing key material', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContentMasterKeyPage(
          source: _FakeSource(
            const ContentEncryptionState(
              status: ContentEncryptionSetupStatus.locked,
              keyVersion: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待解锁'), findsOneWidget);
    expect(find.text('第 1 版'), findsOneWidget);
  });

  testWidgets('supports a bounded retry after state loading fails', (
    tester,
  ) async {
    final source = _RetrySource();
    await tester.pumpWidget(
      MaterialApp(home: ContentMasterKeyPage(source: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('密钥状态加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('已解锁'), findsOneWidget);
    expect(source.calls, 2);
  });
}

class _FakeSource implements ContentEncryptionSource {
  const _FakeSource(this.state);

  final ContentEncryptionState state;

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async => state;

  @override
  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId) async {}

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {}

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() async =>
      RecoveryKeyDraft.fromBytes(List<int>.filled(32, 1));

  @override
  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation() async =>
      RecoveryKeyRotationDraft(
        rotationId: '7267dd3a-38b1-4e96-b8d8-1608109d5d69',
        recoveryKey: RecoveryKeyDraft.fromBytes(List<int>.filled(32, 2)),
      );

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) async {}
}

class _RetrySource extends _FakeSource {
  _RetrySource()
    : super(
        const ContentEncryptionState(
          status: ContentEncryptionSetupStatus.enabled,
          keyVersion: 1,
        ),
      );

  var calls = 0;

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async {
    calls++;
    if (calls == 1) throw StateError('unavailable');
    return state;
  }
}
