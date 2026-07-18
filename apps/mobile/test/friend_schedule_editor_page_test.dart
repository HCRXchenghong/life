import 'package:daylink_mobile/src/application/friend_schedule_list.dart';
import 'package:daylink_mobile/src/domain/share/share_poll_models.dart';
import 'package:daylink_mobile/src/presentation/friend_schedule_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('renders the approved minimal create-poll layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleEditorPage(
          source: _FakeCreationSource(),
          clock: () => DateTime(2026, 7, 18, 9),
        ),
      ),
    );

    expect(find.text('新建选时间'), findsOneWidget);
    expect(find.text('创建'), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('活动名称'), findsOneWidget);
    expect(find.text('补充说明'), findsOneWidget);
    expect(find.text('可选时间范围'), findsOneWidget);
    expect(find.text('7月25日  周六'), findsOneWidget);
    expect(find.text('14:00 – 18:00'), findsOneWidget);
    expect(find.text('7月26日  周日'), findsOneWidget);
    expect(find.text('10:00 – 12:00'), findsOneWidget);
    expect(find.text('添加可选时间范围'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('截止时间'), findsOneWidget);
    expect(find.text('7月24日 22:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a validated account poll in the selected timezone', (
    tester,
  ) async {
    final source = _FakeCreationSource();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-editor'),
              onPressed: () => Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => FriendScheduleEditorPage(
                    source: source,
                    clock: () => DateTime(2026, 7, 18, 9),
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('friend-schedule-editor-name')),
      '周末出游',
    );
    await tester.enterText(
      find.byKey(const Key('friend-schedule-editor-description')),
      '一起找个大家都方便的时间',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-schedule-editor-create')));
    await tester.pumpAndSettle();

    final draft = source.created;
    expect(draft, isNotNull);
    expect(draft!.title, '周末出游');
    expect(draft.description, '一起找个大家都方便的时间');
    expect(draft.timezoneId, 'Asia/Shanghai');
    expect(draft.slots, hasLength(2));
    expect(draft.slots.first.startsAtUtc, DateTime.utc(2026, 7, 25, 6));
    expect(draft.slots.first.endsAtUtc, DateTime.utc(2026, 7, 25, 10));
    expect(draft.closesAtUtc, DateTime.utc(2026, 7, 24, 14));
    expect(find.byKey(const Key('open-editor')), findsOneWidget);
  });

  testWidgets('uses a compact popup and blocks an empty activity name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleEditorPage(
          source: _FakeCreationSource(),
          clock: () => DateTime(2026, 7, 18, 9),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('friend-schedule-editor-slot-0')));
    await tester.pumpAndSettle();
    expect(find.text('开始时间'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friend-schedule-editor-create')));
    await tester.pump();
    expect(find.text('请输入活动名称'), findsOneWidget);
  });

  testWidgets('blocks creation and lets the user edit a conflicting schedule', (
    tester,
  ) async {
    final source = _FakeCreationSource(
      conflicts: [
        FriendScheduleConflict(
          eventId: 'existing-event',
          eventTitle: '已经安排的聚餐',
          startsAtUtc: DateTime.utc(2026, 7, 25, 7),
          endsAtUtc: DateTime.utc(2026, 7, 25, 8),
        ),
      ],
    );
    String? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendScheduleEditorPage(
          source: source,
          clock: () => DateTime(2026, 7, 18, 9),
          onEditSchedule: (eventId) async {
            edited = eventId;
            return false;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('friend-schedule-editor-name')),
      '周末出游',
    );
    await tester.tap(find.byKey(const Key('friend-schedule-editor-create')));
    await tester.pumpAndSettle();

    expect(find.text('发现日程冲突'), findsOneWidget);
    expect(find.text('已经安排的聚餐'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('friend-schedule-conflict-existing-event')),
    );
    await tester.pumpAndSettle();
    expect(edited, 'existing-event');
    expect(source.created, isNull);
  });
}

class _FakeCreationSource implements FriendScheduleCreationSource {
  _FakeCreationSource({this.conflicts = const []});

  final List<FriendScheduleConflict> conflicts;
  CreateSharePollDraft? created;

  @override
  Future<String> loadFriendScheduleTimezoneId() async => 'Asia/Shanghai';

  @override
  Future<void> createFriendSchedule(CreateSharePollDraft draft) async {
    created = draft;
  }

  @override
  Future<List<FriendScheduleConflict>> findFriendScheduleConflicts(
    List<SharePollSlotDraft> ranges,
  ) async => conflicts;

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async => const [];
}
