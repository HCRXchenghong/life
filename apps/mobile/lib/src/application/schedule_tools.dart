import 'package:uuid/uuid.dart';

import '../data/schedule_repository.dart';
import '../domain/ai/tool_protocol.dart';
import '../domain/schedule/schedule_models.dart';

class ScheduleTools {
  ScheduleTools({
    required this._repository,
    required this._reconcileNotifications,
    this._uuid = const Uuid(),
  });

  final ScheduleRepository _repository;
  final Future<void> Function() _reconcileNotifications;
  final Uuid _uuid;

  void register(ToolRegistry registry) {
    registry
      ..register(
        const ToolSpec(
          name: 'daylink_schedule_list',
          description:
              'List active Daylink schedule events. This tool never returns private notes.',
          inputSchema: {
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
            'additionalProperties': false,
          },
          risk: ToolRisk.readOnly,
          approval: ToolApprovalPolicy.never,
          sandbox: ToolSandbox.readOnly,
        ),
        (_) async {
          final events = await _repository.activeEvents();
          return {
            'events': events
                .map(
                  (event) => {
                    'id': event.id,
                    'title': event.title,
                    'starts_at_utc': event.startsAtUtc.toIso8601String(),
                    'duration_minutes': event.duration.inMinutes,
                    'timezone': event.timezoneId,
                    'recurring': event.recurrence != null,
                  },
                )
                .toList(),
          };
        },
      )
      ..register(
        const ToolSpec(
          name: 'daylink_schedule_create',
          description:
              'Create one local schedule event and its reminders after explicit user approval.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'minLength': 1, 'maxLength': 300},
              'starts_at': {
                'type': 'string',
                'description': 'ISO-8601 timestamp with offset',
              },
              'timezone': {'type': 'string', 'description': 'IANA time zone'},
              'duration_minutes': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 10080,
              },
              'reminder_offsets_minutes': {
                'type': 'array',
                'items': {'type': 'integer', 'minimum': 0, 'maximum': 525600},
                'maxItems': 8,
              },
            },
            'required': [
              'title',
              'starts_at',
              'timezone',
              'duration_minutes',
              'reminder_offsets_minutes',
            ],
            'additionalProperties': false,
          },
          risk: ToolRisk.medium,
          approval: ToolApprovalPolicy.always,
          sandbox: ToolSandbox.localData,
        ),
        _create,
      )
      ..register(
        const ToolSpec(
          name: 'daylink_schedule_cancel',
          description:
              'Cancel a Daylink schedule event after explicit approval.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'event_id': {'type': 'string'},
            },
            'required': ['event_id'],
            'additionalProperties': false,
          },
          risk: ToolRisk.high,
          approval: ToolApprovalPolicy.always,
          sandbox: ToolSandbox.localData,
        ),
        (arguments) async {
          await _repository.setStatus(
            arguments['event_id']! as String,
            ScheduleStatus.cancelled,
          );
          await _reconcileNotifications();
          return {'cancelled': true};
        },
      );
  }

  Future<Object?> _create(Map<String, Object?> arguments) async {
    final title = (arguments['title']! as String).trim();
    if (title.isEmpty) throw const FormatException('title must not be empty');
    final startsAt = DateTime.parse(arguments['starts_at']! as String).toUtc();
    final duration = (arguments['duration_minutes']! as num).toInt();
    if (duration < 1 || duration > 10080) {
      throw const FormatException('invalid duration');
    }
    final offsets =
        (arguments['reminder_offsets_minutes']! as List<Object?>)
            .map((value) => (value! as num).toInt())
            .toSet()
            .toList()
          ..sort();
    final eventId = _uuid.v4();
    final event = ScheduleEventModel(
      id: eventId,
      title: title,
      startsAtUtc: startsAt,
      duration: Duration(minutes: duration),
      timezoneId: arguments['timezone']! as String,
      source: ScheduleSource.ai,
    );
    final reminders = offsets
        .map(
          (offset) => ReminderModel(
            id: _uuid.v4(),
            eventId: eventId,
            offset: Duration(minutes: offset),
            exactRequested: offset < 60,
          ),
        )
        .toList();
    await _repository.saveEvent(event, reminders);
    await _reconcileNotifications();
    return {
      'event_id': eventId,
      'title': title,
      'starts_at_utc': startsAt.toIso8601String(),
      'reminders': offsets,
    };
  }
}
