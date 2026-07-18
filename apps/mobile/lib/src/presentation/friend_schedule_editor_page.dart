import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../application/friend_schedule_list.dart';
import '../domain/share/share_poll_models.dart';

class FriendScheduleEditorPage extends StatefulWidget {
  const FriendScheduleEditorPage({
    super.key,
    required this.source,
    this.clock = DateTime.now,
  });

  final FriendScheduleCreationSource source;
  final DateTime Function() clock;

  @override
  State<FriendScheduleEditorPage> createState() =>
      _FriendScheduleEditorPageState();
}

class _FriendScheduleEditorPageState extends State<FriendScheduleEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final List<_EditableSlot> _slots;
  late DateTime _closesAt;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    final defaults = _defaultPollTimes(widget.clock());
    _slots = defaults.slots;
    _closesAt = defaults.closesAt;
  }

  Future<void> _create() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      _showMessage('请输入活动名称');
      return;
    }
    if (title.length > 160) {
      _showMessage('活动名称不能超过 160 个字');
      return;
    }
    if (description.length > 2000) {
      _showMessage('补充说明不能超过 2000 个字');
      return;
    }
    if (_slots.length < 2) {
      _showMessage('至少需要 2 个候选时间');
      return;
    }
    final now = widget.clock();
    if (!_closesAt.isAfter(now)) {
      _showMessage('截止时间必须晚于当前时间');
      return;
    }
    final earliestStart = _slots
        .map((slot) => slot.startsAt)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    if (!_closesAt.isBefore(earliestStart)) {
      _showMessage('截止时间必须早于候选时间');
      return;
    }

    setState(() => _busy = true);
    try {
      final timezoneId = await widget.source.loadFriendScheduleTimezoneId();
      final draft = CreateSharePollDraft(
        title: title,
        description: description,
        timezoneId: timezoneId,
        closesAtUtc: _toUtc(_closesAt, timezoneId),
        slots: _slots
            .map(
              (slot) => SharePollSlotDraft(
                startsAtUtc: _toUtc(slot.startsAt, timezoneId),
                endsAtUtc: _toUtc(slot.endsAt, timezoneId),
              ),
            )
            .toList(growable: false),
      );
      draft.validate();
      await widget.source.createFriendSchedule(draft);
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      if (mounted) _showMessage('候选时间或时区不可用，请检查后重试');
    } on FriendScheduleListException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('暂时无法创建，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSlot(int index) async {
    if (_busy) return;
    final current = _slots[index];
    final startsAt = await _showDateTimeSheet(
      title: '开始时间',
      initial: current.startsAt,
      minimum: _minimumPickerDate(),
    );
    if (startsAt == null || !mounted) return;
    final currentDuration = current.endsAt.difference(current.startsAt);
    final proposedEnd = startsAt.add(
      currentDuration < const Duration(minutes: 5)
          ? const Duration(hours: 1)
          : currentDuration,
    );
    final endsAt = await _showDateTimeSheet(
      title: '结束时间',
      initial: proposedEnd,
      minimum: startsAt.add(const Duration(minutes: 5)),
    );
    if (endsAt == null || !mounted) return;
    if (!endsAt.isAfter(startsAt)) {
      _showMessage('结束时间必须晚于开始时间');
      return;
    }
    if (_isDuplicate(startsAt, endsAt, excluding: index)) {
      _showMessage('候选时间不能重复');
      return;
    }
    setState(() => _slots[index] = _EditableSlot(startsAt, endsAt));
  }

  Future<void> _addSlot() async {
    if (_busy) return;
    if (_slots.length >= 30) {
      _showMessage('最多可添加 30 个候选时间');
      return;
    }
    final last = _slots.last;
    final proposedStart = last.startsAt.add(const Duration(days: 1));
    final startsAt = await _showDateTimeSheet(
      title: '开始时间',
      initial: proposedStart,
      minimum: _minimumPickerDate(),
    );
    if (startsAt == null || !mounted) return;
    final duration = last.endsAt.difference(last.startsAt);
    final endsAt = await _showDateTimeSheet(
      title: '结束时间',
      initial: startsAt.add(duration),
      minimum: startsAt.add(const Duration(minutes: 5)),
    );
    if (endsAt == null || !mounted) return;
    if (_isDuplicate(startsAt, endsAt)) {
      _showMessage('候选时间不能重复');
      return;
    }
    setState(() => _slots.add(_EditableSlot(startsAt, endsAt)));
  }

  Future<void> _removeSlot(int index) async {
    if (_busy) return;
    if (_slots.length <= 2) {
      _showMessage('至少保留 2 个候选时间');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除候选时间？'),
        content: const Text('删除后可以重新添加。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) setState(() => _slots.removeAt(index));
  }

  Future<void> _editClosesAt() async {
    if (_busy) return;
    final value = await _showDateTimeSheet(
      title: '截止时间',
      initial: _closesAt,
      minimum: _minimumPickerDate(),
    );
    if (value != null && mounted) setState(() => _closesAt = value);
  }

  Future<DateTime?> _showDateTimeSheet({
    required String title,
    required DateTime initial,
    required DateTime minimum,
  }) async {
    var picked = initial.isBefore(minimum) ? minimum : initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 360,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, picked),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _divider),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                minuteInterval: 5,
                initialDateTime: picked,
                minimumDate: minimum,
                maximumDate: DateTime(2100, 12, 31, 23, 55),
                onDateTimeChanged: (value) => picked = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDuplicate(DateTime startsAt, DateTime endsAt, {int? excluding}) {
    for (var index = 0; index < _slots.length; index++) {
      if (index == excluding) continue;
      final slot = _slots[index];
      if (slot.startsAt == startsAt && slot.endsAt == endsAt) return true;
    }
    return false;
  }

  DateTime _minimumPickerDate() {
    final now = widget.clock();
    var minuteOfDay = now.hour * 60 + now.minute;
    if (now.second != 0 || now.millisecond != 0 || now.microsecond != 0) {
      minuteOfDay++;
    }
    final roundedMinute = ((minuteOfDay + 4) ~/ 5) * 5;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: roundedMinute));
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          toolbarHeight: 58,
          leadingWidth: 64,
          leading: IconButton(
            key: const Key('friend-schedule-editor-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: '返回',
          ),
          title: const Text(
            '新建选时间',
            key: Key('friend-schedule-editor-title'),
            style: TextStyle(
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            TextButton(
              key: const Key('friend-schedule-editor-create'),
              onPressed: _busy ? null : _create,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                disabledForegroundColor: const Color(0xFFADB5C4),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blue,
                      ),
                    )
                  : const Text('创建'),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            key: const Key('friend-schedule-editor-scroll'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('基本信息'),
                const SizedBox(height: 11),
                _FormCard(
                  children: [
                    _TextInputRow(
                      inputKey: const Key('friend-schedule-editor-name'),
                      label: '活动名称',
                      hint: '请输入',
                      controller: _titleController,
                      maxLength: 160,
                      enabled: !_busy,
                    ),
                    const _InnerDivider(),
                    _TextInputRow(
                      inputKey: const Key('friend-schedule-editor-description'),
                      label: '补充说明',
                      hint: '可选',
                      controller: _descriptionController,
                      maxLength: 2000,
                      enabled: !_busy,
                    ),
                  ],
                ),
                const SizedBox(height: 29),
                const _SectionLabel('候选时间'),
                const SizedBox(height: 11),
                _FormCard(
                  children: [
                    for (var index = 0; index < _slots.length; index++) ...[
                      _CandidateRow(
                        key: Key('friend-schedule-editor-slot-$index'),
                        slot: _slots[index],
                        onTap: () => _editSlot(index),
                        onLongPress: () => _removeSlot(index),
                      ),
                      const _InnerDivider(),
                    ],
                    _AddCandidateRow(enabled: !_busy, onTap: _addSlot),
                  ],
                ),
                const SizedBox(height: 29),
                const _SectionLabel('设置'),
                const SizedBox(height: 11),
                _FormCard(
                  children: [
                    _ValueRow(
                      key: const Key('friend-schedule-editor-closes-at'),
                      label: '截止时间',
                      value: _dateTimeValue(_closesAt),
                      onTap: _editClosesAt,
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
}

class _TextInputRow extends StatelessWidget {
  const _TextInputRow({
    required this.inputKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.maxLength,
    required this.enabled,
  });

  final Key inputKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLength;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _text, fontSize: 16)),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              key: inputKey,
              controller: controller,
              enabled: enabled,
              maxLength: maxLength,
              maxLines: 1,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _text, fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: _muted, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    super.key,
    required this.slot,
    required this.onTap,
    required this.onLongPress,
  });

  final _EditableSlot slot;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onLongPress,
    child: SizedBox(
      height: 96,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.calendar_month_outlined,
                color: _blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(slot.startsAt),
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_timeLabel(slot.startsAt)} – ${_timeLabel(slot.endsAt)}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFADB2BA),
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddCandidateRow extends StatelessWidget {
  const _AddCandidateRow({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('friend-schedule-editor-add-slot'),
    onTap: enabled ? onTap : null,
    child: const SizedBox(
      height: 62,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: _blue, size: 23),
          SizedBox(width: 8),
          Text(
            '添加候选时间',
            style: TextStyle(
              color: _blue,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
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
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

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
            Text(value, style: const TextStyle(color: _text, fontSize: 15)),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFADB2BA),
              size: 16,
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF646A73),
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w500,
      ),
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
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
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

class _EditableSlot {
  const _EditableSlot(this.startsAt, this.endsAt);

  final DateTime startsAt;
  final DateTime endsAt;
}

class _DefaultPollTimes {
  const _DefaultPollTimes({required this.slots, required this.closesAt});

  final List<_EditableSlot> slots;
  final DateTime closesAt;
}

_DefaultPollTimes _defaultPollTimes(DateTime now) {
  var daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
  if (daysUntilSaturday < 2) daysUntilSaturday += 7;
  final saturday = DateTime(now.year, now.month, now.day + daysUntilSaturday);
  final sunday = saturday.add(const Duration(days: 1));
  return _DefaultPollTimes(
    slots: [
      _EditableSlot(
        DateTime(saturday.year, saturday.month, saturday.day, 14),
        DateTime(saturday.year, saturday.month, saturday.day, 18),
      ),
      _EditableSlot(
        DateTime(sunday.year, sunday.month, sunday.day, 10),
        DateTime(sunday.year, sunday.month, sunday.day, 12),
      ),
    ],
    closesAt: DateTime(saturday.year, saturday.month, saturday.day - 1, 22),
  );
}

DateTime _toUtc(DateTime wallTime, String timezoneId) => tz.TZDateTime(
  tz.getLocation(timezoneId),
  wallTime.year,
  wallTime.month,
  wallTime.day,
  wallTime.hour,
  wallTime.minute,
).toUtc();

String _dateLabel(DateTime value) {
  final weekday = const ['一', '二', '三', '四', '五', '六', '日'][value.weekday - 1];
  return '${value.month}月${value.day}日  周$weekday';
}

String _dateTimeValue(DateTime value) =>
    '${value.month}月${value.day}日 ${_timeLabel(value)}';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFF0F1F2);
