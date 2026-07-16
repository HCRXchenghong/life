import 'package:daylink_mobile/src/presentation/device_approval_success_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved recovery success layout and finishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? completed;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open-success'),
            onPressed: () async {
              completed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const DeviceApprovalSuccessPage(),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-success')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('恢复加密内容'), findsOneWidget);
    expect(find.text('加密内容已恢复'), findsOneWidget);
    expect(find.text('这台设备现在可以安全同步你的日程、\n对话与主机内容。'), findsOneWidget);
    expect(find.text('内容密钥'), findsOneWidget);
    expect(find.text('已恢复'), findsOneWidget);
    expect(find.text('同步状态'), findsOneWidget);
    expect(find.text('准备就绪'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('密钥仅保存在你的受信设备中'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('approval-success-done')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}
