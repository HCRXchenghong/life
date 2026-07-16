import 'dart:typed_data';

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
      expect(find.text('端到端加密已开启'), findsOneWidget);
    },
  );

  testWidgets('renders the approved enabled encryption layout', (tester) async {
    final source = _FakeContentEncryptionSource(
      status: ContentEncryptionSetupStatus.enabled,
    );
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

    expect(find.byKey(const Key('e2ee-enabled-heading')), findsOneWidget);
    expect(find.text('端到端加密已开启'), findsOneWidget);
    expect(find.text('已保护'), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('受信设备'), findsOneWidget);
    expect(find.text('这台设备'), findsOneWidget);
    expect(find.text('Daylink Android'), findsOneWidget);
    expect(find.text('受信'), findsOneWidget);
    expect(find.text('加密保护在此设备上正常工作'), findsOneWidget);
    expect(find.byKey(const Key('e2ee-enable')), findsNothing);
  });

  testWidgets('opens a pending trusted-device request from enabled state', (
    tester,
  ) async {
    final source = _FakeContentEncryptionSource(
      status: ContentEncryptionSetupStatus.enabled,
    );
    final approval = _FakeApprovalSource();
    TrustedDeviceApprovalRequest? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: EndToEndEncryptionPage(
          source: source,
          approvalSource: approval,
          onRecoveryKeyReady: (_) async {},
          onOpenUnlock: () async {},
          onOpenDeviceApproval: (request) async => opened = request,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看新设备请求'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('e2ee-enable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('e2ee-enable')));
    await tester.pumpAndSettle();
    expect(opened?.verificationCode, '482 731');
  });
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

class _FakeApprovalSource implements TrustedDeviceApprovalSource {
  final request = TrustedDeviceApprovalRequest(
    id: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
    deviceName: 'Daylink iPhone',
    requesterPublicKey: Uint8List.fromList(List<int>.filled(32, 7)),
    verificationCode: '482 731',
    createdAt: DateTime.now().toUtc(),
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );

  @override
  Future<void> approveDevice(TrustedDeviceApprovalRequest request) async {}

  @override
  Future<TrustedDeviceApprovalRequest?> loadPendingDeviceApproval() async =>
      request;

  @override
  Future<void> rejectDevice(TrustedDeviceApprovalRequest request) async {}
}
