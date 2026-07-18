import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../application/friend_schedule_list.dart';
import '../domain/share/share_poll_models.dart';

class FriendScheduleListPage extends StatefulWidget {
  const FriendScheduleListPage({
    super.key,
    required this.source,
    required this.onCreate,
    required this.onOpenPoll,
  });

  final FriendScheduleListSource source;
  final Future<bool> Function() onCreate;
  final ValueChanged<ManagedSharePollSummary> onOpenPoll;

  @override
  State<FriendScheduleListPage> createState() => _FriendScheduleListPageState();
}

class _FriendScheduleListPageState extends State<FriendScheduleListPage> {
  List<ManagedSharePollSummary>? _polls;
  String? _error;
  int _loadGeneration = 0;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final polls = await widget.source.loadFriendSchedules();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _polls = polls;
        _error = null;
      });
    } on FriendScheduleListException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error.message);
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = '暂时无法加载，请稍后重试');
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    _creating = true;
    try {
      if (await widget.onCreate()) await _load();
    } finally {
      _creating = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        foregroundColor: const Color(0xFF1F2329),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 58,
        leadingWidth: 64,
        leading: IconButton(
          key: const Key('friend-schedule-back'),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '返回',
        ),
        title: const Text(
          '好友选时间',
          key: Key('friend-schedule-title'),
          style: TextStyle(
            fontSize: 17,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('friend-schedule-new'),
            onPressed: () => unawaited(_create()),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3370FF),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('新建'),
          ),
        ],
      ),
      body: _body(),
    ),
  );

  Widget _body() {
    if (_polls == null && _error == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_polls == null) {
      return _RefreshableMessage(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: '重试',
        actionKey: const Key('friend-schedule-retry'),
        onRefresh: _load,
        onAction: _load,
      );
    }
    final polls = _polls!;
    if (polls.isEmpty) {
      return _RefreshableMessage(
        key: const Key('friend-schedule-empty'),
        icon: Icons.calendar_month_outlined,
        message: '还没有选时间',
        actionLabel: '新建一个',
        actionKey: const Key('friend-schedule-empty-new'),
        onRefresh: _load,
        onAction: () => unawaited(_create()),
      );
    }

    final now = DateTime.now().toUtc();
    final active = polls
        .where((poll) => _isActive(poll, now))
        .toList(growable: false);
    final ended = polls
        .where((poll) => !_isActive(poll, now))
        .toList(growable: false);
    return RefreshIndicator(
      key: const Key('friend-schedule-refresh'),
      color: const Color(0xFF3370FF),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 19, 20, 36),
        children: [
          if (active.isNotEmpty) ...[
            _PollSection(
              title: '进行中',
              sectionKey: const Key('friend-schedule-active-section'),
              polls: active,
              onOpenPoll: widget.onOpenPoll,
            ),
            if (ended.isNotEmpty) const SizedBox(height: 29),
          ],
          if (ended.isNotEmpty)
            _PollSection(
              title: '已结束',
              sectionKey: const Key('friend-schedule-ended-section'),
              polls: ended,
              onOpenPoll: widget.onOpenPoll,
            ),
        ],
      ),
    );
  }
}

class _PollSection extends StatelessWidget {
  const _PollSection({
    required this.title,
    required this.sectionKey,
    required this.polls,
    required this.onOpenPoll,
  });

  final String title;
  final Key sectionKey;
  final List<ManagedSharePollSummary> polls;
  final ValueChanged<ManagedSharePollSummary> onOpenPoll;

  @override
  Widget build(BuildContext context) => Column(
    key: sectionKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 11),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF646A73),
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < polls.length; index++) ...[
              _PollRow(
                poll: polls[index],
                onTap: () => onOpenPoll(polls[index]),
              ),
              if (index < polls.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 17,
                  endIndent: 17,
                  color: Color(0xFFF0F1F2),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _PollRow extends StatelessWidget {
  const _PollRow({required this.poll, required this.onTap});

  final ManagedSharePollSummary poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('friend-schedule-poll-${poll.id}'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poll.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2329),
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _subtitle(poll),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8F959E),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15,
            color: Color(0xFFC4C7CC),
          ),
        ],
      ),
    ),
  );
}

class _RefreshableMessage extends StatelessWidget {
  const _RefreshableMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.actionKey,
    required this.onRefresh,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Key actionKey;
  final Future<void> Function() onRefresh;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: const Color(0xFF3370FF),
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 170,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 37, color: const Color(0xFFB7BBC2)),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF8F959E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String _subtitle(ManagedSharePollSummary poll) {
  if (_isActive(poll, DateTime.now().toUtc())) {
    return '${poll.candidateCount} 个候选时间 · ${poll.participantCount} 人参与';
  }
  if (poll.status == SharePollStatus.cancelled) return '已取消';
  final selected = poll.selectedSlot;
  if (poll.status == SharePollStatus.closed && selected != null) {
    return '已确定 · ${_formatSlotStart(selected.startsAtUtc, poll.timezoneId)}';
  }
  return '已结束';
}

bool _isActive(ManagedSharePollSummary poll, DateTime nowUtc) =>
    poll.status == SharePollStatus.open &&
    (poll.closesAtUtc == null || poll.closesAtUtc!.isAfter(nowUtc));

String _formatSlotStart(DateTime startsAtUtc, String timezoneId) {
  DateTime value;
  try {
    value = tz.TZDateTime.from(startsAtUtc.toUtc(), tz.getLocation(timezoneId));
  } on Object {
    value = startsAtUtc.toLocal();
  }
  return '${value.month}月${value.day}日 ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
