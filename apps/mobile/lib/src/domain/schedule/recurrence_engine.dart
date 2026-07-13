import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import 'schedule_models.dart';

class RecurrenceEngine {
  const RecurrenceEngine();

  List<ScheduleOccurrence> between(
    ScheduleEventModel event, {
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 500,
  }) {
    if (!toUtc.isAfter(fromUtc) || limit < 1) return const [];
    final location = tz.getLocation(event.timezoneId);
    final base = tz.TZDateTime.from(event.startsAtUtc.toUtc(), location);
    final rule = event.recurrence;
    if (rule == null) {
      return _inside(event, event.startsAtUtc.toUtc(), fromUtc, toUtc)
          ? [_occurrence(event, 0, event.startsAtUtc.toUtc())]
          : const [];
    }

    return switch (rule.frequency) {
      RecurrenceFrequency.daily => _daily(
        event,
        base,
        rule,
        fromUtc,
        toUtc,
        limit,
      ),
      RecurrenceFrequency.weekly => _weekly(
        event,
        base,
        rule,
        fromUtc,
        toUtc,
        limit,
      ),
      RecurrenceFrequency.monthly => _monthly(
        event,
        base,
        rule,
        fromUtc,
        toUtc,
        limit,
      ),
    };
  }

  List<ScheduleOccurrence> _daily(
    ScheduleEventModel event,
    tz.TZDateTime base,
    RecurrenceRule rule,
    DateTime fromUtc,
    DateTime toUtc,
    int limit,
  ) {
    final result = <ScheduleOccurrence>[];
    for (
      var index = 0;
      index < (rule.count ?? 1000000) && result.length < limit;
      index++
    ) {
      final local = tz.TZDateTime(
        base.location,
        base.year,
        base.month,
        base.day + index * rule.interval,
        base.hour,
        base.minute,
        base.second,
        base.millisecond,
      );
      final utc = local.toUtc();
      if (_pastRuleOrWindow(utc, rule, toUtc)) break;
      if (_inside(event, utc, fromUtc, toUtc)) {
        result.add(_occurrence(event, index, utc));
      }
    }
    return result;
  }

  List<ScheduleOccurrence> _weekly(
    ScheduleEventModel event,
    tz.TZDateTime base,
    RecurrenceRule rule,
    DateTime fromUtc,
    DateTime toUtc,
    int limit,
  ) {
    final weekdays = rule.weekdays.isEmpty ? {base.weekday} : rule.weekdays;
    final result = <ScheduleOccurrence>[];
    var emitted = 0;
    var dayOffset = 0;
    while (emitted < (rule.count ?? 1000000) && result.length < limit) {
      final day = tz.TZDateTime(
        base.location,
        base.year,
        base.month,
        base.day + dayOffset,
      );
      final weekIndex = dayOffset ~/ 7;
      if (weekIndex % rule.interval == 0 && weekdays.contains(day.weekday)) {
        final local = tz.TZDateTime(
          base.location,
          day.year,
          day.month,
          day.day,
          base.hour,
          base.minute,
          base.second,
          base.millisecond,
        );
        if (!local.isBefore(base)) {
          final utc = local.toUtc();
          if (_pastRuleOrWindow(utc, rule, toUtc)) break;
          if (_inside(event, utc, fromUtc, toUtc)) {
            result.add(_occurrence(event, emitted, utc));
          }
          emitted++;
        }
      }
      dayOffset++;
      if (dayOffset > 366000) break;
    }
    return result;
  }

  List<ScheduleOccurrence> _monthly(
    ScheduleEventModel event,
    tz.TZDateTime base,
    RecurrenceRule rule,
    DateTime fromUtc,
    DateTime toUtc,
    int limit,
  ) {
    final result = <ScheduleOccurrence>[];
    for (
      var index = 0;
      index < (rule.count ?? 1000000) && result.length < limit;
      index++
    ) {
      final totalMonth =
          base.year * 12 + base.month - 1 + index * rule.interval;
      final year = totalMonth ~/ 12;
      final month = totalMonth % 12 + 1;
      final lastDay = tz.TZDateTime(base.location, year, month + 1, 0).day;
      final local = tz.TZDateTime(
        base.location,
        year,
        month,
        math.min(base.day, lastDay),
        base.hour,
        base.minute,
        base.second,
        base.millisecond,
      );
      final utc = local.toUtc();
      if (_pastRuleOrWindow(utc, rule, toUtc)) break;
      if (_inside(event, utc, fromUtc, toUtc)) {
        result.add(_occurrence(event, index, utc));
      }
    }
    return result;
  }

  bool _pastRuleOrWindow(DateTime utc, RecurrenceRule rule, DateTime toUtc) =>
      (rule.untilUtc != null && utc.isAfter(rule.untilUtc!)) ||
      !utc.isBefore(toUtc.toUtc());

  bool _inside(
    ScheduleEventModel event,
    DateTime startUtc,
    DateTime fromUtc,
    DateTime toUtc,
  ) {
    final end = startUtc.add(event.duration);
    return end.isAfter(fromUtc.toUtc()) && startUtc.isBefore(toUtc.toUtc());
  }

  ScheduleOccurrence _occurrence(
    ScheduleEventModel event,
    int index,
    DateTime startsAtUtc,
  ) => ScheduleOccurrence(
    eventId: event.id,
    index: index,
    startsAtUtc: startsAtUtc,
    endsAtUtc: startsAtUtc.add(event.duration),
  );
}
