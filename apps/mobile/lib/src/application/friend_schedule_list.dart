import 'package:uuid/uuid.dart';

import '../data/app_session_monitor.dart';
import '../data/share_poll_client.dart';
import '../domain/schedule/recurrence_engine.dart';
import '../domain/schedule/schedule_models.dart';
import '../domain/share/share_poll_models.dart';
import 'daylink_services.dart';

abstract interface class FriendScheduleListSource {
  Future<List<ManagedSharePollSummary>> loadFriendSchedules();
}

abstract interface class FriendScheduleCreationSource
    implements FriendScheduleListSource {
  Future<String> loadFriendScheduleTimezoneId();

  Future<List<FriendScheduleConflict>> findFriendScheduleConflicts(
    List<SharePollSlotDraft> ranges,
  );

  Future<void> createFriendSchedule(CreateSharePollDraft draft);
}

abstract interface class FriendScheduleDetailSource
    implements FriendScheduleCreationSource {
  Future<FriendPollDetails> loadFriendScheduleDetails(String pollId);

  Future<FriendPollInvite> createFriendInvite({
    required String pollId,
    required String displayName,
  });

  Future<void> revokeFriendInvite({
    required String pollId,
    required String inviteId,
  });

  Future<void> confirmFriendSchedule({
    required FriendPollDetails details,
    required FriendTimeSuggestion suggestion,
  });
}

class FriendScheduleConflict {
  const FriendScheduleConflict({
    required this.eventId,
    required this.eventTitle,
    required this.startsAtUtc,
    required this.endsAtUtc,
  });

  final String eventId;
  final String eventTitle;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
}

