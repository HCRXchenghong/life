import 'package:uuid/uuid.dart';

import '../data/schedule_repository.dart';
import '../data/share_poll_client.dart';
import '../data/share_poll_repository.dart';
import '../domain/schedule/schedule_models.dart';
import '../domain/share/share_poll_models.dart';

class SharePollCoordinator {
  SharePollCoordinator({
    required this._client,
    required this._polls,
    required this._schedules,
    required this._reconcileNotifications,
    this._uuid = const Uuid(),
  });

  final SharePollClient _client;
  final SharePollRepository _polls;
  final ScheduleRepository _schedules;
  final Future<void> Function() _reconcileNotifications;
  final Uuid _uuid;

  Future<LocalSharePollRef> create(CreateSharePollDraft draft) async {
    final created = await _client.create(draft);
    return _polls.saveCreated(created);
  }

  Future<SharePollState> refresh(LocalSharePollRef poll) =>
      _client.get(poll.publicToken);

  Future<ScheduleEventModel> finalizeAndCreateSchedule({
    required LocalSharePollRef poll,
    required String slotId,
    List<Duration> reminderOffsets = const [
      Duration(days: 1),
      Duration(hours: 1),
    ],
  }) async {
    if (poll.status != SharePollStatus.open) {
      throw StateError('only an open poll can be finalized');
    }
    final manageToken = await _polls.loadManageToken(poll);
    final finalized = await _client.finalize(
      publicToken: poll.publicToken,
      manageToken: manageToken,
      slotId: slotId,
      expectedVersion: poll.version,
    );
    await _polls.markFinalized(finalized);
    final slot = finalized.selectedSlot;
    final eventId = 'share-poll:${poll.id}';
    final event = ScheduleEventModel(
      id: eventId,
      title: poll.title,
      startsAtUtc: slot.startsAtUtc,
      duration: slot.endsAtUtc.difference(slot.startsAtUtc),
      timezoneId: poll.timezoneId,
      notes: 'Daylink 好友选时间 · ${poll.inviteUrl}',
      source: ScheduleSource.sharePoll,
    );
    final reminders = reminderOffsets
        .where((offset) => !offset.isNegative)
        .toSet()
        .map(
          (offset) => ReminderModel(
            id: _uuid.v4(),
            eventId: eventId,
            offset: offset,
            exactRequested: offset <= const Duration(hours: 1),
          ),
        )
        .toList(growable: false);
    await _schedules.saveEvent(event, reminders);
    await _reconcileNotifications();
    return event;
  }
}
