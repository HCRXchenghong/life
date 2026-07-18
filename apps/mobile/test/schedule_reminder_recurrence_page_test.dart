import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:daylink_mobile/src/presentation/schedule_reminder_recurrence_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved minimal reminder and recurrence layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScheduleReminderRecurrencePage(
          initialReminderLeadMinutes: 10,
          initialRecurrence: null,
          startsOnWeekday: DateTime.saturday,
        ),
      ),
    );

    expect(find.text('提醒与重复'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('不提醒'), findsOneWidget);
    expect(find.text('日程开始时'), findsOneWidget);
    expect(find.text('提前 10 分钟'), findsOneWidget);
    expect(find.text('不重复'), findsOneWidget);
    expect(find.text('每天'), findsOneWidget);
    expect(find.text('每周'), findsOneWidget);
    expect(find.text('自定义'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('returns only explicitly changed common selections', (
    tester,
  ) async {
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const Key('reminder-choice-none')));
    await tester.tap(find.byKey(const Key('recurrence-choice-daily')));
    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.reminderLeadMinutes, isNull);
    expect(result?.reminderChanged, isTrue);
    expect(result?.recurrence?.frequency, RecurrenceFrequency.daily);
    expect(result?.recurrenceChanged, isTrue);
  });

  testWidgets('supports custom reminder and recurrence intervals', (
    tester,
  ) async {
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const Key('reminder-choice-custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-reminder-dialog')), findsOneWidget);
    expect(find.text('自定义提醒'), findsOneWidget);
    expect(find.text('提前'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('custom-reminder-amount')),
      '45',
    );
    await tester.tap(find.byKey(const Key('custom-reminder-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('提前 45 分钟'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('recurrence-choice-custom')),
    );
    await tester.tap(find.byKey(const Key('recurrence-choice-custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-recurrence-dialog')), findsOneWidget);
    expect(find.text('自定义重复'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('custom-recurrence-interval')),
      '2',
    );
    await tester.tap(find.byKey(const Key('custom-recurrence-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('每 2 周'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.reminderLeadMinutes, 45);
    expect(result?.recurrence?.frequency, RecurrenceFrequency.weekly);
    expect(result?.recurrence?.interval, 2);
    expect(result?.recurrence?.weekdays, {DateTime.saturday});
  });

  testWidgets('custom reminder cancel preserves the original selection', (
    tester,
  ) async {
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const Key('reminder-choice-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-reminder-amount')),
      '45',
    );
    await tester.tap(find.byKey(const Key('custom-reminder-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-reminder-dialog')), findsNothing);

    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.reminderLeadMinutes, 10);
    expect(result?.reminderChanged, isFalse);
  });

  testWidgets('custom reminder validates and converts the selected unit', (
    tester,
  ) async {
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const Key('reminder-choice-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-reminder-amount')),
      '366',
    );
    await tester.tap(find.byKey(const Key('custom-reminder-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('天').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-reminder-confirm')));
    await tester.pump();
    expect(find.byKey(const Key('custom-reminder-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-reminder-amount')),
      '2',
    );
    await tester.tap(find.byKey(const Key('custom-reminder-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('提前 2 天'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.reminderLeadMinutes, 2880);
    expect(result?.reminderChanged, isTrue);
  });

  testWidgets('custom recurrence cancel preserves the original complex rule', (
    tester,
  ) async {
    const recurrence = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 2,
      weekdays: {DateTime.monday, DateTime.friday},
      count: 12,
    );
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(
      tester,
      initialRecurrence: recurrence,
      onResult: (value) => result = value,
    );

    await tester.ensureVisible(
      find.byKey(const Key('recurrence-choice-custom')),
    );
    await tester.tap(find.byKey(const Key('recurrence-choice-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-recurrence-interval')),
      '4',
    );
    await tester.tap(find.byKey(const Key('custom-recurrence-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-recurrence-dialog')), findsNothing);

    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.recurrenceChanged, isFalse);
    expect(result?.recurrence?.interval, 2);
    expect(result?.recurrence?.weekdays, recurrence.weekdays);
    expect(result?.recurrence?.count, 12);
  });

  testWidgets('custom recurrence validates and converts the selected unit', (
    tester,
  ) async {
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(tester, onResult: (value) => result = value);

    await tester.ensureVisible(
      find.byKey(const Key('recurrence-choice-custom')),
    );
    await tester.tap(find.byKey(const Key('recurrence-choice-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-recurrence-interval')),
      '366',
    );
    await tester.tap(find.byKey(const Key('custom-recurrence-confirm')));
    await tester.pump();
    expect(find.byKey(const Key('custom-recurrence-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-recurrence-interval')),
      '3',
    );
    await tester.tap(find.byKey(const Key('custom-recurrence-frequency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-recurrence-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('每 3 月'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.recurrence?.frequency, RecurrenceFrequency.monthly);
    expect(result?.recurrence?.interval, 3);
    expect(result?.recurrenceChanged, isTrue);
  });

  testWidgets('completing without changes preserves existing complex rules', (
    tester,
  ) async {
    const recurrence = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 2,
      weekdays: {DateTime.monday, DateTime.friday},
      count: 12,
    );
    ScheduleReminderRecurrenceSelection? result;
    await _pumpHarness(
      tester,
      initialRecurrence: recurrence,
      onResult: (value) => result = value,
    );

    await tester.tap(
      find.byKey(const Key('schedule-reminder-recurrence-done')),
    );
    await tester.pumpAndSettle();

    expect(result?.reminderChanged, isFalse);
    expect(result?.recurrenceChanged, isFalse);
    expect(result?.recurrence?.interval, 2);
    expect(result?.recurrence?.weekdays, recurrence.weekdays);
    expect(result?.recurrence?.count, 12);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  RecurrenceRule? initialRecurrence,
  required ValueChanged<ScheduleReminderRecurrenceSelection?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-reminder-recurrence'),
              onPressed: () async {
                final result =
                    await Navigator.push<ScheduleReminderRecurrenceSelection>(
                      context,
                      MaterialPageRoute<ScheduleReminderRecurrenceSelection>(
                        builder: (_) => ScheduleReminderRecurrencePage(
                          initialReminderLeadMinutes: 10,
                          initialRecurrence: initialRecurrence,
                          startsOnWeekday: DateTime.saturday,
                        ),
                      ),
                    );
                onResult(result);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-reminder-recurrence')));
  await tester.pumpAndSettle();
}
