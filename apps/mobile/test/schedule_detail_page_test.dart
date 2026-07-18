import 'package:daylink_mobile/src/domain/schedule/schedule_detail_models.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:daylink_mobile/src/presentation/schedule_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders the approved schedule detail from real source data', (
    tester,
  ) async {
    final source = _FakeDetailSource(_detail());

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleDetailPage(
          eventId: 'trip',
          source: source,
          onEdit: (_, _) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日程详情'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('周末出游'), findsOneWidget);
    expect(find.text('7月18日 周六 14:00–15:00'), findsOneWidget);
    expect(find.text('日程信息'), findsOneWidget);
    expect(find.text('7月18日 周六 14:00'), findsOneWidget);
    expect(find.text('中国标准时间'), findsOneWidget);
    expect(find.text('提前 10 分钟'), findsOneWidget);
    expect(find.text('不重复'), findsOneWidget);
    expect(find.text('记得带上相机和防晒霜'), findsOneWidget);
    expect(find.byKey(const Key('schedule-detail-complete')), findsOneWidget);
    expect(find.byKey(const Key('schedule-detail-cancel')), findsOneWidget);
  });

  testWidgets('editing reloads the persisted detail', (tester) async {
    final source = _FakeDetailSource(_detail());
    var editCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleDetailPage(
          eventId: 'trip',
          source: source,
          onEdit: (event, reminders) async {
            editCalls++;
            source.data = ScheduleDetailData(
              event: _event(title: '周末出游（已更新）'),
              reminders: reminders,
            );
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('schedule-detail-edit')));
    await tester.pumpAndSettle();

    expect(editCalls, 1);
    expect(source.loadCalls, 2);
    expect(find.text('周末出游（已更新）'), findsOneWidget);
  });

  testWidgets('marking complete returns the durable status result', (
    tester,
  ) async {
    final source = _FakeDetailSource(_detail());
    ScheduleStatusChangeResult? returned;
    await _pumpHarness(
      tester,
      source: source,
      onResult: (value) => returned = value,
    );

    await tester.ensureVisible(
      find.byKey(const Key('schedule-detail-complete')),
    );
    await tester.tap(find.byKey(const Key('schedule-detail-complete')));
    await tester.pumpAndSettle();

    expect(source.changedStatus, ScheduleStatus.completed);
    expect(returned?.eventId, 'trip');
    expect(returned?.remindersCancelled, isTrue);
  });

  testWidgets('cancelling requires confirmation and returns cancelled status', (
    tester,
  ) async {
    final source = _FakeDetailSource(_detail());
    ScheduleStatusChangeResult? returned;
    await _pumpHarness(
      tester,
      source: source,
      onResult: (value) => returned = value,
    );

    await tester.ensureVisible(find.byKey(const Key('schedule-detail-cancel')));
    await tester.tap(find.byKey(const Key('schedule-detail-cancel')));
    await tester.pumpAndSettle();
    expect(source.changedStatus, isNull);

    await tester.tap(find.byKey(const Key('schedule-detail-cancel-confirm')));
    await tester.pumpAndSettle();

    expect(source.changedStatus, ScheduleStatus.cancelled);
    expect(returned?.status, ScheduleStatus.cancelled);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required _FakeDetailSource source,
  required ValueChanged<ScheduleStatusChangeResult?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-detail'),
              onPressed: () async {
                final result = await Navigator.push<ScheduleStatusChangeResult>(
                  context,
                  MaterialPageRoute<ScheduleStatusChangeResult>(
                    builder: (_) => ScheduleDetailPage(
                      eventId: 'trip',
                      source: source,
                      onEdit: (_, _) async => false,
                    ),
                  ),
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-detail')));
  await tester.pumpAndSettle();
}

ScheduleDetailData _detail() => ScheduleDetailData(
  event: _event(),
  reminders: const [
    ReminderModel(
      id: 'trip-reminder',
      eventId: 'trip',
      offset: Duration(minutes: 10),
    ),
  ],
);

ScheduleEventModel _event({String title = '周末出游'}) => ScheduleEventModel(
  id: 'trip',
  title: title,
  notes: '记得带上相机和防晒霜',
  startsAtUtc: DateTime.utc(2026, 7, 18, 6),
  duration: const Duration(hours: 1),
  timezoneId: 'Asia/Shanghai',
);

class _FakeDetailSource implements ScheduleDetailSource {
  _FakeDetailSource(this.data);

  ScheduleDetailData? data;
  ScheduleStatus? changedStatus;
  var loadCalls = 0;

  @override
  Future<ScheduleDetailData?> loadScheduleDetail(String eventId) async {
    loadCalls++;
    return data?.event.id == eventId ? data : null;
  }

  @override
  Future<ScheduleStatusChangeResult> setScheduleStatus({
    required String eventId,
    required ScheduleStatus status,
  }) async {
    changedStatus = status;
    return ScheduleStatusChangeResult(
      eventId: eventId,
      status: status,
      remindersCancelled: true,
    );
  }
}
