import 'dart:async';
import 'dart:typed_data';

import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/presentation/trusted_device_approval_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved minimal trusted-device layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDeviceApprovalPage(
          source: _FakeApprovalSource(),
          request: _request(),
        ),
      ),
    );

    expect(find.byKey(const Key('device-approval-title')), findsOneWidget);
    expect(find.text('批准新设备'), findsOneWidget);
    expect(find.text('允许这台新设备？'), findsOneWidget);
    expect(find.text('批准后，它可以恢复你的加密内容。'), findsOneWidget);
    expect(find.text('新设备'), findsOneWidget);
    expect(find.text('Daylink iPhone'), findsOneWidget);
    expect(find.text('上海 · 刚刚申请'), findsOneWidget);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.text('482 731'), findsOneWidget);
    expect(find.text('请核对两台设备验证码一致'), findsOneWidget);
    expect(find.text('确认并批准'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
    expect(find.text('批准请求将在 10 分钟后失效。'), findsOneWidget);
  });

  testWidgets('approves once and closes only after the encrypted upload', (
    tester,
  ) async {
    final source = _FakeApprovalSource();
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDeviceApprovalPage(source: source, request: _request()),
      ),
    );
    await _scrollToActions(tester);
    await tester.tap(find.byKey(const Key('device-approval-confirm')));
    await tester.pumpAndSettle();

    expect(source.approveCalls, 1);
    expect(source.rejectCalls, 0);
    expect(find.byKey(const Key('device-approval-title')), findsNothing);
  });

  testWidgets('rejects explicitly and closes the request', (tester) async {
    final source = _FakeApprovalSource();
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDeviceApprovalPage(source: source, request: _request()),
      ),
    );
    await _scrollToActions(tester);
    await tester.tap(find.byKey(const Key('device-approval-reject')));
    await tester.pumpAndSettle();

    expect(source.rejectCalls, 1);
    expect(source.approveCalls, 0);
    expect(find.byKey(const Key('device-approval-title')), findsNothing);
  });

  testWidgets('blocks navigation while approval is in flight', (tester) async {
    final completion = Completer<void>();
    final source = _FakeApprovalSource(approval: completion.future);
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDeviceApprovalPage(source: source, request: _request()),
      ),
    );
    await _scrollToActions(tester);
    await tester.tap(find.byKey(const Key('device-approval-confirm')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byKey(const Key('device-approval-title')), findsOneWidget);
    expect(source.approveCalls, 1);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-approval-title')), findsNothing);
  });

  testWidgets('never approves an expired request', (tester) async {
    final source = _FakeApprovalSource();
    final expired = _request(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDeviceApprovalPage(source: source, request: expired),
      ),
    );
    await _scrollToActions(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('device-approval-confirm')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('批准请求已失效。'), findsOneWidget);
    expect(source.approveCalls, 0);
  });
}

Future<void> _scrollToActions(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('device-approval-scroll')),
    const Offset(0, -420),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('device-approval-confirm')), findsOneWidget);
}

TrustedDeviceApprovalRequest _request({DateTime? expiresAt}) =>
    TrustedDeviceApprovalRequest(
      id: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
      deviceName: 'Daylink iPhone',
      requesterPublicKey: Uint8List.fromList(List<int>.filled(32, 7)),
      verificationCode: '482 731',
      createdAt: DateTime.now().toUtc(),
      expiresAt:
          expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 10)),
      locationLabel: '上海',
    );

class _FakeApprovalSource implements TrustedDeviceApprovalSource {
  _FakeApprovalSource({this.approval});

  final Future<void>? approval;
  var approveCalls = 0;
  var rejectCalls = 0;

  @override
  Future<void> approveDevice(TrustedDeviceApprovalRequest request) async {
    approveCalls++;
    await approval;
  }

  @override
  Future<TrustedDeviceApprovalRequest?> loadPendingDeviceApproval() async =>
      null;

  @override
  Future<void> rejectDevice(TrustedDeviceApprovalRequest request) async {
    rejectCalls++;
  }
}
