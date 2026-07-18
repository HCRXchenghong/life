import 'package:daylink_mobile/src/domain/schedule/schedule_editor_models.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:daylink_mobile/src/presentation/schedule_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders the approved minimal new schedule layout', (
    tester,
  ) async {
    final source = _FakeEditorSource();
    var assistantCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEditorPage(
          source: source,
          clock: _clock,
          onOpenAssistant: () => assistantCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建日程'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('添加标题'), findsOneWidget);
    expect(find.text('让助手填写'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('全天'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('7月18日 周六 14:00'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);
    expect(find.text('7月18日 周六 15:00'), findsOneWidget);
    expect(find.text('中国标准时间'), findsOneWidget);
    expect(find.text('提醒与重复'), findsOneWidget);
    expect(find.text('提前 10 分钟'), findsOneWidget);
    expect(find.text('不重复'), findsOneWidget);
    expect(find.text('添加备注（可选）'), findsOneWidget);
    expect(find.text('保存后将通过系统原生通知提醒'), findsOneWidget);

    await tester.tap(find.byKey(const Key('schedule-editor-assistant')));
    expect(assistantCalls, 1);
  });

  testWidgets('saves manual data with timezone, reminder and recurrence', (
    tester,
  ) async {
    final source = _FakeEditorSource();
    ScheduleSaveResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-editor'),
              onPressed: () async {
                result = await Navigator.push<ScheduleSaveResult>(
                  context,
                  MaterialPageRoute<ScheduleSaveResult>(
                    builder: (_) => ScheduleEditorPage(
                      source: source,
                      clock: _clock,
                      idFactory: _idFactory(),
                      onOpenAssistant: () {},
                    ),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('schedule-editor-title-input')),
      '周末出游',
    );
    await tester.enterText(
      find.byKey(const Key('schedule-editor-notes')),
      '带上相机',
    );
    await tester.ensureVisible(
      find.byKey(const Key('schedule-editor-recurrence')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-editor-recurrence')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('recurrence-choice-weekly')),
    );
    await tester.tap(find.byKey(const Key('recurrence-choice-weekly')));
    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-editor-save')));
    await tester.pumpAndSettle();

    expect(source.savedEvent?.id, 'event-id');
    expect(source.savedEvent?.title, '周末出游');
    expect(source.savedEvent?.notes, '带上相机');
    expect(source.savedEvent?.startsAtUtc, DateTime.utc(2026, 7, 18, 6));
    expect(source.savedEvent?.duration, const Duration(hours: 1));
    expect(source.savedEvent?.timezoneId, 'Asia/Shanghai');
    expect(source.savedEvent?.source, ScheduleSource.manual);
    expect(
      source.savedEvent?.recurrence?.frequency,
      RecurrenceFrequency.weekly,
    );
    expect(source.savedEvent?.recurrence?.weekdays, {DateTime.saturday});
    expect(source.savedReminders.single.id, 'reminder-id');
    expect(source.savedReminders.single.offset, const Duration(minutes: 10));
    expect(source.savedReminders.single.exactRequested, isTrue);
    expect(result?.reminderDelivery, ScheduleReminderDelivery.scheduled);
  });

  testWidgets('does not mutate data when the title is blank', (tester) async {
    final source = _FakeEditorSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEditorPage(
          source: source,
          clock: _clock,
          onOpenAssistant: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('schedule-editor-save')));
    await tester.pump();

    expect(find.text('请输入日程标题'), findsOneWidget);
    expect(source.saveCalls, 0);
  });

  testWidgets('edit mode preserves existing reminder identities by default', (
    tester,
  ) async {
    final source = _FakeEditorSource();
    final event = ScheduleEventModel(
      id: 'existing-event',
      title: '原日程',
      startsAtUtc: DateTime.utc(2026, 7, 19, 2),
      duration: const Duration(hours: 2),
      timezoneId: 'Asia/Shanghai',
      source: ScheduleSource.ai,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        weekdays: const {DateTime.sunday},
        count: 8,
      ),
    );
    final reminders = [
      const ReminderModel(
        id: 'first-reminder',
        eventId: 'existing-event',
        offset: Duration(minutes: 10),
      ),
      const ReminderModel(
        id: 'second-reminder',
        eventId: 'existing-event',
        offset: Duration(hours: 1),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleEditorPage(
          source: source,
          initialEvent: event,
          initialReminders: reminders,
          clock: _clock,
          onOpenAssistant: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑日程'), findsOneWidget);
    expect(find.text('2 个提醒'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('schedule-editor-title-input')),
      '修改后的日程',
    );
    await tester.tap(find.byKey(const Key('schedule-editor-save')));
    await tester.pumpAndSettle();

    expect(source.savedEvent?.id, event.id);
    expect(source.savedEvent?.source, ScheduleSource.ai);
    expect(source.savedEvent?.recurrence?.interval, 2);
    expect(source.savedEvent?.recurrence?.weekdays, {DateTime.sunday});
    expect(source.savedEvent?.recurrence?.count, 8);
    expect(source.savedReminders.map((item) => item.id), [
      'first-reminder',
      'second-reminder',
    ]);
  });
}

DateTime _clock() => DateTime(2026, 7, 18, 13, 20);

ScheduleIdFactory _idFactory() {
  final values = ['event-id', 'reminder-id'].iterator;
  return () {
    values.moveNext();
    return values.current;
  };
}

class _FakeEditorSource implements ScheduleEditorSource {
  ScheduleEventModel? savedEvent;
  List<ReminderModel> savedReminders = const [];
  var saveCalls = 0;

  @override
  Future<ScheduleEditorDefaults> loadScheduleEditorDefaults() async =>
      const ScheduleEditorDefaults(
        timezoneId: 'Asia/Shanghai',
        defaultReminderLeadMinutes: 10,
      );

  @override
  Future<ScheduleSaveResult> saveScheduleEvent({
    required ScheduleEventModel event,
    required List<ReminderModel> reminders,
  }) async {
    saveCalls++;
    savedEvent = event;
    savedReminders = List.unmodifiable(reminders);
    return ScheduleSaveResult(
      eventId: event.id,
      reminderDelivery: ScheduleReminderDelivery.scheduled,
    );
  }
}
