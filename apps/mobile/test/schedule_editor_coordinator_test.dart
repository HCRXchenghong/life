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
      cancelEventNotifications: (_) async {},
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
        cancelEventNotifications: (_) async {},
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
      cancelEventNotifications: (_) async {},
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
        cancelEventNotifications: (_) async {},
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

  test('loads the event detail with its account-scoped reminders', () async {
    final event = _event('detail-event');
    final reminder = ReminderModel(
      id: 'detail-reminder',
      eventId: event.id,
      offset: const Duration(minutes: 10),
    );
    await repository.saveEvent(event, [reminder]);
    final coordinator = ScheduleEditorCoordinator(
      repository: repository,
      notificationPreferences: preferences,
      localTimezoneId: () async => 'Asia/Shanghai',
      ensureNotificationPermission: () async => true,
      cancelEventNotifications: (_) async {},
      reconcileNotifications: () async => ReminderCapability.exact,
    );

    final detail = await coordinator.loadScheduleDetail(event.id);

    expect(detail?.event.title, '项目复盘');
    expect(detail?.reminders.single.id, reminder.id);
    expect(await coordinator.loadScheduleDetail('missing'), isNull);
  });

  test('changes status before cancelling and reconciling reminders', () async {
    final event = _event('complete-event');
    await repository.saveEvent(event, const []);
    final calls = <String>[];
    final coordinator = ScheduleEditorCoordinator(
      repository: repository,
      notificationPreferences: preferences,
      localTimezoneId: () async => 'Asia/Shanghai',
      ensureNotificationPermission: () async => true,
      cancelEventNotifications: (eventId) async => calls.add('cancel:$eventId'),
      reconcileNotifications: () async {
        calls.add('reconcile');
        return ReminderCapability.exact;
      },
    );

    final result = await coordinator.setScheduleStatus(
      eventId: event.id,
      status: ScheduleStatus.completed,
    );

    expect(result.status, ScheduleStatus.completed);
    expect(result.remindersCancelled, isTrue);
    expect(calls, ['cancel:${event.id}', 'reconcile']);
    expect(
      (await repository.eventById(event.id))?.status,
      ScheduleStatus.completed,
    );
  });

  test('keeps changed status when native cancellation fails', () async {
    final event = _event('cancel-failure-event');
    await repository.saveEvent(event, const []);
    final coordinator = ScheduleEditorCoordinator(
      repository: repository,
      notificationPreferences: preferences,
      localTimezoneId: () async => 'Asia/Shanghai',
      ensureNotificationPermission: () async => true,
      cancelEventNotifications: (_) async => throw StateError('unavailable'),
      reconcileNotifications: () async => ReminderCapability.exact,
    );

    final result = await coordinator.setScheduleStatus(
      eventId: event.id,
      status: ScheduleStatus.cancelled,
    );

    expect(result.remindersCancelled, isFalse);
    expect(
      (await repository.eventById(event.id))?.status,
      ScheduleStatus.cancelled,
    );
  });
}

ScheduleEventModel _event(String id) => ScheduleEventModel(
  id: id,
  title: '项目复盘',
  startsAtUtc: DateTime.utc(2026, 7, 20, 6),
  duration: const Duration(hours: 1),
  timezoneId: 'Asia/Shanghai',
);
