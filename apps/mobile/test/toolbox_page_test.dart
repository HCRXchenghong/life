import 'package:daylink_mobile/src/presentation/app_navigation.dart';
import 'package:daylink_mobile/src/presentation/toolbox_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved minimal toolbox layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ToolboxPage(
          onToolSelected: (_) {},
          onDestinationSelected: (_) {},
        ),
      ),
    );

    expect(find.text('工具箱'), findsNWidgets(2));
    expect(find.text('常用能力，随用随取'), findsOneWidget);
    expect(find.text('常用工具'), findsOneWidget);
    expect(find.text('好友选时间'), findsOneWidget);
    expect(find.text('发链接，一起定时间'), findsOneWidget);
    expect(find.text('AI 生图'), findsNothing);
    expect(find.text('Word 文档'), findsOneWidget);
    expect(find.text('生成并保存文档'), findsOneWidget);
    expect(find.text('表格与演示'), findsOneWidget);
    expect(find.text('Excel、PPT'), findsOneWidget);

    final toolboxIcon = tester.widget<Icon>(
      find.byIcon(Icons.grid_view_rounded),
    );
    final scheduleIcon = tester.widget<Icon>(
      find.byIcon(Icons.event_available_outlined),
    );
    expect(toolboxIcon.color, const Color(0xFF3370FF));
    expect(scheduleIcon.color, const Color(0xFF646A73));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tool cards and navigation dispatch explicit actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tools = <ToolboxTool>[];
    final destinations = <AppDestination>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ToolboxPage(
          onToolSelected: tools.add,
          onDestinationSelected: destinations.add,
        ),
      ),
    );

    for (final key in const [
      Key('tool-friend-schedule'),
      Key('tool-word-document'),
      Key('tool-spreadsheet-presentation'),
    ]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
    }
    await tester.tap(find.byKey(const Key('nav-schedule')));
    await tester.tap(find.byKey(const Key('nav-assistant')));
    await tester.tap(find.byKey(const Key('nav-hosts')));
    await tester.tap(find.byKey(const Key('nav-me')));

    expect(tools, ToolboxTool.values);
    expect(destinations, [
      AppDestination.schedule,
      AppDestination.assistant,
      AppDestination.hosts,
      AppDestination.me,
    ]);
  });
}
