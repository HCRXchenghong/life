import 'package:daylink_mobile/src/domain/schedule/recurrence_engine.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('daily recurrence preserves local wall time across DST', () {
    final newYork = tz.getLocation('America/New_York');
    final start = tz.TZDateTime(newYork, 2026, 3, 7, 9).toUtc();
    final event = _event(
      startsAtUtc: start,
      timezoneId: newYork.name,
      rule: const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 3,
      ),
    );

    final occurrences = const RecurrenceEngine().between(
      event,
      fromUtc: DateTime.utc(2026, 3, 7),
      toUtc: DateTime.utc(2026, 3, 11),
    );

    expect(occurrences, hasLength(3));
    expect(
      occurrences.map(
        (item) => tz.TZDateTime.from(item.startsAtUtc, newYork).hour,
      ),
      everyElement(9),
    );
    expect(
      occurrences[1].startsAtUtc.difference(occurrences[0].startsAtUtc),
      const Duration(hours: 23),
    );
  });

  test('monthly recurrence clamps month-end and returns to original day', () {
    final shanghai = tz.getLocation('Asia/Shanghai');
    final event = _event(
      startsAtUtc: tz.TZDateTime(shanghai, 2026, 1, 31, 18, 30).toUtc(),
      timezoneId: shanghai.name,
      rule: const RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        count: 3,
      ),
    );

    final occurrences = const RecurrenceEngine().between(
      event,
      fromUtc: DateTime.utc(2026, 1, 1),
      toUtc: DateTime.utc(2026, 5, 1),
    );
    final localDays = occurrences
        .map((item) => tz.TZDateTime.from(item.startsAtUtc, shanghai).day)
        .toList();

    expect(localDays, [31, 28, 31]);
  });

  test('weekly count applies to emitted rule occurrences', () {
    final shanghai = tz.getLocation('Asia/Shanghai');
    final event = _event(
      startsAtUtc: tz.TZDateTime(shanghai, 2026, 7, 13, 8).toUtc(),
      timezoneId: shanghai.name,
      rule: const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        weekdays: {DateTime.monday, DateTime.wednesday},
        count: 4,
      ),
    );

    final occurrences = const RecurrenceEngine().between(
      event,
      fromUtc: DateTime.utc(2026, 7, 1),
      toUtc: DateTime.utc(2026, 8, 1),
    );

    expect(occurrences, hasLength(4));
    expect(
      occurrences
          .map((item) => tz.TZDateTime.from(item.startsAtUtc, shanghai).weekday)
          .toList(),
      [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.monday,
        DateTime.wednesday,
      ],
    );
  });
}

ScheduleEventModel _event({
  required DateTime startsAtUtc,
  required String timezoneId,
  required RecurrenceRule rule,
}) => ScheduleEventModel(
  id: 'event-1',
  title: '测试日程',
  startsAtUtc: startsAtUtc,
  duration: const Duration(hours: 1),
  timezoneId: timezoneId,
  recurrence: rule,
);
