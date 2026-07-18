import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule/schedule_detail_models.dart';
import '../domain/schedule/schedule_models.dart';

typedef ScheduleEditCallback =
    Future<bool> Function(
      ScheduleEventModel event,
      List<ReminderModel> reminders,
    );

class ScheduleDetailPage extends StatefulWidget {
  const ScheduleDetailPage({
    super.key,
    required this.eventId,
    required this.source,
    required this.onEdit,
  });

  final String eventId;
  final ScheduleDetailSource source;
  final ScheduleEditCallback onEdit;

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  ScheduleDetailData? _data;
  var _loading = true;
  var _busy = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final data = await widget.source.loadScheduleDetail(widget.eventId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      _showMessage('日程详情加载失败，请重试');
    }
  }

  Future<void> _edit() async {
    final data = _data;
    if (_busy || data == null || data.event.status != ScheduleStatus.active) {
      return;
    }
    final changed = await widget.onEdit(data.event, data.reminders);
    if (changed && mounted) await _load();
  }

  Future<void> _complete() => _changeStatus(ScheduleStatus.completed);

  Future<void> _cancel() async {
    final event = _data?.event;
    if (_busy || event == null) return;
    final recurring = event.recurrence != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消这个日程？'),
        content: Text(
          recurring ? '此操作会取消整个重复日程，并移除已经安排的系统提醒。' : '取消后将移除已经安排的系统提醒。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          TextButton(
            key: const Key('schedule-detail-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _changeStatus(ScheduleStatus.cancelled);
    }
  }

  Future<void> _changeStatus(ScheduleStatus status) async {
    final event = _data?.event;
    if (_busy || event == null || event.status != ScheduleStatus.active) return;
    setState(() => _busy = true);
    try {
      final result = await widget.source.setScheduleStatus(
        eventId: event.id,
        status: status,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ScheduleDetailException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('日程状态更新失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leadingWidth: 66,
          leading: IconButton(
            key: const Key('schedule-detail-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '日程详情',
            key: Key('schedule-detail-title'),
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            TextButton(
              key: const Key('schedule-detail-edit'),
              onPressed: _busy || _data?.event.status != ScheduleStatus.active
                  ? null
                  : _edit,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                disabledForegroundColor: const Color(0xFFADB5C4),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('编辑'),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _divider),
          ),
        ),
        body: _loading
            ? const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            : _data == null
            ? _MissingSchedule(onRetry: _load)
            : _DetailBody(
                data: _data!,
                busy: _busy,
                onComplete: _complete,
                onCancel: _cancel,
              ),
      ),
    ),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.busy,
    required this.onComplete,
    required this.onCancel,
  });

  final ScheduleDetailData data;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final event = data.event;
    final startsAt = _wallTime(event.startsAtUtc, event.timezoneId);
    final endsAt = startsAt.add(event.duration);
    final active = event.status == ScheduleStatus.active;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('schedule-detail-scroll'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(25, 39, 25, 31),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 70),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  active
                      ? Icons.event_available_outlined
                      : Icons.event_busy_outlined,
                  color: active ? _blue : _muted,
                  size: 52,
                ),
                const SizedBox(height: 20),
                Text(
                  event.title,
                  key: const Key('schedule-detail-heading'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _summaryLabel(startsAt, endsAt, event.allDay),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                if (!active) ...[
                  const SizedBox(height: 12),
                  Center(child: _StatusPill(status: event.status)),
                ],
                const SizedBox(height: 39),
                const _SectionLabel('日程信息'),
                const SizedBox(height: 11),
                _DetailCard(
                  children: [
                    _DetailRow(
                      label: '开始',
                      value: _dateTimeLabel(startsAt, event.allDay),
                    ),
                    const _InnerDivider(),
                    _DetailRow(
                      label: '结束',
                      value: _dateTimeLabel(endsAt, event.allDay),
                    ),
                    const _InnerDivider(),
                    _DetailRow(
                      label: '时区',
                      value: _timezoneLabel(event.timezoneId),
                    ),
                    const _InnerDivider(),
                    _DetailRow(
                      label: '提醒',
                      value: _reminderLabel(data.reminders),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const _SectionLabel('重复'),
                const SizedBox(height: 11),
                _DetailCard(
                  children: [
                    _DetailRow(
                      label: '重复规则',
                      value: _recurrenceLabel(event.recurrence),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const _SectionLabel('备注'),
                const SizedBox(height: 11),
                Container(
                  key: const Key('schedule-detail-notes'),
                  constraints: const BoxConstraints(minHeight: 72),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.topLeft,
                  child: Text(
                    event.notes.trim().isEmpty ? '无备注' : event.notes.trim(),
                    style: TextStyle(
                      color: event.notes.trim().isEmpty ? _muted : _text,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                if (active) ...[
                  const SizedBox(height: 31),
                  SizedBox(
                    height: 51,
                    child: FilledButton(
                      key: const Key('schedule-detail-complete'),
                      onPressed: busy ? null : onComplete,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        disabledBackgroundColor: const Color(0xFFD6DCEB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('标记为完成'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const Key('schedule-detail-cancel'),
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: _danger,
                      disabledForegroundColor: const Color(0xFFCFB1B1),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('取消日程'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF646A73),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _cardBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 62,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _text, fontSize: 16)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InnerDivider extends StatelessWidget {
  const _InnerDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, thickness: 1, color: _divider),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFECEFF4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      status == ScheduleStatus.completed ? '已完成' : '已取消',
      style: const TextStyle(color: _muted, fontSize: 12.5),
    ),
  );
}

class _MissingSchedule extends StatelessWidget {
  const _MissingSchedule({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('日程不存在或已被删除', style: TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}

DateTime _wallTime(DateTime utc, String timezoneId) {
  try {
    final value = tz.TZDateTime.from(utc.toUtc(), tz.getLocation(timezoneId));
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  } on Object {
    return utc.toLocal();
  }
}

String _summaryLabel(DateTime start, DateTime end, bool allDay) {
  final weekday = _weekday(start.weekday);
  final date = '${start.month}月${start.day}日 周$weekday';
  if (allDay) return '$date 全天';
  return '$date ${_time(start)}–${_time(end)}';
}

String _dateTimeLabel(DateTime value, bool allDay) {
  final date = '${value.month}月${value.day}日 周${_weekday(value.weekday)}';
  return allDay ? date : '$date ${_time(value)}';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _weekday(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];

String _timezoneLabel(String timezoneId) => switch (timezoneId) {
  'Asia/Shanghai' || 'Asia/Chongqing' || 'Asia/Harbin' => '中国标准时间',
  'Asia/Hong_Kong' => '香港时间',
  'Asia/Taipei' => '台北时间',
  'Asia/Tokyo' => '日本标准时间',
  'UTC' || 'Etc/UTC' => '协调世界时',
  _ => timezoneId.replaceAll('_', ' '),
};

String _reminderLabel(List<ReminderModel> reminders) {
  if (reminders.isEmpty) return '不提醒';
  if (reminders.length > 1) return '${reminders.length} 个提醒';
  final minutes = reminders.single.offset.inMinutes;
  if (minutes == 0) return '日程开始时';
  if (minutes < 60) return '提前 $minutes 分钟';
  if (minutes % 1440 == 0) return '提前 ${minutes ~/ 1440} 天';
  return '提前 ${minutes ~/ 60} 小时';
}

String _recurrenceLabel(RecurrenceRule? rule) {
  if (rule == null) return '不重复';
  final interval = rule.interval;
  return switch (rule.frequency) {
    RecurrenceFrequency.daily => interval == 1 ? '每天' : '每 $interval 天',
    RecurrenceFrequency.weekly => interval == 1 ? '每周' : '每 $interval 周',
    RecurrenceFrequency.monthly => interval == 1 ? '每月' : '每 $interval 月',
  };
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _danger = Color(0xFFFF4D4F);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
