import 'dart:convert';

enum ScheduleSource { manual, ai, sharePoll, system }

enum ScheduleStatus { active, completed, cancelled }

enum ReminderCapability { exact, approximate, denied, snoozed }

enum RecurrenceFrequency { daily, weekly, monthly }

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.count,
    this.untilUtc,
  }) : assert(interval > 0),
       assert(count == null || count > 0);

  final RecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final int? count;
  final DateTime? untilUtc;

  Map<String, Object?> toJson() => {
    'frequency': frequency.name,
    'interval': interval,
    'weekdays': weekdays.toList()..sort(),
    'count': count,
    'untilUtc': untilUtc?.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory RecurrenceRule.fromJson(Map<String, Object?> json) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.byName(
        json['frequency']! as String,
      ),
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      weekdays: ((json['weekdays'] as List<Object?>?) ?? const [])
          .map((value) => (value! as num).toInt())
          .toSet(),
      count: (json['count'] as num?)?.toInt(),
      untilUtc: json['untilUtc'] == null
          ? null
          : DateTime.parse(json['untilUtc']! as String).toUtc(),
    );
  }

  factory RecurrenceRule.decode(String value) =>
      RecurrenceRule.fromJson(jsonDecode(value) as Map<String, Object?>);
}

class ScheduleEventModel {
  const ScheduleEventModel({
    required this.id,
    required this.title,
    required this.startsAtUtc,
    required this.duration,
    required this.timezoneId,
    this.notes = '',
    this.allDay = false,
    this.recurrence,
    this.status = ScheduleStatus.active,
    this.source = ScheduleSource.manual,
  });

  final String id;
  final String title;
  final String notes;
  final DateTime startsAtUtc;
  final Duration duration;
  final String timezoneId;
  final bool allDay;
  final RecurrenceRule? recurrence;
  final ScheduleStatus status;
  final ScheduleSource source;
}

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.eventId,
    required this.offset,
    this.enabled = true,
    this.exactRequested = false,
  });

  final String id;
  final String eventId;
  final Duration offset;
  final bool enabled;
  final bool exactRequested;
}

class ScheduleOccurrence {
  const ScheduleOccurrence({
    required this.eventId,
    required this.index,
    required this.startsAtUtc,
    required this.endsAtUtc,
  });

  final String eventId;
  final int index;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
}
