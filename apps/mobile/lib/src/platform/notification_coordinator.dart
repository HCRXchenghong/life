import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_database.dart';
import '../data/notification_preferences_repository.dart';
import '../data/schedule_repository.dart';
import '../domain/notifications/notification_settings.dart';
import '../domain/schedule/recurrence_engine.dart';
import '../domain/schedule/schedule_models.dart';

const _scheduleCategory = 'daylink_schedule';
const _doneAction = 'done';
const _snoozeAction = 'snooze_10';
const _settingsChannel = MethodChannel('app.daylink.daylink_mobile/settings');

@pragma('vm:entry-point')
Future<void> daylinkNotificationBackground(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  if (response.payload == null) return;
  final payload = jsonDecode(response.payload!) as Map<String, Object?>;
  final eventId = payload['eventId'] as String?;
  final accountId = payload['accountId'] as String?;
  if (eventId == null || accountId == null) return;
  final database = AppDatabase.openForAccount(accountId);
  try {
    final repository = ScheduleRepository(database);
    final preferences = NotificationPreferencesRepository(database);
    final coordinator = NotificationCoordinator(
      accountId: accountId,
      repository: repository,
      preferences: preferences,
    );
    await coordinator.initialize();
    await coordinator.handleAction(response);
  } finally {
    await database.close();
  }
}

