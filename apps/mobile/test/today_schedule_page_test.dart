import 'dart:async';

import 'package:daylink_mobile/src/data/schedule_repository.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:daylink_mobile/src/presentation/today_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders today from live account schedule data', (tester) async {
    final source = _FakeScheduleSource(
      events: [
        ScheduleEventModel(
          id: 'meeting',
          title: '产品例会',
          notes: '线上会议',
          startsAtUtc: DateTime(2026, 7, 16, 9, 30).toUtc(),
          duration: const Duration(minutes: 30),
          timezoneId: 'Asia/Shanghai',
        ),
        ScheduleEventModel(
          id: 'focus',
          title: '深度工作',
          notes: '专注 2 小时',
          startsAtUtc: DateTime(2026, 7, 16, 14).toUtc(),
          duration: const Duration(hours: 2),
          timezoneId: 'Asia/Shanghai',
          source: ScheduleSource.ai,
        ),
        ScheduleEventModel(
          id: 'tomorrow',
          title: '明天的日程',
          startsAtUtc: DateTime(2026, 7, 17, 9).toUtc(),
          duration: const Duration(hours: 1),
          timezoneId: 'Asia/Shanghai',
        ),
      ],
      reminders: const [
        ReminderModel(
          id: 'focus-reminder',
          eventId: 'focus',
          offset: Duration(minutes: 10),
        ),
      ],
    );
    addTearDown(source.close);

    await tester.pumpWidget(
      MaterialApp(
        home: TodaySchedulePage(
          source: source,
          clock: () => DateTime(2026, 7, 16, 8),
          onCreateEvent: () {},
          onOpenAssistant: () {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    source.emit();
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('7月16日  星期四'), findsOneWidget);
    expect(find.text('告诉 Daylink 你的安排…'), findsOneWidget);
    expect(find.text('2 项'), findsOneWidget);
    expect(find.text('产品例会'), findsOneWidget);
    expect(find.text('线上会议 · 10:00 结束'), findsOneWidget);
    expect(find.text('深度工作'), findsOneWidget);
    expect(find.text('专注 2 小时 · 提前 10 分钟提醒'), findsOneWidget);
    expect(find.text('明天的日程'), findsNothing);
    expect(find.text('日程'), findsOneWidget);
    expect(find.text('工具箱'), findsOneWidget);
    expect(find.text('助手'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    source.events.removeWhere((event) => event.id == 'meeting');
    source.emit();
    await tester.pumpAndSettle();

    expect(find.text('1 项'), findsOneWidget);
    expect(find.text('产品例会'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('all schedule page controls dispatch an explicit action', (
    tester,
  ) async {
    final source = _FakeScheduleSource();
    addTearDown(source.close);
    var createCalls = 0;
    var assistantCalls = 0;
    final destinations = <AppDestination>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TodaySchedulePage(
          source: source,
          clock: () => DateTime(2026, 7, 16, 8),
          onCreateEvent: () => createCalls++,
          onOpenAssistant: () => assistantCalls++,
          onDestinationSelected: destinations.add,
        ),
      ),
    );
    source.emit();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('today-create')));
    await tester.tap(find.byKey(const Key('today-ai-entry')));
    await tester.tap(find.byKey(const Key('nav-toolbox')));
    await tester.tap(find.byKey(const Key('nav-assistant')));
    await tester.tap(find.byKey(const Key('nav-hosts')));
    await tester.tap(find.byKey(const Key('nav-me')));

    expect(createCalls, 1);
    expect(assistantCalls, 1);
    expect(destinations, [
      AppDestination.toolbox,
      AppDestination.assistant,
      AppDestination.hosts,
      AppDestination.me,
    ]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _FakeScheduleSource implements ScheduleEventSource {
  _FakeScheduleSource({
    List<ScheduleEventModel>? events,
    List<ReminderModel>? reminders,
  }) : events = events ?? [],
       reminders = reminders ?? const [];

  final List<ScheduleEventModel> events;
  final List<ReminderModel> reminders;
  final _events = StreamController<List<ScheduleEventModel>>.broadcast(
    sync: true,
  );

  void emit() => _events.add(List.unmodifiable(events));

  @override
  Future<List<ReminderModel>> remindersForEvents(
    Iterable<String> eventIds,
  ) async {
    final ids = eventIds.toSet();
    return reminders
        .where((reminder) => ids.contains(reminder.eventId))
        .toList(growable: false);
  }

  @override
  Stream<List<ScheduleEventModel>> watchActiveEvents() => _events.stream;

  Future<void> close() => _events.close();
}
