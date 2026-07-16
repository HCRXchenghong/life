import 'dart:async';

import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/schedule_repository.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ScheduleRepository repository;

  setUp(() {
    database = AppDatabase.inMemory();
    repository = ScheduleRepository(database);
  });

  tearDown(() => database.close());

  test('event and reminders round-trip transactionally', () async {
    final event = ScheduleEventModel(
      id: 'event-1',
      title: '看展览',
      startsAtUtc: DateTime.utc(2026, 7, 20, 2),
      duration: const Duration(hours: 2),
      timezoneId: 'Asia/Shanghai',
      source: ScheduleSource.ai,
    );
    const reminder = ReminderModel(
      id: 'reminder-1',
      eventId: 'event-1',
      offset: Duration(minutes: 30),
      exactRequested: true,
    );

    await repository.saveEvent(event, [reminder]);

    final events = await repository.activeEvents();
    final reminders = await repository.remindersForEvents(['event-1']);
    expect(events.single.title, '看展览');
    expect(events.single.source, ScheduleSource.ai);
    expect(reminders.single.offset, const Duration(minutes: 30));
    expect(reminders.single.exactRequested, isTrue);
  });

  test('completed event is excluded from active events', () async {
    final event = ScheduleEventModel(
      id: 'event-2',
      title: '晚餐',
      startsAtUtc: DateTime.utc(2026, 7, 20, 10),
      duration: const Duration(hours: 1),
      timezoneId: 'Asia/Shanghai',
    );
    await repository.saveEvent(event, const []);
    await repository.setStatus(event.id, ScheduleStatus.completed);

    expect(await repository.activeEvents(), isEmpty);
  });

  test('active event stream updates when status changes', () async {
    final event = ScheduleEventModel(
      id: 'event-live',
      title: '实时日程',
      startsAtUtc: DateTime.utc(2026, 7, 20, 10),
      duration: const Duration(hours: 1),
      timezoneId: 'Asia/Shanghai',
    );
    final emissions = StreamIterator(repository.watchActiveEvents());

    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current, isEmpty);

    await repository.saveEvent(event, const []);
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current.single.id, event.id);

    await repository.setStatus(event.id, ScheduleStatus.completed);
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current, isEmpty);

    await emissions.cancel();
  });
}
