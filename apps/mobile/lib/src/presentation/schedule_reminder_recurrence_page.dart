import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/schedule/schedule_models.dart';

class ScheduleReminderRecurrenceSelection {
  const ScheduleReminderRecurrenceSelection({
    required this.reminderLeadMinutes,
    required this.recurrence,
    required this.reminderChanged,
    required this.recurrenceChanged,
  });

  final int? reminderLeadMinutes;
  final RecurrenceRule? recurrence;
  final bool reminderChanged;
  final bool recurrenceChanged;
}

class ScheduleReminderRecurrencePage extends StatefulWidget {
  const ScheduleReminderRecurrencePage({
    super.key,
    required this.initialReminderLeadMinutes,
    required this.initialRecurrence,
    required this.startsOnWeekday,
  });

  final int? initialReminderLeadMinutes;
  final RecurrenceRule? initialRecurrence;
  final int startsOnWeekday;

  @override
  State<ScheduleReminderRecurrencePage> createState() =>
      _ScheduleReminderRecurrencePageState();
}

class _ScheduleReminderRecurrencePageState
    extends State<ScheduleReminderRecurrencePage> {
  late int? _reminderLeadMinutes = widget.initialReminderLeadMinutes;
  late RecurrenceRule? _recurrence = widget.initialRecurrence;
  var _reminderChanged = false;
  var _recurrenceChanged = false;

  void _setReminder(int? value) {
    setState(() {
      _reminderLeadMinutes = value;
      _reminderChanged = true;
    });
  }

  void _setRecurrence(RecurrenceRule? value) {
    setState(() {
      _recurrence = value;
      _recurrenceChanged = true;
    });
  }

  Future<void> _customReminder() async {
    final value = await _showCustomReminderDialog(
      context,
      _reminderKind == _ReminderKind.custom ? _reminderLeadMinutes : 30,
    );
    if (value != null && mounted) _setReminder(value);
  }

  Future<void> _customRecurrence() async {
    final value = await _showCustomRecurrenceDialog(
      context,
      initial: _recurrence,
      startsOnWeekday: widget.startsOnWeekday,
    );
    if (value != null && mounted) _setRecurrence(value);
  }

  void _done() => Navigator.pop(
    context,
    ScheduleReminderRecurrenceSelection(
      reminderLeadMinutes: _reminderLeadMinutes,
      recurrence: _recurrence,
      reminderChanged: _reminderChanged,
      recurrenceChanged: _recurrenceChanged,
    ),
  );

  _ReminderKind get _reminderKind => switch (_reminderLeadMinutes) {
    null => _ReminderKind.none,
    0 => _ReminderKind.atStart,
    10 => _ReminderKind.tenMinutes,
    _ => _ReminderKind.custom,
  };

  _RecurrenceKind get _recurrenceKind {
    final recurrence = _recurrence;
    if (recurrence == null) return _RecurrenceKind.none;
    final simpleEnd = recurrence.count == null && recurrence.untilUtc == null;
    if (simpleEnd &&
        recurrence.frequency == RecurrenceFrequency.daily &&
        recurrence.interval == 1 &&
        recurrence.weekdays.isEmpty) {
      return _RecurrenceKind.daily;
    }
    if (simpleEnd &&
        recurrence.frequency == RecurrenceFrequency.weekly &&
        recurrence.interval == 1 &&
        recurrence.weekdays.length == 1 &&
        recurrence.weekdays.contains(widget.startsOnWeekday)) {
      return _RecurrenceKind.weekly;
    }
    return _RecurrenceKind.custom;
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
          key: const Key('schedule-reminder-recurrence-back'),
          onPressed: () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        title: const Text(
          '提醒与重复',
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('schedule-reminder-recurrence-done'),
            onPressed: _done,
            style: TextButton.styleFrom(
              foregroundColor: _blue,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('完成'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _divider),
        ),
      ),
      body: SingleChildScrollView(
        key: const Key('schedule-reminder-recurrence-scroll'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(25, 37, 25, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('提醒'),
            const SizedBox(height: 11),
            _ChoiceCard(
              children: [
                _ChoiceRow(
                  key: const Key('reminder-choice-none'),
                  label: '不提醒',
                  selected: _reminderKind == _ReminderKind.none,
                  onTap: () => _setReminder(null),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('reminder-choice-start'),
                  label: '日程开始时',
                  selected: _reminderKind == _ReminderKind.atStart,
                  onTap: () => _setReminder(0),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('reminder-choice-ten-minutes'),
                  label: '提前 10 分钟',
                  selected: _reminderKind == _ReminderKind.tenMinutes,
                  onTap: () => _setReminder(10),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('reminder-choice-custom'),
                  label: '自定义',
                  value: _reminderKind == _ReminderKind.custom
                      ? _reminderLabel(_reminderLeadMinutes!)
                      : null,
                  selected: _reminderKind == _ReminderKind.custom,
                  onTap: _customReminder,
                ),
              ],
            ),
            const SizedBox(height: 39),
            const _SectionLabel('重复'),
            const SizedBox(height: 11),
            _ChoiceCard(
              children: [
                _ChoiceRow(
                  key: const Key('recurrence-choice-none'),
                  label: '不重复',
                  selected: _recurrenceKind == _RecurrenceKind.none,
                  onTap: () => _setRecurrence(null),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('recurrence-choice-daily'),
                  label: '每天',
                  selected: _recurrenceKind == _RecurrenceKind.daily,
                  onTap: () => _setRecurrence(
                    const RecurrenceRule(frequency: RecurrenceFrequency.daily),
                  ),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('recurrence-choice-weekly'),
                  label: '每周',
                  selected: _recurrenceKind == _RecurrenceKind.weekly,
                  onTap: () => _setRecurrence(
                    RecurrenceRule(
                      frequency: RecurrenceFrequency.weekly,
                      weekdays: {widget.startsOnWeekday},
                    ),
                  ),
                ),
                const _InnerDivider(),
                _ChoiceRow(
                  key: const Key('recurrence-choice-custom'),
                  label: '自定义',
                  value: _recurrenceKind == _RecurrenceKind.custom
                      ? _recurrenceLabel(_recurrence!)
                      : null,
                  selected: _recurrenceKind == _RecurrenceKind.custom,
                  onTap: _customRecurrence,
                ),
              ],
            ),
          ],
        ),
      ),
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
    ),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _cardBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.value,
  });

  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: _text, fontSize: 16)),
            if (value != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            ] else
              const Spacer(),
            if (selected) ...[
              const SizedBox(width: 12),
              const Icon(Icons.check_rounded, color: _blue, size: 23),
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
    padding: EdgeInsets.symmetric(horizontal: 17),
    child: Divider(height: 1, thickness: 1, color: _divider),
  );
}

