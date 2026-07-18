import 'schedule_models.dart';

class ScheduleDetailData {
  const ScheduleDetailData({required this.event, required this.reminders});

  final ScheduleEventModel event;
  final List<ReminderModel> reminders;
}

class ScheduleStatusChangeResult {
  const ScheduleStatusChangeResult({
    required this.eventId,
    required this.status,
    required this.remindersCancelled,
  });

  final String eventId;
  final ScheduleStatus status;
  final bool remindersCancelled;
}

abstract interface class ScheduleDetailSource {
  Future<ScheduleDetailData?> loadScheduleDetail(String eventId);

  Future<ScheduleStatusChangeResult> setScheduleStatus({
    required String eventId,
    required ScheduleStatus status,
  });
}

class ScheduleDetailException implements Exception {
  const ScheduleDetailException(this.message);

  final String message;

  @override
  String toString() => message;
}
