import '../data/notification_preferences_repository.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule/schedule_editor_models.dart';
import '../domain/schedule/schedule_models.dart';

class ScheduleEditorCoordinator implements ScheduleEditorSource {
  factory ScheduleEditorCoordinator({
    required ScheduleRepository repository,
    required NotificationPreferencesRepository notificationPreferences,
    required Future<String> Function() localTimezoneId,
    required Future<bool> Function() ensureNotificationPermission,
    required Future<ReminderCapability> Function() reconcileNotifications,
  }) => ScheduleEditorCoordinator._(
    repository,
    notificationPreferences,
    localTimezoneId,
    ensureNotificationPermission,
    reconcileNotifications,
  );

  const ScheduleEditorCoordinator._(
    this._repository,
    this._notificationPreferences,
    this._localTimezoneId,
    this._ensureNotificationPermission,
    this._reconcileNotifications,
  );

  final ScheduleRepository _repository;
  final NotificationPreferencesRepository _notificationPreferences;
  final Future<String> Function() _localTimezoneId;
  final Future<bool> Function() _ensureNotificationPermission;
  final Future<ReminderCapability> Function() _reconcileNotifications;

  @override
  Future<ScheduleEditorDefaults> loadScheduleEditorDefaults() async {
    final timezoneId = await _localTimezoneId();
    final preferences = await _notificationPreferences.load();
    return ScheduleEditorDefaults(
      timezoneId: timezoneId,
      defaultReminderLeadMinutes: preferences.defaultLeadMinutes,
    );
  }

  @override
  Future<ScheduleSaveResult> saveScheduleEvent({
    required ScheduleEventModel event,
    required List<ReminderModel> reminders,
  }) async {
    _validate(event, reminders);
    await _repository.saveEvent(event, reminders);
    if (reminders.isEmpty) {
      return ScheduleSaveResult(
        eventId: event.id,
        reminderDelivery: ScheduleReminderDelivery.none,
      );
    }

    try {
      final preferences = await _notificationPreferences.load();
      if (!preferences.remindersEnabled ||
          !await _ensureNotificationPermission()) {
        return ScheduleSaveResult(
          eventId: event.id,
          reminderDelivery: ScheduleReminderDelivery.permissionDenied,
        );
      }
      final capability = await _reconcileNotifications();
      if (capability == ReminderCapability.denied) {
        return ScheduleSaveResult(
          eventId: event.id,
          reminderDelivery: ScheduleReminderDelivery.permissionDenied,
        );
      }
      final mappings = await _repository.notificationMappingsForEvent(event.id);
      return ScheduleSaveResult(
        eventId: event.id,
        reminderDelivery: mappings.isEmpty
            ? ScheduleReminderDelivery.deferred
            : ScheduleReminderDelivery.scheduled,
      );
    } on Object {
      return ScheduleSaveResult(
        eventId: event.id,
        reminderDelivery: ScheduleReminderDelivery.deferred,
      );
    }
  }
}

void _validate(ScheduleEventModel event, List<ReminderModel> reminders) {
  final title = event.title.trim();
  if (title.isEmpty || title.length > 300 || title != event.title) {
    throw ArgumentError.value(event.title, 'event.title', 'Invalid title');
  }
  if (event.notes.length > 4000) {
    throw ArgumentError.value(event.notes, 'event.notes', 'Notes are too long');
  }
  if (event.timezoneId.isEmpty || event.timezoneId.length > 80) {
    throw ArgumentError.value(
      event.timezoneId,
      'event.timezoneId',
      'Invalid timezone',
    );
  }
  if (event.duration < const Duration(minutes: 1) ||
      event.duration > const Duration(days: 366)) {
    throw ArgumentError.value(
      event.duration,
      'event.duration',
      'Invalid duration',
    );
  }
  if (reminders.length > 10) {
    throw ArgumentError.value(reminders.length, 'reminders', 'Too many');
  }
  for (final reminder in reminders) {
    if (reminder.eventId != event.id ||
        reminder.offset.isNegative ||
        reminder.offset > const Duration(days: 365)) {
      throw ArgumentError.value(reminder.id, 'reminders', 'Invalid reminder');
    }
  }
}