enum _ReminderKind { none, atStart, tenMinutes, custom }

enum _RecurrenceKind { none, daily, weekly, custom }

Future<int?> _showCustomReminderDialog(
  BuildContext context,
  int? initialMinutes,
) => showDialog<int>(
  context: context,
  barrierColor: const Color(0x52000000),
  builder: (_) => _CustomReminderDialog(initialMinutes: initialMinutes ?? 30),
);

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  late final TextEditingController _controller;
  late int _unitMinutes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unitMinutes = widget.initialMinutes % 1440 == 0
        ? 1440
        : widget.initialMinutes % 60 == 0
        ? 60
        : 1;
    _controller = TextEditingController(
      text: (widget.initialMinutes ~/ _unitMinutes).clamp(1, 365).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = int.tryParse(_controller.text);
    final minutes = amount == null ? null : amount * _unitMinutes;
    if (amount == null ||
        amount < 1 ||
        minutes! > const Duration(days: 365).inMinutes) {
      setState(() => _error = '请输入有效时间');
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const Key('custom-reminder-dialog'),
    insetPadding: const EdgeInsets.symmetric(horizontal: 32),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 10,
    shadowColor: const Color(0x26000000),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 0),
          child: Text(
            '自定义提醒',
            style: TextStyle(
              color: _text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, 23, 22, _error == null ? 24 : 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Text(
                    '提前',
                    style: TextStyle(color: _text, fontSize: 16),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 66,
                    height: 48,
                    child: TextField(
                      key: const Key('custom-reminder-amount'),
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _text, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF2F3F5),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _blue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 92,
                    height: 48,
                    padding: const EdgeInsets.only(left: 14, right: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        key: const Key('custom-reminder-unit'),
                        value: _unitMinutes,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _muted,
                          size: 21,
                        ),
                        style: const TextStyle(color: _text, fontSize: 16),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('分钟')),
                          DropdownMenuItem(value: 60, child: Text('小时')),
                          DropdownMenuItem(value: 1440, child: Text('天')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _unitMinutes = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('custom-reminder-error'),
                  style: const TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _divider),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('custom-reminder-cancel'),
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    shape: const RoundedRectangleBorder(),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: _divider),
              Expanded(
                child: TextButton(
                  key: const Key('custom-reminder-confirm'),
                  onPressed: _confirm,
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    shape: const RoundedRectangleBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<RecurrenceRule?> _showCustomRecurrenceDialog(
  BuildContext context, {
  required RecurrenceRule? initial,
  required int startsOnWeekday,
}) => showDialog<RecurrenceRule>(
  context: context,
  builder: (_) => _CustomRecurrenceDialog(
    initial: initial,
    startsOnWeekday: startsOnWeekday,
  ),
);

class _CustomRecurrenceDialog extends StatefulWidget {
  const _CustomRecurrenceDialog({
    required this.initial,
    required this.startsOnWeekday,
  });

  final RecurrenceRule? initial;
  final int startsOnWeekday;

  @override
  State<_CustomRecurrenceDialog> createState() =>
      _CustomRecurrenceDialogState();
}

class _CustomRecurrenceDialogState extends State<_CustomRecurrenceDialog> {
  late final TextEditingController _controller;
  late RecurrenceFrequency _frequency;
  String? _error;

  @override
  void initState() {
    super.initState();
    _frequency = widget.initial?.frequency ?? RecurrenceFrequency.weekly;
    _controller = TextEditingController(
      text: (widget.initial?.interval ?? 2).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final interval = int.tryParse(_controller.text);
    if (interval == null || interval < 1 || interval > 365) {
      setState(() => _error = '请输入 1–365');
      return;
    }
    final initial = widget.initial;
    Navigator.pop(
      context,
      RecurrenceRule(
        frequency: _frequency,
        interval: interval,
        weekdays: _frequency == RecurrenceFrequency.weekly
            ? initial?.weekdays.isNotEmpty == true
                  ? initial!.weekdays
                  : {widget.startsOnWeekday}
            : const {},
        count: initial?.count,
        untilUtc: initial?.untilUtc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('自定义重复'),
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 17), child: Text('每')),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const Key('custom-recurrence-interval'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<RecurrenceFrequency>(
          key: const Key('custom-recurrence-frequency'),
          value: _frequency,
          items: const [
            DropdownMenuItem(
              value: RecurrenceFrequency.daily,
              child: Text('天'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.weekly,
              child: Text('周'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.monthly,
              child: Text('月'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _frequency = value);
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        key: const Key('custom-recurrence-confirm'),
        onPressed: _confirm,
        child: const Text('确定'),
      ),
    ],
  );
}

String _reminderLabel(int minutes) {
  if (minutes < 60) return '提前 $minutes 分钟';
  if (minutes % 1440 == 0) return '提前 ${minutes ~/ 1440} 天';
  if (minutes % 60 == 0) return '提前 ${minutes ~/ 60} 小时';
  return '提前 $minutes 分钟';
}

String _recurrenceLabel(RecurrenceRule rule) {
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
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
