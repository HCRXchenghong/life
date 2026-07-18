import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../application/friend_schedule_list.dart';
import '../domain/share/share_poll_models.dart';

class FriendScheduleDetailPage extends StatefulWidget {
  const FriendScheduleDetailPage({
    super.key,
    required this.pollId,
    required this.source,
  });

  final String pollId;
  final FriendScheduleDetailSource source;

  @override
  State<FriendScheduleDetailPage> createState() =>
      _FriendScheduleDetailPageState();
}

class _FriendScheduleDetailPageState extends State<FriendScheduleDetailPage> {
  FriendPollDetails? _details;
  FriendTimeSuggestion? _selected;
  String? _error;
  Timer? _refreshTimer;
  var _busy = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy && silent) return;
    final generation = ++_generation;
    try {
      final details = await widget.source.loadFriendScheduleDetails(
        widget.pollId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _details = details;
        _error = null;
        final selected = _selected;
        if (selected == null ||
            !details.suggestions.any(
              (value) =>
                  value.startsAtUtc == selected.startsAtUtc &&
                  value.endsAtUtc == selected.endsAtUtc,
            )) {
          _selected = details.suggestions.firstOrNull;
        }
      });
    } on FriendScheduleListException catch (error) {
      if (!mounted || generation != _generation || silent) return;
      setState(() => _error = error.message);
    } on Object {
      if (!mounted || generation != _generation || silent) return;
      setState(() => _error = '暂时无法加载，请稍后重试');
    }
  }

  Future<void> _inviteFriend() async {
    final details = _details;
    if (_busy || details == null || details.invites.length >= 50) return;
    final name = await _askFriendName();
    if (!mounted || name == null) return;
    setState(() => _busy = true);
    try {
      final invite = await widget.source.createFriendInvite(
        pollId: details.id,
        displayName: name,
      );
      await _load();
      if (!mounted) return;
      final copied = await _writeClipboard(invite.inviteUrl);
      if (!mounted) return;
      _message(copied ? '已为$name生成专属链接并复制' : '链接已生成，请点列表中的“复制链接”');
    } on FriendScheduleListException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message('暂时无法生成邀请，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askFriendName() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _FriendNameDialog(),
    );
  }

  Future<void> _copyInvite(FriendPollInvite invite) async {
    final copied = await _writeClipboard(invite.inviteUrl);
    if (mounted) {
      _message(copied ? '已复制${invite.displayName}的专属链接' : '复制失败，请稍后重试');
    }
  }

  Future<bool> _writeClipboard(Uri value) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: value.toString()),
      ).timeout(const Duration(seconds: 2));
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _revokeInvite(FriendPollInvite invite) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销专属邀请？'),
        content: Text('撤销后，${invite.displayName}的链接将立即失效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.source.revokeFriendInvite(
        pollId: widget.pollId,
        inviteId: invite.id,
      );
      await _load();
    } on FriendScheduleListException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final details = _details;
    final selected = _selected;
    if (_busy ||
        details == null ||
        selected == null ||
        details.status != SharePollStatus.open) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定这个时间？'),
        content: Text(
          '${_suggestionDate(selected, details.timezoneId)}\n确定后会加入你的日程并安排原生提醒。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('friend-schedule-confirm-dialog'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.source.confirmFriendSchedule(
        details: details,
        suggestion: selected,
      );
      if (!mounted) return;
      _message('时间已确定，并已加入日程');
      Navigator.pop(context, true);
    } on FriendScheduleListException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message('暂时无法确认时间，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(value)),
      );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: _busy ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '返回',
        ),
        title: Text(
          _details?.title ?? '选时间详情',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            key: const Key('friend-schedule-detail-more'),
            onPressed: _busy ? null : () => unawaited(_load()),
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: _bottomBar(),
    ),
  );

  Widget _body() {
    final details = _details;
    if (details == null && _error == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.3));
    }
    if (details == null) {
      return Center(
        child: TextButton.icon(
          onPressed: () => unawaited(_load()),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _ActivityHeader(details: details),
          const SizedBox(height: 24),
          _InviteCard(
            details: details,
            busy: _busy,
            onInvite: _inviteFriend,
            onCopy: _copyInvite,
            onRevoke: _revokeInvite,
          ),
          const SizedBox(height: 28),
          const Text(
            '共同可行时间',
            style: TextStyle(
              color: _text,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text('按参与人数排序', style: TextStyle(color: _muted, fontSize: 14)),
          const SizedBox(height: 14),
          if (details.suggestions.isEmpty)
            const _EmptySuggestions()
          else
            for (
              var index = 0;
              index < details.suggestions.length;
              index++
            ) ...[
              _SuggestionCard(
                suggestion: details.suggestions[index],
                timezoneId: details.timezoneId,
                selected: _sameSuggestion(
                  details.suggestions[index],
                  _selected,
                ),
                best: index == 0,
                onTap: details.status == SharePollStatus.open
                    ? () =>
                          setState(() => _selected = details.suggestions[index])
                    : null,
              ),
              if (index < details.suggestions.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    final details = _details;
    if (details == null) return null;
    final enabled =
        !_busy && details.status == SharePollStatus.open && _selected != null;
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 11, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              details.status == SharePollStatus.open
                  ? '确定后会自动加入你的日程'
                  : '这个活动已经结束',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const Key('friend-schedule-confirm'),
                onPressed: enabled ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: const Color(0xFFD9DEE8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        details.status == SharePollStatus.open
                            ? '确定这个时间'
                            : '已结束',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendNameDialog extends StatefulWidget {
  const _FriendNameDialog();

  @override
  State<_FriendNameDialog> createState() => _FriendNameDialogState();
}

class _FriendNameDialogState extends State<_FriendNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('邀请朋友'),
    content: TextField(
      key: const Key('friend-invite-name'),
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: '朋友姓名', hintText: '例如：小明'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('friend-invite-create'),
        onPressed: _submit,
        child: const Text('生成并复制'),
      ),
    ],
  );
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.details});

  final FriendPollDetails details;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              _statusText(details.status),
              style: const TextStyle(
                color: _blue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (details.closesAtUtc != null)
            Expanded(
              child: Text(
                '截止 ${_deadline(details.closesAtUtc!, details.timezoneId)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
            ),
        ],
      ),
      if (details.description.isNotEmpty) ...[
        const SizedBox(height: 13),
        Text(
          details.description,
          style: const TextStyle(color: _secondary, fontSize: 15, height: 1.55),
        ),
      ],
    ],
  );
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.details,
    required this.busy,
    required this.onInvite,
    required this.onCopy,
    required this.onRevoke,
  });

  final FriendPollDetails details;
  final bool busy;
  final VoidCallback onInvite;
  final ValueChanged<FriendPollInvite> onCopy;
  final ValueChanged<FriendPollInvite> onRevoke;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09000000),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 17, 16, 8),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '专属邀请',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '每位朋友一个独立链接',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Text(
              '${details.invites.length}/50',
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            key: const Key('friend-schedule-invite'),
            onPressed:
                !busy &&
                    details.status == SharePollStatus.open &&
                    details.invites.length < 50
                ? onInvite
                : null,
            style: FilledButton.styleFrom(
              foregroundColor: _blue,
              backgroundColor: const Color(0xFFEDF3FF),
              disabledBackgroundColor: const Color(0xFFF1F2F4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text(
              '邀请朋友',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (details.invites.isNotEmpty) const SizedBox(height: 9),
        for (var index = 0; index < details.invites.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: _divider),
          _InviteRow(
            invite: details.invites[index],
            onCopy: () => onCopy(details.invites[index]),
            onRevoke: () => onRevoke(details.invites[index]),
          ),
        ],
      ],
    ),
  );
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.onCopy,
    required this.onRevoke,
  });

  final FriendPollInvite invite;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('friend-invite-${invite.id}'),
    onLongPress: onRevoke,
    child: SizedBox(
      height: 68,
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFF0F4FF),
            child: Text(
              invite.displayName.characters.first,
              style: const TextStyle(
                color: _blue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invite.status == FriendInviteStatus.submitted
                      ? '已提交 · ${invite.selections.length}段时间'
                      : '待选择',
                  style: TextStyle(
                    color: invite.status == FriendInviteStatus.submitted
                        ? _blue
                        : _muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: Key('friend-invite-copy-${invite.id}'),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('复制链接'),
            style: TextButton.styleFrom(
              foregroundColor: _blue,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.timezoneId,
    required this.selected,
    required this.best,
    required this.onTap,
  });

  final FriendTimeSuggestion suggestion;
  final String timezoneId;
  final bool selected;
  final bool best;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF5F8FF) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(
        color: selected ? _blue : const Color(0xFFE5E7EB),
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? _blue : const Color(0xFFB5BAC2),
              size: 22,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _suggestionDate(suggestion, timezoneId),
                          style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (best) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            '最佳',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${suggestion.peopleCount} 人可以',
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptySuggestions extends StatelessWidget {
  const _EmptySuggestions();

  @override
  Widget build(BuildContext context) => Container(
    height: 116,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Text(
      '朋友提交后，这里会显示共同可行时间',
      style: TextStyle(color: _muted, fontSize: 14),
    ),
  );
}

bool _sameSuggestion(
  FriendTimeSuggestion value,
  FriendTimeSuggestion? selected,
) =>
    selected != null &&
    value.startsAtUtc == selected.startsAtUtc &&
    value.endsAtUtc == selected.endsAtUtc;

String _statusText(SharePollStatus status) => switch (status) {
  SharePollStatus.open => '进行中',
  SharePollStatus.closed => '已确定',
  SharePollStatus.cancelled => '已取消',
  SharePollStatus.expired => '已截止',
};

String _deadline(DateTime value, String timezoneId) {
  final local = tz.TZDateTime.from(value.toUtc(), tz.getLocation(timezoneId));
  return '${local.month}月${local.day}日 ${_two(local.hour)}:${_two(local.minute)}';
}

String _suggestionDate(FriendTimeSuggestion value, String timezoneId) {
  final location = tz.getLocation(timezoneId);
  final start = tz.TZDateTime.from(value.startsAtUtc, location);
  final end = tz.TZDateTime.from(value.endsAtUtc, location);
  final weekday = const ['一', '二', '三', '四', '五', '六', '日'][start.weekday - 1];
  return '${start.month}月${start.day}日 周$weekday  '
      '${_two(start.hour)}:${_two(start.minute)}–${_two(end.hour)}:${_two(end.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _secondary = Color(0xFF4E5969);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFF0F1F2);
