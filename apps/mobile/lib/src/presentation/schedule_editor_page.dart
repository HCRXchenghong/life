import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../domain/schedule/schedule_editor_models.dart';
import '../domain/schedule/schedule_models.dart';

typedef ScheduleIdFactory = String Function();

class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({
    super.key,
    required this.source,
    required this.onOpenAssistant,
    this.initialEvent,
    this.initialReminders = const [],
    this.clock = DateTime.now,
    this.idFactory = _newId,
  });

  final ScheduleEditorSource source;
  final VoidCallback onOpenAssistant;
  final ScheduleEventModel? initialEvent;
  final List<ReminderModel> initialReminders;
  final DateTime Function() clock;
  final ScheduleIdFactory idFactory;

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _allDay;
  RecurrenceFrequency? _recurrenceFrequency;
  int? _reminderLeadMinutes;
  var _reminderTouched = false;
  var _timezoneId = 'UTC';
  var _loadingDefaults = true;
  var _defaultsReady = false;
  var _busy = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _titleController = TextEditingController(text: event?.title ?? '');
    _notesController = TextEditingController(text: event?.notes ?? '');
    _allDay = event?.allDay ?? false;
    _timezoneId = event?.timezoneId ?? 'UTC';
    if (event == null) {
      _startsAt = _nextWholeHour(widget.clock());
      _endsAt = _startsAt.add(const Duration(hours: 1));
    } else {
      _startsAt = _wallTime(event.startsAtUtc, event.timezoneId);
      _endsAt = _startsAt.add(event.duration);
    }
    _recurrenceFrequency = event?.recurrence?.frequency;
    if (widget.initialReminders.isNotEmpty) {
      _reminderLeadMinutes = widget.initialReminders.first.offset.inMinutes;
    }
    unawaited(_loadDefaults());
  }

  Future<void> _loadDefaults() async {
    final generation = ++_generation;
    if (mounted) setState(() => _loadingDefaults = true);
    try {
      final defaults = await widget.source.loadScheduleEditorDefaults();
      if (!mounted || generation != _generation) return;
      setState(() {
        if (widget.initialEvent == null) {
          _timezoneId = defaults.timezoneId;
          if (!_reminderTouched) {
            _reminderLeadMinutes = defaults.defaultReminderLeadMinutes;
          }
        }
        _defaultsReady = true;
        _loadingDefaults = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _defaultsReady = false;
        _loadingDefaults = false;
      });
      _showMessage('时区与提醒设置加载失败，请重试');
    }
  }

  Future<void> _save() async {
    if (_busy || _loadingDefaults) return;
    if (!_defaultsReady) {
      await _loadDefaults();
      return;
    }
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('请输入日程标题');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      _showMessage('结束时间必须晚于开始时间');
      return;
    }

    late DateTime startsAtUtc;
    try {
      startsAtUtc = _toUtc(_startsAt, _timezoneId);
    } on Object {
      _showMessage('当前时区不可用，请重试');
      return;
    }
    final duration = _endsAt.difference(_startsAt);
    final eventId = widget.initialEvent?.id ?? widget.idFactory();
    final reminders = _buildReminders(eventId);
    if (widget.initialEvent == null && reminders.isNotEmpty) {
      final earliestReminder = reminders
          .map((reminder) => startsAtUtc.subtract(reminder.offset))
          .reduce((left, right) => left.isBefore(right) ? left : right);
      if (!earliestReminder.isAfter(widget.clock().toUtc())) {
        _showMessage('提醒时间必须晚于当前时间');
        return;
      }
    }

    final event = ScheduleEventModel(
      id: eventId,
      title: title,
      notes: _notesController.text.trim(),
      startsAtUtc: startsAtUtc,
      duration: duration,
      timezoneId: _timezoneId,
      allDay: _allDay,
      recurrence: _recurrenceRule(),
      status: widget.initialEvent?.status ?? ScheduleStatus.active,
      source: widget.initialEvent?.source ?? ScheduleSource.manual,
    );

    setState(() => _busy = true);
    try {
      final result = await widget.source.saveScheduleEvent(
        event: event,
        reminders: reminders,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ArgumentError {
      if (mounted) _showMessage('日程内容不符合要求，请检查后重试');
    } on Object {
      if (mounted) _showMessage('日程保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<ReminderModel> _buildReminders(String eventId) {
    if (widget.initialEvent != null &&
        !_reminderTouched &&
        widget.initialReminders.isNotEmpty) {
      return widget.initialReminders
          .map(
            (reminder) => ReminderModel(
              id: reminder.id,
              eventId: eventId,
              offset: reminder.offset,
              enabled: reminder.enabled,
              exactRequested: reminder.exactRequested,
            ),
          )
          .toList(growable: false);
    }
    final leadMinutes = _reminderLeadMinutes;
    if (leadMinutes == null) return const [];
    return [
      ReminderModel(
        id: widget.idFactory(),
        eventId: eventId,
        offset: Duration(minutes: leadMinutes),
        exactRequested: leadMinutes <= 60,
      ),
    ];
  }

  RecurrenceRule? _recurrenceRule() => switch (_recurrenceFrequency) {
    null => null,
    RecurrenceFrequency.daily => const RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
    ),
    RecurrenceFrequency.weekly => RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      weekdays: {_startsAt.weekday},
    ),
    RecurrenceFrequency.monthly => const RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
    ),
  };

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startsAt);
    if (picked == null || !mounted) return;
    final duration = _endsAt.difference(_startsAt);
    setState(() {
      _startsAt = picked;
      _endsAt = picked.add(
        duration < const Duration(minutes: 1)
            ? const Duration(hours: 1)
            : duration,
      );
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endsAt);
    if (picked == null || !mounted) return;
    if (!picked.isAfter(_startsAt)) {
      _showMessage('结束时间必须晚于开始时间');
      return;
    }
    setState(() => _endsAt = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return null;
    if (_allDay) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _setAllDay(bool value) {
    if (_busy || value == _allDay) return;
    setState(() {
      _allDay = value;
      if (value) {
        _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day);
        _endsAt = DateTime(_endsAt.year, _endsAt.month, _endsAt.day);
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(days: 1));
        }
      } else {
        _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day, 9);
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _chooseReminder() async {
    final selection = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _ReminderPicker(),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _reminderTouched = true;
      _reminderLeadMinutes = selection < 0 ? null : selection;
    });
  }

  Future<void> _chooseRecurrence() async {
    final selection = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _RecurrencePicker(),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _recurrenceFrequency = selection < 0
          ? null
          : RecurrenceFrequency.values[selection];
    });
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
    _titleController.dispose();
    _notesController.dispose();
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
            key: const Key('schedule-editor-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: Text(
            widget.initialEvent == null ? '新建日程' : '编辑日程',
            key: const Key('schedule-editor-title'),
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            TextButton(
              key: const Key('schedule-editor-save'),
              onPressed: _busy || _loadingDefaults ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                disabledForegroundColor: const Color(0xFFADB5C4),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blue,
                      ),
                    )
                  : const Text('保存'),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _divider),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            key: const Key('schedule-editor-scroll'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleCard(
                  controller: _titleController,
                  enabled: !_busy,
                  onOpenAssistant: widget.onOpenAssistant,
                ),
                const SizedBox(height: 30),
                const _SectionLabel('时间'),
                const SizedBox(height: 11),
                _FormCard(
                  children: [
                    _SwitchRow(
                      label: '全天',
                      value: _allDay,
                      onChanged: _setAllDay,
                    ),
                    const _InnerDivider(),
                    _ValueRow(
                      key: const Key('schedule-editor-start'),
                      label: '开始',
                      value: _dateTimeLabel(_startsAt, _allDay),
                      onTap: _pickStart,
                    ),
                    const _InnerDivider(),
                    _ValueRow(
                      key: const Key('schedule-editor-end'),
                      label: '结束',
                      value: _dateTimeLabel(_endsAt, _allDay),
                      onTap: _pickEnd,
                    ),
                    const _InnerDivider(),
                    _ValueRow(label: '时区', value: _timezoneLabel(_timezoneId)),
                  ],
                ),
                const SizedBox(height: 30),
                const _SectionLabel('提醒与重复'),
                const SizedBox(height: 11),
                _FormCard(
                  children: [
                    _ValueRow(
                      key: const Key('schedule-editor-reminder'),
                      label: '提醒',
                      value: _reminderLabel(),
                      showChevron: true,
                      onTap: _chooseReminder,
                    ),
                    const _InnerDivider(),
                    _ValueRow(
                      key: const Key('schedule-editor-recurrence'),
                      label: '重复',
                      value: _recurrenceLabel(_recurrenceFrequency),
                      showChevron: true,
                      onTap: _chooseRecurrence,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const _SectionLabel('备注'),
                const SizedBox(height: 11),
                Container(
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                  child: TextField(
                    key: const Key('schedule-editor-notes'),
                    controller: _notesController,
                    enabled: !_busy,
                    maxLines: null,
                    maxLength: 4000,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16,
                      height: 1.45,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      isCollapsed: true,
                      hintText: '添加备注（可选）',
                      hintStyle: TextStyle(color: _muted, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 31),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: _blue,
                      size: 22,
                    ),
                    SizedBox(width: 9),
                    Text(
                      '保存后将通过系统原生通知提醒',
                      style: TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String _reminderLabel() {
    if (!_reminderTouched && widget.initialReminders.length > 1) {
      return '${widget.initialReminders.length} 个提醒';
    }
    final minutes = _reminderLeadMinutes;
    if (minutes == null) return '不提醒';
    if (minutes == 0) return '日程开始时';
    if (minutes < 60) return '提前 $minutes 分钟';
    if (minutes % 1440 == 0) return '提前 ${minutes ~/ 1440} 天';
    return '提前 ${minutes ~/ 60} 小时';
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.controller,
    required this.enabled,
    required this.onOpenAssistant,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _cardBorder),
    ),
    padding: const EdgeInsets.only(left: 16, right: 7),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('schedule-editor-title-input'),
            controller: controller,
            enabled: enabled,
            maxLength: 300,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: _text, fontSize: 18),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: '添加标题',
              hintStyle: TextStyle(color: _muted, fontSize: 18),
            ),
          ),
        ),
        TextButton.icon(
          key: const Key('schedule-editor-assistant'),
          onPressed: enabled ? onOpenAssistant : null,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('让助手填写'),
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
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

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _text, fontSize: 16)),
          const Spacer(),
          Switch.adaptive(
            key: const Key('schedule-editor-all-day'),
            value: value,
            activeTrackColor: _blue,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.showChevron = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 64,
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
            if (showChevron) ...[
              const SizedBox(width: 7),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 22),
            ],
          ],
        ),
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

