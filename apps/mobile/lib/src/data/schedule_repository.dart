import 'package:drift/drift.dart';

import '../domain/schedule/schedule_models.dart';
import 'app_database.dart';

abstract interface class ScheduleEventSource {
  Stream<List<ScheduleEventModel>> watchActiveEvents();
  Future<List<ReminderModel>> remindersForEvents(Iterable<String> eventIds);
}

class ScheduleRepository implements ScheduleEventSource {
  ScheduleRepository(this._db);

  final AppDatabase _db;

  Future<void> saveEvent(
    ScheduleEventModel event,
    List<ReminderModel> reminders,
  ) async {
    await _db.transaction(() async {
      await _db
          .into(_db.scheduleEvents)
          .insertOnConflictUpdate(
            ScheduleEventsCompanion.insert(
              id: event.id,
              title: event.title,
              notes: Value(event.notes),
              startsAtUtc: event.startsAtUtc.toUtc(),
              durationMinutes: event.duration.inMinutes,
              timezoneId: event.timezoneId,
              allDay: Value(event.allDay),
              recurrenceJson: Value(event.recurrence?.encode()),
              status: Value(event.status.name),
              source: Value(event.source.name),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      await (_db.delete(
        _db.scheduleReminders,
      )..where((table) => table.eventId.equals(event.id))).go();
      if (reminders.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.scheduleReminders,
            reminders
                .map(
                  (reminder) => ScheduleRemindersCompanion.insert(
                    id: reminder.id,
                    eventId: reminder.eventId,
                    offsetMinutes: reminder.offset.inMinutes,
                    enabled: Value(reminder.enabled),
                    exactRequested: Value(reminder.exactRequested),
                  ),
                )
                .toList(),
          );
        });
      }
    });
  }

  Future<List<ScheduleEventModel>> activeEvents() async {
    final rows = await (_db.select(
      _db.scheduleEvents,
    )..where((table) => table.status.equals(ScheduleStatus.active.name))).get();
    return rows.map(_eventFromRow).toList(growable: false);
  }

  @override
  Stream<List<ScheduleEventModel>> watchActiveEvents() =>
      (_db.select(_db.scheduleEvents)
            ..where((table) => table.status.equals(ScheduleStatus.active.name)))
          .watch()
          .map((rows) => rows.map(_eventFromRow).toList(growable: false));

  @override
  Future<List<ReminderModel>> remindersForEvents(
    Iterable<String> eventIds,
  ) async {
    final ids = eventIds.toList(growable: false);
    if (ids.isEmpty) return const [];
    final rows =
        await (_db.select(_db.scheduleReminders)..where(
              (table) => table.eventId.isIn(ids) & table.enabled.equals(true),
            ))
            .get();
    return rows
        .map(
          (row) => ReminderModel(
            id: row.id,
            eventId: row.eventId,
            offset: Duration(minutes: row.offsetMinutes),
            enabled: row.enabled,
            exactRequested: row.exactRequested,
          ),
        )
        .toList(growable: false);
  }

  Future<void> setStatus(String eventId, ScheduleStatus status) async {
    await (_db.update(
      _db.scheduleEvents,
    )..where((table) => table.id.equals(eventId))).write(
      ScheduleEventsCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<ScheduleEventModel?> eventById(String eventId) async {
    final row = await (_db.select(
      _db.scheduleEvents,
    )..where((table) => table.id.equals(eventId))).getSingleOrNull();
    return row == null ? null : _eventFromRow(row);
  }

  Future<List<NotificationMapping>> notificationMappingsForEvent(
    String eventId,
  ) => (_db.select(
    _db.notificationMappings,
  )..where((table) => table.eventId.equals(eventId))).get();

  Future<List<NotificationMapping>> scheduledNotificationMappings() =>
      (_db.select(_db.notificationMappings)..where(
            (table) =>
                table.capability.equals(ReminderCapability.snoozed.name).not(),
          ))
          .get();

  Future<void> deleteNotificationMapping(int notificationId) => (_db.delete(
    _db.notificationMappings,
  )..where((table) => table.notificationId.equals(notificationId))).go();

  Future<void> upsertNotificationMapping(NotificationMappingDraft mapping) =>
      _db
          .into(_db.notificationMappings)
          .insertOnConflictUpdate(
            NotificationMappingsCompanion.insert(
              notificationId: Value(mapping.notificationId),
              reminderId: mapping.reminderId,
              eventId: mapping.eventId,
              occurrenceStartsAtUtc: mapping.occurrenceStartsAtUtc,
              scheduledForUtc: mapping.scheduledForUtc,
              capability: mapping.capability.name,
            ),
          );

  Future<void> replaceNotificationMappings(
    List<NotificationMappingDraft> mappings,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.notificationMappings)..where(
            (table) =>
                table.capability.equals(ReminderCapability.snoozed.name).not(),
          ))
          .go();
      if (mappings.isEmpty) return;
      await _db.batch((batch) {
        batch.insertAll(
          _db.notificationMappings,
          mappings
              .map(
                (mapping) => NotificationMappingsCompanion.insert(
                  notificationId: Value(mapping.notificationId),
                  reminderId: mapping.reminderId,
                  eventId: mapping.eventId,
                  occurrenceStartsAtUtc: mapping.occurrenceStartsAtUtc,
                  scheduledForUtc: mapping.scheduledForUtc,
                  capability: mapping.capability.name,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<NotificationMapping?> notificationMapping(int notificationId) =>
      (_db.select(_db.notificationMappings)
            ..where((table) => table.notificationId.equals(notificationId)))
          .getSingleOrNull();

  ScheduleEventModel _eventFromRow(ScheduleEvent row) => ScheduleEventModel(
    id: row.id,
    title: row.title,
    notes: row.notes,
    startsAtUtc: row.startsAtUtc.toUtc(),
    duration: Duration(minutes: row.durationMinutes),
    timezoneId: row.timezoneId,
    allDay: row.allDay,
    recurrence: row.recurrenceJson == null
        ? null
        : RecurrenceRule.decode(row.recurrenceJson!),
    status: ScheduleStatus.values.byName(row.status),
    source: ScheduleSource.values.byName(row.source),
  );
}

class NotificationMappingDraft {
  const NotificationMappingDraft({
    required this.notificationId,
    required this.reminderId,
    required this.eventId,
    required this.occurrenceStartsAtUtc,
    required this.scheduledForUtc,
    required this.capability,
  });

  final int notificationId;
  final String reminderId;
  final String eventId;
  final DateTime occurrenceStartsAtUtc;
  final DateTime scheduledForUtc;
  final ReminderCapability capability;
}
