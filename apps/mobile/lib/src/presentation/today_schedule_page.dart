import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/schedule_repository.dart';
import '../domain/schedule/recurrence_engine.dart';
import '../domain/schedule/schedule_models.dart';
import 'app_navigation.dart';

class TodaySchedulePage extends StatefulWidget {
  const TodaySchedulePage({
    super.key,
    required this.source,
    required this.onCreateEvent,
    required this.onOpenAssistant,
    required this.onDestinationSelected,
    this.clock = DateTime.now,
    this.recurrenceEngine = const RecurrenceEngine(),
  });

  final ScheduleEventSource source;
  final VoidCallback onCreateEvent;
  final VoidCallback onOpenAssistant;
  final ValueChanged<AppDestination> onDestinationSelected;
  final DateTime Function() clock;
  final RecurrenceEngine recurrenceEngine;

  @override
  State<TodaySchedulePage> createState() => _TodaySchedulePageState();
}

class _TodaySchedulePageState extends State<TodaySchedulePage> {
  StreamSubscription<List<ScheduleEventModel>>? _eventsSubscription;
  Timer? _clockTimer;
  List<ScheduleEventModel> _events = const [];
  Map<String, List<ReminderModel>> _remindersByEvent = const {};
  var _loading = true;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
    _scheduleClockRefresh();
  }

  @override
  void didUpdateWidget(covariant TodaySchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) _listenToEvents();
  }

  void _listenToEvents() {
    unawaited(_eventsSubscription?.cancel());
    final generation = ++_loadGeneration;
    _eventsSubscription = widget.source.watchActiveEvents().listen(
      (events) async {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _events = events;
          _loading = false;
        });
        try {
          final reminders = await widget.source.remindersForEvents(
            events.map((event) => event.id),
          );
          if (!mounted || generation != _loadGeneration) return;
          final grouped = <String, List<ReminderModel>>{};
          for (final reminder in reminders) {
            grouped.putIfAbsent(reminder.eventId, () => []).add(reminder);
          }
          setState(() => _remindersByEvent = grouped);
        } on Object {
          // The event list remains usable if reminder metadata is temporarily
          // unavailable. The next database emission retries the join.
        }
      },
      onError: (_) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _loading = false);
      },
    );
  }

  void _scheduleClockRefresh() {
    _clockTimer?.cancel();
    final now = widget.clock();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _clockTimer = Timer(nextMinute.difference(now), () {
      if (mounted) setState(() {});
      _scheduleClockRefresh();
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    unawaited(_eventsSubscription?.cancel());
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final occurrences = _todayOccurrences(now);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 27, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(now: now, onCreate: widget.onCreateEvent),
                      const SizedBox(height: 25),
                      _AssistantEntry(onTap: widget.onOpenAssistant),
                      const SizedBox(height: 39),
                      _SectionHeader(count: occurrences.length),
                      const SizedBox(height: 15),
                      Expanded(
                        child: _loading
                            ? const SizedBox.shrink()
                            : occurrences.isEmpty
                            ? const _EmptySchedule()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _Timeline(items: occurrences),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DaylinkBottomNavigation(
              currentDestination: AppDestination.schedule,
              onSelected: widget.onDestinationSelected,
            ),
          ],
        ),
      ),
    );
  }

  List<_TodayOccurrence> _todayOccurrences(DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day + 1);
    final result = <_TodayOccurrence>[];
    for (final event in _events) {
      final occurrences = widget.recurrenceEngine.between(
        event,
        fromUtc: dayStart.toUtc(),
        toUtc: dayEnd.toUtc(),
        limit: 100,
      );
      for (final occurrence in occurrences) {
        result.add(
          _TodayOccurrence(
            event: event,
            occurrence: occurrence,
            reminders: _remindersByEvent[event.id] ?? const [],
          ),
        );
      }
    }
    result.sort(
      (left, right) =>
          left.occurrence.startsAtUtc.compareTo(right.occurrence.startsAtUtc),
    );
    return result;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.onCreate});

  final DateTime now;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text(
        '今天',
        style: TextStyle(
          color: Color(0xFF1F2329),
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(width: 17),
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Text(
          '${now.month}月${now.day}日  星期${_weekday(now.weekday)}',
          style: const TextStyle(
            color: Color(0xFF8F959E),
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      const Spacer(),
      Semantics(
        button: true,
        label: '新建日程',
        child: Material(
          color: const Color(0xFF3370FF),
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('today-create'),
            customBorder: const CircleBorder(),
            onTap: onCreate,
            child: const SizedBox.square(
              dimension: 39,
              child: Icon(Icons.add_rounded, size: 25, color: Colors.white),
            ),
          ),
        ),
      ),
    ],
  );

  static String _weekday(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
}

class _AssistantEntry extends StatelessWidget {
  const _AssistantEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const Key('today-ai-entry'),
      onTap: onTap,
      child: const SizedBox(
        height: 58,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 17),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF3370FF), size: 20),
              SizedBox(width: 13),
              Expanded(
                child: Text(
                  '告诉 Daylink 你的安排…',
                  style: TextStyle(
                    color: Color(0xFF8F959E),
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(Icons.send_rounded, color: Color(0xFF3370FF), size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text(
        '今日日程',
        style: TextStyle(
          color: Color(0xFF1F2329),
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Text(
        '$count 项',
        key: const Key('today-count'),
        style: const TextStyle(
          color: Color(0xFF8F959E),
          fontSize: 14,
          height: 1.3,
        ),
      ),
    ],
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});

  final List<_TodayOccurrence> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++)
        _TimelineRow(item: items[index], isLast: index == items.length - 1),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.isLast});

  final _TodayOccurrence item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final localStart = item.occurrence.startsAtUtc.toLocal();
    return SizedBox(
      key: Key('today-event-${item.event.id}'),
      height: 107,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 21,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _sourceColor(item.event.source),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFFE5E7EB)),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                item.event.allDay ? '全天' : _formatTime(localStart),
                style: const TextStyle(
                  color: Color(0xFF1F2329),
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 0),
              decoration: isLast
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEDEFF2)),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8F959E),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _sourceColor(ScheduleSource source) => switch (source) {
    ScheduleSource.manual => const Color(0xFF3370FF),
    ScheduleSource.ai => const Color(0xFF7C5CFC),
    ScheduleSource.sharePoll => const Color(0xFFFF8B5C),
    ScheduleSource.system => const Color(0xFF8F959E),
  };
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 190,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '今天没有日程',
            style: TextStyle(
              color: Color(0xFF646A73),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '轻松安排今天吧',
            style: TextStyle(color: Color(0xFFA8ABB2), fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class _TodayOccurrence {
  const _TodayOccurrence({
    required this.event,
    required this.occurrence,
    required this.reminders,
  });

  final ScheduleEventModel event;
  final ScheduleOccurrence occurrence;
  final List<ReminderModel> reminders;

  String get subtitle {
    final note = event.notes.replaceAll(RegExp(r'\s+'), ' ').trim();
    final reminder = reminders.isEmpty
        ? null
        : _formatReminder(
            reminders
                .map((item) => item.offset)
                .reduce((left, right) => left < right ? left : right),
          );
    final detail =
        reminder ??
        (event.allDay
            ? null
            : '${_formatTime(occurrence.endsAtUtc.toLocal())} 结束');
    if (note.isEmpty) return detail ?? '全天日程';
    if (detail == null) return note;
    return '$note · $detail';
  }

  static String _formatReminder(Duration offset) {
    final minutes = offset.inMinutes.abs();
    if (minutes == 0) return '开始时提醒';
    if (minutes % (24 * 60) == 0) {
      return '提前 ${minutes ~/ (24 * 60)} 天提醒';
    }
    if (minutes % 60 == 0) return '提前 ${minutes ~/ 60} 小时提醒';
    return '提前 $minutes 分钟提醒';
  }
}

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
