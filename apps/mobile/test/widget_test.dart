import 'package:daylink_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('headless shell starts without product UI', (tester) async {
    await tester.pumpWidget(
      DaylinkApp(runtimeFactory: () async => _FakeRuntime()),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(ColoredBox), findsWidgets);
  });
}

class _FakeRuntime implements AppRuntime {
  @override
  Future<void> close() async {}

  @override
  Future<void> reconcile() async {}
}
