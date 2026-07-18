import 'schedule_models.dart';

class ScheduleEditorDefaults {
  const ScheduleEditorDefaults({
    required this.timezoneId,
    required this.defaultReminderLeadMinutes,
  });

  final String timezoneId;
  final int defaultReminderLeadMinutes;
}

enum ScheduleReminderDelivery { none, scheduled, permissionDenied, deferred }

class ScheduleSaveResult {
  const ScheduleSaveResult({
    required this.eventId,
    required this.reminderDelivery,
  });

  final String eventId;
  final ScheduleReminderDelivery reminderDelivery;
}

abstract interface class ScheduleEditorSource {
  Future<ScheduleEditorDefaults> loadScheduleEditorDefaults();

  Future<ScheduleSaveResult> saveScheduleEvent({
    required ScheduleEventModel event,
    required List<ReminderModel> reminders,
  });
}
