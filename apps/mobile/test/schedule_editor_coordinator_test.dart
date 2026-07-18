import 'package:daylink_mobile/src/application/schedule_editor_coordinator.dart';
import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/notification_preferences_repository.dart';
import 'package:daylink_mobile/src/data/schedule_repository.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_editor_models.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ScheduleRepository repository;
  late NotificationPreferencesRepository preferences;

  setUp(() {
    database = AppDatabase.inMemory();
    repository = ScheduleRepository(database);
    preferences = NotificationPreferencesRepository(database);
  });

  tearDown(() => database.close());

  test('loads the device timezone and persisted reminder default', () async {
    await preferences.save(
      const NotificationPreferencesModel(defaultLeadMinutes: 30),
    );
    final coordinator = ScheduleEditorCoordinator(
      repository: repository,
      notificationPreferences: preferences,
      localTimezoneId: () async => 'Asia/Shanghai',
      ensureNotificationPermission: () async => true,
      reconcileNotifications: () async => ReminderCapability.exact,
    );

    final defaults = await coordinator.loadScheduleEditorDefaults();

    expect(defaults.timezoneId, 'Asia/Shanghai');
    expect(defaults.defaultReminderLeadMinutes, 30);
  });

  test(
    'persists the event before reporting denied notification delivery',
    () async {
      final coordinator = ScheduleEditorCoordinator(
        repository: repository,
        notificationPreferences: preferences,
        localTimezoneId: () async => 'Asia/Shanghai',
        ensureNotificationPermission: () async => false,
        reconcileNotifications: () async => ReminderCapability.denied,
      );
      final event = _event('denied-event');
      final reminder = ReminderModel(
        id: 'denied-reminder',
        eventId: event.id,
        offset: const Duration(minutes: 10),
      );

      final result = await coordinator.saveScheduleEvent(
        event: event,
        reminders: [reminder],
      );

      expect(
        result.reminderDelivery,
        ScheduleReminderDelivery.permissionDenied,
      );
      expect((await repository.eventById(event.id))?.title, '项目复盘');
      expect(await repository.remindersForEvents([event.id]), hasLength(1));
    },
  );

  test('reports scheduled only when the native mapping exists', () async {
    late ScheduleEditorCoordinator coordinator;
    final event = _event('scheduled-event');
    final reminder = ReminderModel(
      id: 'scheduled-reminder',
      eventId: event.id,
      offset: const Duration(minutes: 10),
    );
    coordinator = ScheduleEditorCoordinator(
      repository: repository,
      notificationPreferences: preferences,
      localTimezoneId: () async => 'Asia/Shanghai',
      ensureNotificationPermission: () async => true,
      reconcileNotifications: () async {
        await repository.upsertNotificationMapping(
          NotificationMappingDraft(
            notificationId: 72,
            reminderId: reminder.id,
            eventId: event.id,
            occurrenceStartsAtUtc: event.startsAtUtc,
            scheduledForUtc: event.startsAtUtc.subtract(reminder.offset),
            capability: ReminderCapability.exact,
          ),
        );
        return ReminderCapability.exact;
      },
    );

    final result = await coordinator.saveScheduleEvent(
      event: event,
      reminders: [reminder],
    );

    expect(result.reminderDelivery, ScheduleReminderDelivery.scheduled);
  });

  test(
    'keeps the saved event when native reconciliation is interrupted',
    () async {
      final coordinator = ScheduleEditorCoordinator(
        repository: repository,
        notificationPreferences: preferences,
        localTimezoneId: () async => 'Asia/Shanghai',
        ensureNotificationPermission: () async => true,
        reconcileNotifications: () async => throw StateError('interrupted'),
      );
      final event = _event('deferred-event');
      final reminder = ReminderModel(
        id: 'deferred-reminder',
        eventId: event.id,
        offset: const Duration(minutes: 10),
      );

      final result = await coordinator.saveScheduleEvent(
        event: event,
        reminders: [reminder],
      );

      expect(result.reminderDelivery, ScheduleReminderDelivery.deferred);
      expect(await repository.eventById(event.id), isNotNull);
    },
  );
}

ScheduleEventModel _event(String id) => ScheduleEventModel(
  id: id,
  title: '项目复盘',
  startsAtUtc: DateTime.utc(2026, 7, 20, 6),
  duration: const Duration(hours: 1),
  timezoneId: 'Asia/Shanghai',
);
