import 'dart:typed_data';

import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/device_approval_waiting_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved waiting layout and recovery fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeRecoverySource();
    DeviceApprovalWaitingResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () async {
              result = await Navigator.of(context)
                  .push<DeviceApprovalWaitingResult>(
                    MaterialPageRoute<DeviceApprovalWaitingResult>(
                      builder: (_) => DeviceApprovalWaitingPage(
                        source: source,
                        session: _session(),
                      ),
                    ),
                  );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('恢复加密内容'), findsOneWidget);
    expect(find.text('等待受信设备确认'), findsOneWidget);
    expect(find.text('请在已登录的 Daylink 设备上\n批准此请求。'), findsOneWidget);
    expect(find.text('482 731'), findsOneWidget);
    expect(find.text('这台新设备'), findsOneWidget);
    expect(find.text('Daylink iPhone'), findsOneWidget);
    expect(find.text('内容密钥只会加密发送到此设备'), findsOneWidget);
    expect(find.text('等待批准...'), findsOneWidget);
    expect(find.text('改用恢复密钥'), findsOneWidget);
    expect(find.text('取消请求'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('approval-waiting-recovery')));
    await tester.pumpAndSettle();
    expect(source.cancelCalls, 1);
    expect(result, DeviceApprovalWaitingResult.useRecoveryKey);
  });

  testWidgets('polls only one request and closes after trusted approval', (
    tester,
  ) async {
    final source = _FakeRecoverySource();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceApprovalWaitingPage(source: source, session: _session()),
      ),
    );
    await tester.pump();
    expect(source.checkCalls, 1);

    source.status = DeviceApprovalWaitingStatus.completed;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(source.checkCalls, 2);
  });
}

DeviceApprovalWaitingSession _session() => DeviceApprovalWaitingSession(
  id: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
  requestToken: Uint8List.fromList(List<int>.filled(32, 6)),
  verificationCode: '482 731',
  deviceName: 'Daylink iPhone',
  createdAt: DateTime.now().toUtc(),
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
);

class _FakeRecoverySource implements DeviceApprovalRecoverySource {
  var status = DeviceApprovalWaitingStatus.pending;
  var checkCalls = 0;
  var cancelCalls = 0;

  @override
  Future<void> cancelDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) async {
    cancelCalls++;
  }

  @override
  Future<DeviceApprovalWaitingStatus> checkDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) async {
    checkCalls++;
    return status;
  }

  @override
  Future<DeviceApprovalWaitingSession> startDeviceApproval() async =>
      _session();
}