class FriendScheduleListException implements Exception {
  const FriendScheduleListException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DaylinkFriendSchedules implements FriendScheduleDetailSource {
  const DaylinkFriendSchedules({
    required this.services,
    required this.apiBaseUri,
    required this.accessToken,
    required this.refreshAccessToken,
  });

  final DaylinkServices services;
  final Uri apiBaseUri;
  final AccessTokenProvider accessToken;
  final SessionRefreshCallback refreshAccessToken;

  @override
  Future<String> loadFriendScheduleTimezoneId() =>
      services.notifications.localTimezoneIdentifier();

  @override
  Future<void> createFriendSchedule(CreateSharePollDraft draft) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requiredToken();
      final client = SharePollClient(
        apiBaseUri: apiBaseUri,
        mobileToken: token,
      );
      try {
        await client.createExclusive(draft);
        return;
      } on ShareApiException catch (error) {
        if (error.statusCode == 401 && attempt == 0 && await _refreshOnce()) {
          continue;
        }
        if (error.statusCode == 401) {
          throw const FriendScheduleListException('登录已失效，请重新登录');
        }
        if (error.statusCode == 429) {
          throw const FriendScheduleListException('创建过于频繁，请稍后重试');
        }
        throw const FriendScheduleListException('暂时无法创建，请稍后重试');
      } on ArgumentError {
        throw const FriendScheduleListException('选时间内容不符合要求');
      } on FriendScheduleListException {
        rethrow;
      } on Object {
        throw const FriendScheduleListException('暂时无法创建，请稍后重试');
      } finally {
        client.close();
      }
    }
  }

  @override
  Future<List<FriendScheduleConflict>> findFriendScheduleConflicts(
    List<SharePollSlotDraft> ranges,
  ) async {
    if (ranges.isEmpty) return const [];
    final startsAt = ranges
        .map((range) => range.startsAtUtc.toUtc())
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final endsAt = ranges
        .map((range) => range.endsAtUtc.toUtc())
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final conflicts = <String, FriendScheduleConflict>{};
    for (final event in await services.schedules.activeEvents()) {
      final occurrences = const RecurrenceEngine().between(
        event,
        fromUtc: startsAt,
        toUtc: endsAt,
        limit: 500,
      );
      for (final occurrence in occurrences) {
        final overlaps = ranges.any(
          (range) =>
              occurrence.endsAtUtc.isAfter(range.startsAtUtc.toUtc()) &&
              occurrence.startsAtUtc.isBefore(range.endsAtUtc.toUtc()),
        );
        if (overlaps) {
          conflicts.putIfAbsent(
            event.id,
            () => FriendScheduleConflict(
              eventId: event.id,
              eventTitle: event.title,
              startsAtUtc: occurrence.startsAtUtc,
              endsAtUtc: occurrence.endsAtUtc,
            ),
          );
          break;
        }
      }
    }
    final result = conflicts.values.toList()
      ..sort((left, right) => left.startsAtUtc.compareTo(right.startsAtUtc));
    return List.unmodifiable(result);
  }

  @override
  Future<FriendPollDetails> loadFriendScheduleDetails(String pollId) =>
      _withClient(
        (client) => client.managedDetails(pollId),
        fallbackMessage: '暂时无法加载活动详情，请稍后重试',
      );

  @override
  Future<FriendPollInvite> createFriendInvite({
    required String pollId,
    required String displayName,
  }) => _withClient(
    (client) =>
        client.createFriendInvite(pollId: pollId, displayName: displayName),
    fallbackMessage: '暂时无法生成邀请，请稍后重试',
  );

  @override
  Future<void> revokeFriendInvite({
    required String pollId,
    required String inviteId,
  }) => _withClient(
    (client) => client.revokeFriendInvite(pollId: pollId, inviteId: inviteId),
    fallbackMessage: '暂时无法撤销邀请，请稍后重试',
  );

  @override
  Future<void> confirmFriendSchedule({
    required FriendPollDetails details,
    required FriendTimeSuggestion suggestion,
  }) async {
    await _withClient(
      (client) => client.confirmManaged(
        pollId: details.id,
        startsAtUtc: suggestion.startsAtUtc,
        endsAtUtc: suggestion.endsAtUtc,
        expectedVersion: details.version,
      ),
      fallbackMessage: '暂时无法确认时间，请稍后重试',
    );
    final defaults = await services.scheduleEditor.loadScheduleEditorDefaults();
    final eventId = 'share-poll:${details.id}';
    final reminders = <ReminderModel>[];
    final lead = Duration(minutes: defaults.defaultReminderLeadMinutes);
    if (suggestion.startsAtUtc.subtract(lead).isAfter(DateTime.now().toUtc())) {
      reminders.add(
        ReminderModel(
          id: const Uuid().v4(),
          eventId: eventId,
          offset: lead,
          exactRequested: true,
        ),
      );
    }
    await services.scheduleEditor.saveScheduleEvent(
      event: ScheduleEventModel(
        id: eventId,
        title: details.title,
        notes: details.description,
        startsAtUtc: suggestion.startsAtUtc,
        duration: suggestion.endsAtUtc.difference(suggestion.startsAtUtc),
        timezoneId: details.timezoneId,
        source: ScheduleSource.sharePoll,
      ),
      reminders: reminders,
    );
  }

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requiredToken();
      final client = SharePollClient(
        apiBaseUri: apiBaseUri,
        mobileToken: token,
      );
      try {
        return await client.listManaged();
      } on ShareApiException catch (error) {
        if (error.statusCode == 401 && attempt == 0 && await _refreshOnce()) {
          continue;
        }
        if (error.statusCode == 401) {
          throw const FriendScheduleListException('登录已失效，请重新登录');
        }
        throw const FriendScheduleListException('暂时无法加载，请稍后重试');
      } on FriendScheduleListException {
        rethrow;
      } on Object {
        throw const FriendScheduleListException('暂时无法加载，请稍后重试');
      } finally {
        client.close();
      }
    }
    throw const FriendScheduleListException('暂时无法加载，请稍后重试');
  }

  Future<String> _requiredToken() async {
    final token = await accessToken();
    if (token == null) {
      throw const FriendScheduleListException('登录已失效，请重新登录');
    }
    return token;
  }

  Future<bool> _refreshOnce() async {
    try {
      return await refreshAccessToken();
    } on Object {
      return false;
    }
  }

  Future<T> _withClient<T>(
    Future<T> Function(SharePollClient client) action, {
    required String fallbackMessage,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requiredToken();
      final client = SharePollClient(
        apiBaseUri: apiBaseUri,
        mobileToken: token,
      );
      try {
        return await action(client);
      } on ShareApiException catch (error) {
        if (error.statusCode == 401 && attempt == 0 && await _refreshOnce()) {
          continue;
        }
        if (error.statusCode == 401) {
          throw const FriendScheduleListException('登录已失效，请重新登录');
        }
        if (error.statusCode == 409 || error.statusCode == 429) {
          throw FriendScheduleListException(error.message);
        }
        throw FriendScheduleListException(fallbackMessage);
      } on ArgumentError {
        throw const FriendScheduleListException('提交内容不符合要求');
      } on FriendScheduleListException {
        rethrow;
      } on Object {
        throw FriendScheduleListException(fallbackMessage);
      } finally {
        client.close();
      }
    }
    throw FriendScheduleListException(fallbackMessage);
  }
}