class _ReminderPicker extends StatelessWidget {
  const _ReminderPicker();

  @override
  Widget build(BuildContext context) {
    const options = <(int, String)>[
      (-1, '不提醒'),
      (0, '日程开始时'),
      (5, '提前 5 分钟'),
      (10, '提前 10 分钟'),
      (15, '提前 15 分钟'),
      (30, '提前 30 分钟'),
      (60, '提前 1 小时'),
      (1440, '提前 1 天'),
    ];
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 3, 22, 9),
            child: Text(
              '提醒',
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.$2),
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ],
      ),
    );
  }
}

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker();

  @override
  Widget build(BuildContext context) {
    const options = <(int, String)>[
      (-1, '不重复'),
      (0, '每天'),
      (1, '每周'),
      (2, '每月'),
    ];
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 3, 22, 9),
            child: Text(
              '重复',
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.$2),
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ],
      ),
    );
  }
}

DateTime _nextWholeHour(DateTime now) =>
    DateTime(now.year, now.month, now.day, now.hour + 1);

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

DateTime _toUtc(DateTime wallTime, String timezoneId) => tz.TZDateTime(
  tz.getLocation(timezoneId),
  wallTime.year,
  wallTime.month,
  wallTime.day,
  wallTime.hour,
  wallTime.minute,
).toUtc();

String _dateTimeLabel(DateTime value, bool allDay) {
  final weekday = const ['一', '二', '三', '四', '五', '六', '日'][value.weekday - 1];
  final date = '${value.month}月${value.day}日 周$weekday';
  if (allDay) return date;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}

String _timezoneLabel(String timezoneId) => switch (timezoneId) {
  'Asia/Shanghai' || 'Asia/Chongqing' || 'Asia/Harbin' => '中国标准时间',
  'Asia/Hong_Kong' => '香港时间',
  'Asia/Taipei' => '台北时间',
  'Asia/Tokyo' => '日本标准时间',
  'UTC' || 'Etc/UTC' => '协调世界时',
  _ => timezoneId.replaceAll('_', ' '),
};

String _recurrenceLabel(RecurrenceFrequency? frequency) => switch (frequency) {
  null => '不重复',
  RecurrenceFrequency.daily => '每天',
  RecurrenceFrequency.weekly => '每周',
  RecurrenceFrequency.monthly => '每月',
};

String _newId() => const Uuid().v4();

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