class NotificationCoordinator {
  NotificationCoordinator({
    required this.accountId,
    required this._repository,
    required this._preferences,
    FlutterLocalNotificationsPlugin? plugin,
    this._recurrence = const RecurrenceEngine(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final ScheduleRepository _repository;
  final NotificationPreferencesRepository _preferences;
  final String accountId;
  final FlutterLocalNotificationsPlugin _plugin;
  final RecurrenceEngine _recurrence;
  bool _initialized = false;

  Future<void> initialize({
    void Function(NotificationResponse response)? onForegroundAction,
  }) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _scheduleCategory,
          actions: [
            DarwinNotificationAction.plain(_doneAction, '完成'),
            DarwinNotificationAction.plain(_snoozeAction, '10 分钟后提醒'),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: daylinkNotificationBackground,
    );
    _initialized = true;
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<NotificationPermissionStatus> notificationPermissionStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return NotificationPermissionStatus.unsupported;
    }
    return await _notificationsAllowed()
        ? NotificationPermissionStatus.authorized
        : NotificationPermissionStatus.denied;
  }

  Future<void> openSystemNotificationSettings() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _settingsChannel.invokeMethod<void>('openNotificationSettings');
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  Future<ReconcileResult> reconcile({DateTime? nowUtc}) async {
    if (!_initialized) await initialize();
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final preferences = await _preferences.load();
    final events = await _repository.activeEvents();
    final reminders = await _repository.remindersForEvents(
      events.map((event) => event.id),
    );
    final remindersByEvent = <String, List<ReminderModel>>{};
    for (final reminder in reminders) {
      remindersByEvent.putIfAbsent(reminder.eventId, () => []).add(reminder);
    }
    final notificationAllowed = await _notificationsAllowed();
    final exactAllowed = await _exactAlarmsAllowed();
    final candidates = <_Candidate>[];
    final horizon = now.add(const Duration(days: 370));
    for (final event in events) {
      for (final occurrence in _recurrence.between(
        event,
        fromUtc: now,
        toUtc: horizon,
        limit: 500,
      )) {
        for (final reminder
            in remindersByEvent[event.id] ?? const <ReminderModel>[]) {
          final scheduledFor = occurrence.startsAtUtc.subtract(reminder.offset);
          if (scheduledFor.isAfter(now)) {
            candidates.add(
              _Candidate(
                event: event,
                occurrence: occurrence,
                reminder: reminder,
                scheduledForUtc: scheduledFor,
              ),
            );
          }
        }
      }
    }
    candidates.sort((a, b) => a.scheduledForUtc.compareTo(b.scheduledForUtc));
    final limit = Platform.isIOS ? 50 : 500;
    final selected = candidates.take(limit).toList(growable: false);
    final canSchedule = notificationAllowed && preferences.remindersEnabled;
    final existingMappings = canSchedule
        ? await _repository.scheduledNotificationMappings()
        : await _repository.allNotificationMappings();
    for (final mapping in existingMappings) {
      await _plugin.cancel(id: mapping.notificationId);
    }
    final mappings = <NotificationMappingDraft>[];
    if (canSchedule) {
      for (final candidate in selected) {
        final exact = candidate.reminder.exactRequested && exactAllowed;
        final id = _stableNotificationId(
          '${candidate.reminder.id}:${candidate.occurrence.startsAtUtc.toIso8601String()}',
        );
        final payload = jsonEncode({
          'accountId': accountId,
          'eventId': candidate.event.id,
          'reminderId': candidate.reminder.id,
          'occurrenceStartsAtUtc': candidate.occurrence.startsAtUtc
              .toIso8601String(),
        });
        await _plugin.zonedSchedule(
          id: id,
          title: candidate.event.title,
          body: _body(candidate),
          scheduledDate: tz.TZDateTime.from(
            candidate.scheduledForUtc,
            tz.local,
          ),
          notificationDetails: _notificationDetails(
            preferences.soundAndVibrationEnabled,
          ),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        mappings.add(
          NotificationMappingDraft(
            notificationId: id,
            reminderId: candidate.reminder.id,
            eventId: candidate.event.id,
            occurrenceStartsAtUtc: candidate.occurrence.startsAtUtc,
            scheduledForUtc: candidate.scheduledForUtc,
            capability: exact
                ? ReminderCapability.exact
                : ReminderCapability.approximate,
          ),
        );
      }
    }
    if (canSchedule) {
      await _repository.replaceNotificationMappings(mappings);
    } else {
      await _repository.deleteAllNotificationMappings();
    }
    return ReconcileResult(
      scheduled: mappings.length,
      deferred: candidates.length - selected.length,
      capability: !notificationAllowed || !preferences.remindersEnabled
          ? ReminderCapability.denied
          : exactAllowed
          ? ReminderCapability.exact
          : ReminderCapability.approximate,
    );
  }

  Future<void> handleAction(NotificationResponse response) async {
    final rawPayload = response.payload;
    if (rawPayload == null || rawPayload.isEmpty) return;
    final payload = jsonDecode(rawPayload) as Map<String, Object?>;
    final eventId = payload['eventId'] as String?;
    if (eventId == null) return;

    if (response.actionId == _doneAction) {
      final mappings = await _repository.notificationMappingsForEvent(eventId);
      for (final mapping in mappings) {
        await _plugin.cancel(id: mapping.notificationId);
        await _repository.deleteNotificationMapping(mapping.notificationId);
      }
      await _repository.setStatus(eventId, ScheduleStatus.completed);
      return;
    }

    if (response.actionId != _snoozeAction) return;
    final event = await _repository.eventById(eventId);
    final reminderId = payload['reminderId'] as String?;
    final occurrenceRaw = payload['occurrenceStartsAtUtc'] as String?;
    if (event == null || reminderId == null || occurrenceRaw == null) return;
    if (!_initialized) await initialize();
    final preferences = await _preferences.load();
    if (!preferences.remindersEnabled || !await _notificationsAllowed()) return;
    final scheduledFor = DateTime.now().toUtc().add(
      const Duration(minutes: 10),
    );
    final notificationId = _stableNotificationId(
      'snooze:$reminderId:${scheduledFor.toIso8601String()}',
    );
    await _plugin.zonedSchedule(
      id: notificationId,
      title: event.title,
      body: '稍后提醒：${event.title}',
      scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
      notificationDetails: _notificationDetails(
        preferences.soundAndVibrationEnabled,
      ),
      androidScheduleMode: await _exactAlarmsAllowed()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: rawPayload,
    );
    await _repository.upsertNotificationMapping(
      NotificationMappingDraft(
        notificationId: notificationId,
        reminderId: reminderId,
        eventId: eventId,
        occurrenceStartsAtUtc: DateTime.parse(occurrenceRaw).toUtc(),
        scheduledForUtc: scheduledFor,
        capability: ReminderCapability.snoozed,
      ),
    );
  }

  Future<bool> _notificationsAllowed() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }

  Future<bool> _exactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  String _body(_Candidate candidate) {
    final minutes = candidate.reminder.offset.inMinutes;
    if (minutes == 0) return '现在开始';
    if (minutes < 60) return '$minutes 分钟后开始';
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} 天后开始';
    return '${minutes ~/ 60} 小时后开始';
  }

  int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}

NotificationDetails _notificationDetails(bool soundAndVibrationEnabled) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        soundAndVibrationEnabled
            ? 'daylink_schedule_alerts'
            : 'daylink_schedule_quiet',
        soundAndVibrationEnabled ? '日程提醒' : '静音日程提醒',
        channelDescription: 'Daylink 日程和活动提醒',
        importance: Importance.high,
        priority: Priority.high,
        playSound: soundAndVibrationEnabled,
        enableVibration: soundAndVibrationEnabled,
        actions: const [
          AndroidNotificationAction(_doneAction, '完成'),
          AndroidNotificationAction(_snoozeAction, '10 分钟后提醒'),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentSound: soundAndVibrationEnabled,
        categoryIdentifier: _scheduleCategory,
      ),
    );

class ReconcileResult {
  const ReconcileResult({
    required this.scheduled,
    required this.deferred,
    required this.capability,
  });

  final int scheduled;
  final int deferred;
  final ReminderCapability capability;
}

class _Candidate {
  const _Candidate({
    required this.event,
    required this.occurrence,
    required this.reminder,
    required this.scheduledForUtc,
  });

  final ScheduleEventModel event;
  final ScheduleOccurrence occurrence;
  final ReminderModel reminder;
  final DateTime scheduledForUtc;
}
