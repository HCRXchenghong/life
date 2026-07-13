import '../data/share_poll_repository.dart';
import '../domain/ai/tool_protocol.dart';
import '../domain/share/share_poll_models.dart';
import 'share_poll_coordinator.dart';

class SharePollTools {
  SharePollTools({required this._coordinator, required this._repository});

  final SharePollCoordinator _coordinator;
  final SharePollRepository _repository;

  void register(ToolRegistry registry) {
    registry
      ..register(
        const ToolSpec(
          name: 'daylink_poll_list',
          description:
              'List locally managed time polls without returning management tokens.',
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
          final polls = await _repository.list();
          return {
            'polls': polls
                .map(
                  (poll) => {
                    'id': poll.id,
                    'title': poll.title,
                    'invite_url': poll.inviteUrl.toString(),
                    'timezone': poll.timezoneId,
                    'status': poll.status.name,
                    'version': poll.version,
                    'selected_slot': poll.selectedSlot?.toJson(),
                  },
                )
                .toList(growable: false),
          };
        },
      )
      ..register(
        const ToolSpec(
          name: 'daylink_poll_get',
          description:
              'Refresh one public poll and return candidates and aggregate votes.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'poll_id': {'type': 'string', 'minLength': 1, 'maxLength': 64},
            },
            'required': ['poll_id'],
            'additionalProperties': false,
          },
          risk: ToolRisk.readOnly,
          approval: ToolApprovalPolicy.never,
          sandbox: ToolSandbox.readOnly,
        ),
        (arguments) async {
          final local = await _repository.get(arguments['poll_id']! as String);
          final state = await _coordinator.refresh(local);
          return _stateJson(state);
        },
      )
      ..register(
        const ToolSpec(
          name: 'daylink_poll_create',
          description:
              'Create a friend time-selection link after explicit user approval.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'minLength': 1, 'maxLength': 160},
              'description': {'type': 'string', 'maxLength': 2000},
              'timezone': {'type': 'string', 'minLength': 1, 'maxLength': 80},
              'closes_at': {'type': 'string', 'minLength': 20, 'maxLength': 40},
              'slots': {
                'type': 'array',
                'minItems': 2,
                'maxItems': 30,
                'items': {
                  'type': 'object',
                  'properties': {
                    'label': {'type': 'string', 'maxLength': 120},
                    'starts_at': {
                      'type': 'string',
                      'minLength': 20,
                      'maxLength': 40,
                    },
                    'ends_at': {
                      'type': 'string',
                      'minLength': 20,
                      'maxLength': 40,
                    },
                  },
                  'required': ['starts_at', 'ends_at'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['title', 'timezone', 'slots'],
            'additionalProperties': false,
          },
          risk: ToolRisk.medium,
          approval: ToolApprovalPolicy.always,
          sandbox: ToolSandbox.localData,
          timeout: Duration(seconds: 45),
        ),
        (arguments) async {
          final rawSlots = arguments['slots']! as List<Object?>;
          final poll = await _coordinator.create(
            CreateSharePollDraft(
              title: arguments['title']! as String,
              description: arguments['description'] as String? ?? '',
              timezoneId: arguments['timezone']! as String,
              closesAtUtc: arguments['closes_at'] == null
                  ? null
                  : DateTime.parse(arguments['closes_at']! as String).toUtc(),
              slots: rawSlots
                  .map((value) {
                    final slot = value! as Map<String, Object?>;
                    return SharePollSlotDraft(
                      label: slot['label'] as String? ?? '',
                      startsAtUtc: DateTime.parse(
                        slot['starts_at']! as String,
                      ).toUtc(),
                      endsAtUtc: DateTime.parse(
                        slot['ends_at']! as String,
                      ).toUtc(),
                    );
                  })
                  .toList(growable: false),
            ),
          );
          return {
            'poll_id': poll.id,
            'invite_url': poll.inviteUrl.toString(),
            'status': poll.status.name,
            'version': poll.version,
          };
        },
      )
      ..register(
        const ToolSpec(
          name: 'daylink_poll_finalize',
          description:
              'Finalize one poll and import the selected slot into the local schedule.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'poll_id': {'type': 'string', 'minLength': 1, 'maxLength': 64},
              'slot_id': {'type': 'string', 'minLength': 1, 'maxLength': 64},
              'reminder_offsets_minutes': {
                'type': 'array',
                'maxItems': 8,
                'items': {'type': 'integer', 'minimum': 0, 'maximum': 525600},
              },
            },
            'required': ['poll_id', 'slot_id', 'reminder_offsets_minutes'],
            'additionalProperties': false,
          },
          risk: ToolRisk.high,
          approval: ToolApprovalPolicy.always,
          sandbox: ToolSandbox.localData,
          timeout: Duration(seconds: 45),
        ),
        (arguments) async {
          final poll = await _repository.get(arguments['poll_id']! as String);
          final offsets =
              (arguments['reminder_offsets_minutes']! as List<Object?>)
                  .map((value) => Duration(minutes: (value! as num).toInt()))
                  .toList(growable: false);
          final event = await _coordinator.finalizeAndCreateSchedule(
            poll: poll,
            slotId: arguments['slot_id']! as String,
            reminderOffsets: offsets,
          );
          return {
            'poll_id': poll.id,
            'event_id': event.id,
            'starts_at_utc': event.startsAtUtc.toIso8601String(),
            'duration_minutes': event.duration.inMinutes,
          };
        },
      );
  }
}

Map<String, Object?> _stateJson(SharePollState state) => {
  'poll': {
    'id': state.poll.id,
    'title': state.poll.title,
    'status': state.poll.status.name,
    'timezone': state.poll.timezoneId,
    'version': state.poll.version,
    'selected_slot_id': state.poll.selectedSlotId,
  },
  'slots': state.slots.map((slot) => slot.toJson()).toList(growable: false),
  'participants': state.participants
      .map(
        (participant) => {
          'id': participant.id,
          'display_name': participant.displayName,
        },
      )
      .toList(growable: false),
  'votes': state.votes
      .map(
        (vote) => {
          'participant_id': vote.participantId,
          'slot_id': vote.slotId,
          'response': vote.response.name,
        },
      )
      .toList(growable: false),
};
