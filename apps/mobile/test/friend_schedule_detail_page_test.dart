import 'package:daylink_mobile/src/application/friend_schedule_list.dart';
import 'package:daylink_mobile/src/domain/share/share_poll_models.dart';
import 'package:daylink_mobile/src/presentation/friend_schedule_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders the approved friend-specific invitation detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _FakeDetailsSource();

    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleDetailPage(pollId: 'trip', source: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('周末出游'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('一起找个大家都方便的时间'), findsOneWidget);
    expect(find.text('专属邀请'), findsOneWidget);
    expect(find.text('每位朋友一个独立链接'), findsOneWidget);
    expect(find.text('2/50'), findsOneWidget);
    expect(find.text('小明'), findsOneWidget);
    expect(find.text('待选择'), findsOneWidget);
    expect(find.text('小雨'), findsOneWidget);
    expect(find.text('已提交 · 2段时间'), findsOneWidget);
    expect(find.text('共同可行时间'), findsOneWidget);
    expect(find.text('按参与人数排序'), findsOneWidget);
    expect(find.text('最佳'), findsOneWidget);
    expect(find.text('5 人可以'), findsOneWidget);
    expect(find.text('确定这个时间'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a named invite and confirms the selected suggestion', (
    tester,
  ) async {
    final source = _FakeDetailsSource();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open-details'),
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) =>
                    FriendScheduleDetailPage(pollId: 'trip', source: source),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-details')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friend-schedule-invite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-invite-name')), '小林');
    await tester.tap(find.byKey(const Key('friend-invite-create')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(source.createdName, '小林');
    expect(find.text('3/50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friend-schedule-confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('friend-schedule-confirm-dialog')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(source.confirmCalls, 1);
    expect(find.byKey(const Key('open-details')), findsOneWidget);
  });
}

class _FakeDetailsSource implements FriendScheduleDetailSource {
  _FakeDetailsSource() : details = _details();

  FriendPollDetails details;
  String? createdName;
  var confirmCalls = 0;

  @override
  Future<FriendPollDetails> loadFriendScheduleDetails(String pollId) async =>
      details;

  @override
  Future<FriendPollInvite> createFriendInvite({
    required String pollId,
    required String displayName,
  }) async {
    createdName = displayName;
    final invite = _invite('lin', displayName, FriendInviteStatus.pending);
    details = FriendPollDetails(
      id: details.id,
      title: details.title,
      description: details.description,
      timezoneId: details.timezoneId,
      status: details.status,
      version: details.version + 1,
      ranges: details.ranges,
      invites: [...details.invites, invite],
      suggestions: details.suggestions,
      createdAtUtc: details.createdAtUtc,
      updatedAtUtc: details.updatedAtUtc,
      closesAtUtc: details.closesAtUtc,
    );
    return invite;
  }

  @override
  Future<void> confirmFriendSchedule({
    required FriendPollDetails details,
    required FriendTimeSuggestion suggestion,
  }) async {
    confirmCalls++;
  }

  @override
  Future<void> revokeFriendInvite({
    required String pollId,
    required String inviteId,
  }) async {}

  @override
  Future<void> createFriendSchedule(CreateSharePollDraft draft) async {}

  @override
  Future<List<FriendScheduleConflict>> findFriendScheduleConflicts(
    List<SharePollSlotDraft> ranges,
  ) async => const [];

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async => const [];

  @override
  Future<String> loadFriendScheduleTimezoneId() async => 'Asia/Shanghai';
}

FriendPollDetails _details() {
  final firstStart = DateTime.utc(2026, 7, 25, 6);
  final secondStart = DateTime.utc(2026, 7, 26, 2);
  return FriendPollDetails(
    id: 'trip',
    title: '周末出游',
    description: '一起找个大家都方便的时间',
    timezoneId: 'Asia/Shanghai',
    status: SharePollStatus.open,
    version: 3,
    ranges: [
      SharePollSlot(
        id: 'range-1',
        startsAtUtc: firstStart,
        endsAtUtc: firstStart.add(const Duration(hours: 4)),
      ),
      SharePollSlot(
        id: 'range-2',
        startsAtUtc: secondStart,
        endsAtUtc: secondStart.add(const Duration(hours: 2)),
      ),
    ],
    invites: [
      _invite('ming', '小明', FriendInviteStatus.pending),
      _invite(
        'yu',
        '小雨',
        FriendInviteStatus.submitted,
        selections: [
          FriendTimeSelection(
            startsAtUtc: firstStart,
            endsAtUtc: firstStart.add(const Duration(hours: 1)),
          ),
          FriendTimeSelection(
            startsAtUtc: secondStart,
            endsAtUtc: secondStart.add(const Duration(hours: 1)),
          ),
        ],
      ),
    ],
    suggestions: [
      FriendTimeSuggestion(
        startsAtUtc: firstStart,
        endsAtUtc: firstStart.add(const Duration(hours: 1)),
        peopleCount: 5,
      ),
      FriendTimeSuggestion(
        startsAtUtc: secondStart,
        endsAtUtc: secondStart.add(const Duration(hours: 1)),
        peopleCount: 4,
      ),
    ],
    closesAtUtc: DateTime.utc(2026, 7, 24, 14),
    createdAtUtc: DateTime.utc(2026, 7, 18),
    updatedAtUtc: DateTime.utc(2026, 7, 18),
  );
}

FriendPollInvite _invite(
  String id,
  String name,
  FriendInviteStatus status, {
  List<FriendTimeSelection> selections = const [],
}) => FriendPollInvite(
  id: id,
  displayName: name,
  inviteUrl: Uri.parse('https://daylink.example/select/token-$id'),
  status: status,
  selections: selections,
  submittedAtUtc: status == FriendInviteStatus.submitted
      ? DateTime.utc(2026, 7, 18, 2)
      : null,
  createdAtUtc: DateTime.utc(2026, 7, 18),
  updatedAtUtc: DateTime.utc(2026, 7, 18),
);
