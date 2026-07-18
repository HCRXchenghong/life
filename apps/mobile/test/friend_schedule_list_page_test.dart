import 'package:daylink_mobile/src/application/friend_schedule_list.dart';
import 'package:daylink_mobile/src/domain/share/share_poll_models.dart';
import 'package:daylink_mobile/src/presentation/friend_schedule_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders approved active and ended poll groups', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var createCalls = 0;
    ManagedSharePollSummary? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleListPage(
          source: _FakeFriendSchedules([
            _poll(id: 'trip', title: '周末出游', candidates: 3, participants: 6),
            _poll(id: 'dinner', title: '项目聚餐', candidates: 2, participants: 4),
            _poll(
              id: 'birthday',
              title: '生日聚会',
              status: SharePollStatus.closed,
              candidates: 3,
              participants: 6,
              selectedSlot: SharePollSlot(
                id: 'selected',
                startsAtUtc: DateTime.utc(2026, 7, 26, 10, 30),
                endsAtUtc: DateTime.utc(2026, 7, 26, 12, 30),
              ),
            ),
          ]),
          onCreate: () async {
            createCalls++;
            return false;
          },
          onOpenPoll: (poll) async {
            opened = poll;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('好友选时间'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('周末出游'), findsOneWidget);
    expect(find.text('3 个候选时间 · 6 人参与'), findsOneWidget);
    expect(find.text('项目聚餐'), findsOneWidget);
    expect(find.text('2 个候选时间 · 4 人参与'), findsOneWidget);
    expect(find.text('生日聚会'), findsOneWidget);
    expect(find.text('已确定 · 7月26日 18:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friend-schedule-new')));
    await tester.tap(find.byKey(const Key('friend-schedule-poll-trip')));
    expect(createCalls, 1);
    expect(opened?.id, 'trip');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers retry after a safe loading error', (tester) async {
    final source = _RetryingFriendSchedules();
    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleListPage(
          source: source,
          onCreate: () async => false,
          onOpenPoll: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络异常'), findsOneWidget);
    await tester.tap(find.byKey(const Key('friend-schedule-retry')));
    await tester.pumpAndSettle();

    expect(source.calls, 2);
    expect(find.byKey(const Key('friend-schedule-empty')), findsOneWidget);
    expect(find.text('还没有选时间'), findsOneWidget);
  });
}

ManagedSharePollSummary _poll({
  required String id,
  required String title,
  required int candidates,
  required int participants,
  SharePollStatus status = SharePollStatus.open,
  SharePollSlot? selectedSlot,
}) => ManagedSharePollSummary(
  id: id,
  title: title,
  timezoneId: 'Asia/Shanghai',
  status: status,
  version: 1,
  candidateCount: candidates,
  participantCount: participants,
  createdAtUtc: DateTime.utc(2026, 7, 18),
  updatedAtUtc: DateTime.utc(2026, 7, 18),
  selectedSlot: selectedSlot,
);

class _FakeFriendSchedules implements FriendScheduleListSource {
  const _FakeFriendSchedules(this.polls);

  final List<ManagedSharePollSummary> polls;

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async => polls;
}

class _RetryingFriendSchedules implements FriendScheduleListSource {
  var calls = 0;

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async {
    calls++;
    if (calls == 1) {
      throw const FriendScheduleListException('网络异常');
    }
    return const [];
  }
}
