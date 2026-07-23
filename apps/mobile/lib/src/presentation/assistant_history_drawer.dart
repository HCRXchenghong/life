import 'package:flutter/material.dart';

import '../application/assistant_conversation.dart';

typedef AssistantConversationSelectionCallback =
    Future<void> Function(AssistantConversationSummary conversation);

Future<void> showAssistantHistoryDrawer({
  required BuildContext context,
  required AssistantConversationHistorySource source,
  required String accountName,
  required String? activeConversationId,
  required AssistantConversationSelectionCallback onSelect,
  required Future<void> Function() onNewConversation,
  required Future<void> Function(String conversationId) onDeleted,
  required VoidCallback onOpenSettings,
  required ValueChanged<String> onMessage,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭对话历史',
  barrierColor: const Color(0x660B1220),
  transitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (context, _, _) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: 0.88,
      heightFactor: 1,
      child: _AssistantHistoryDrawer(
        source: source,
        accountName: accountName,
        activeConversationId: activeConversationId,
        onSelect: onSelect,
        onNewConversation: onNewConversation,
        onDeleted: onDeleted,
        onOpenSettings: onOpenSettings,
        onMessage: onMessage,
      ),
    ),
  ),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  },
);

class _AssistantHistoryDrawer extends StatefulWidget {
  const _AssistantHistoryDrawer({
    required this.source,
    required this.accountName,
    required this.activeConversationId,
    required this.onSelect,
    required this.onNewConversation,
    required this.onDeleted,
    required this.onOpenSettings,
    required this.onMessage,
  });

  final AssistantConversationHistorySource source;
  final String accountName;
  final String? activeConversationId;
  final AssistantConversationSelectionCallback onSelect;
  final Future<void> Function() onNewConversation;
  final Future<void> Function(String conversationId) onDeleted;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onMessage;

  @override
  State<_AssistantHistoryDrawer> createState() =>
      _AssistantHistoryDrawerState();
}

class _AssistantHistoryDrawerState extends State<_AssistantHistoryDrawer> {
  final _searchController = TextEditingController();
  List<AssistantConversationSummary>? _conversations;
  String? _busyConversationId;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await widget.source.loadAssistantConversations();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } on Object {
      if (!mounted) return;
      setState(() => _conversations = const []);
      widget.onMessage('无法加载对话历史，请稍后重试');
    }
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  Future<void> _newConversation() async {
    if (_creating || _busyConversationId != null) return;
    setState(() => _creating = true);
    try {
      await widget.onNewConversation();
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) widget.onMessage('无法新建对话，请稍后重试');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _select(AssistantConversationSummary conversation) async {
    if (_creating || _busyConversationId != null) return;
    setState(() => _busyConversationId = conversation.id);
    try {
      await widget.onSelect(conversation);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) widget.onMessage('无法打开此对话，请稍后重试');
    } finally {
      if (mounted) setState(() => _busyConversationId = null);
    }
  }

  Future<void> _rename(AssistantConversationSummary conversation) async {
    var editedTitle = conversation.title;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('assistant-history-rename-dialog'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重命名对话'),
        content: TextFormField(
          key: const Key('assistant-history-rename-input'),
          initialValue: conversation.title,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: '输入对话名称',
            counterText: '',
          ),
          onChanged: (value) => editedTitle = value,
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('assistant-history-rename-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3370FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = editedTitle.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (title == null || !mounted) return;
    try {
      await widget.source.renameAssistantConversation(conversation.id, title);
      await _load();
    } on Object {
      if (mounted) widget.onMessage('重命名失败，请稍后重试');
    }
  }

  Future<void> _delete(AssistantConversationSummary conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('assistant-history-delete-dialog'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除此对话？'),
        content: Text(
          '“${conversation.title}”将从当前账号中删除，此操作无法撤销。',
          style: const TextStyle(
            color: Color(0xFF646A73),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('assistant-history-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5484D),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyConversationId = conversation.id);
    try {
      await widget.source.deleteAssistantConversation(conversation.id);
      await widget.onDeleted(conversation.id);
      await _load();
    } on Object {
      if (mounted) widget.onMessage('删除失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busyConversationId = null);
    }
  }

  void _openSettings() {
    Navigator.pop(context);
    widget.onOpenSettings();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = (_conversations ?? const <AssistantConversationSummary>[])
        .where(
          (conversation) =>
              query.isEmpty || conversation.title.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final groups = _groupConversations(filtered, DateTime.now());
    return Material(
      key: const Key('assistant-history-drawer'),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF3370FF),
                    size: 28,
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'Daylink',
                    style: TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('assistant-history-close'),
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F6F8),
                      foregroundColor: const Color(0xFF1F2329),
                      minimumSize: const Size.square(44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 25),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
              child: TextField(
                key: const Key('assistant-history-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索对话',
                  hintStyle: const TextStyle(color: Color(0xFF8F959E)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF646A73),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: OutlinedButton.icon(
                key: const Key('assistant-history-new'),
                onPressed: _creating ? null : _newConversation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F2329),
                  side: const BorderSide(color: Color(0xFFE1E4E8)),
                  minimumSize: const Size.fromHeight(54),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.edit_square, size: 22),
                label: const Text(
                  '新建对话',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _conversations == null
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF3370FF),
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty ? '还没有对话' : '没有找到相关对话',
                        style: const TextStyle(
                          color: Color(0xFF8F959E),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView(
                      key: const Key('assistant-history-list'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      children: [
                        for (final group in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 13, 9, 7),
                            child: Text(
                              group.label,
                              style: const TextStyle(
                                color: Color(0xFF8F959E),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          for (final conversation in group.conversations)
                            _AssistantHistoryRow(
                              conversation: conversation,
                              selected:
                                  conversation.id ==
                                  widget.activeConversationId,
                              busy: conversation.id == _busyConversationId,
                              onTap: () => _select(conversation),
                              onRename: () => _rename(conversation),
                              onDelete: () => _delete(conversation),
                            ),
                        ],
                      ],
                    ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EAED)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 13, 16, 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3370FF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _accountInitial(widget.accountName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('assistant-history-settings'),
                    tooltip: '助手设置',
                    onPressed: _openSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF4E5969),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantHistoryRow extends StatelessWidget {
  const _AssistantHistoryRow({
    required this.conversation,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final AssistantConversationSummary conversation;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('assistant-history-item-${conversation.id}'),
    color: selected ? const Color(0xFFEAF1FF) : Colors.transparent,
    borderRadius: BorderRadius.circular(13),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: busy ? null : onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1465E8)
                      : const Color(0xFF1F2329),
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 17),
                child: SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3370FF),
                  ),
                ),
              )
            else
              PopupMenuButton<_AssistantHistoryMenuAction>(
                key: Key('assistant-history-menu-${conversation.id}'),
                tooltip: '对话操作',
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _AssistantHistoryMenuAction.rename:
                      onRename();
                    case _AssistantHistoryMenuAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _AssistantHistoryMenuAction.rename,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 10),
                        Text('重命名'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _AssistantHistoryMenuAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: Color(0xFFE5484D),
                        ),
                        SizedBox(width: 10),
                        Text('删除', style: TextStyle(color: Color(0xFFE5484D))),
                      ],
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: Color(0xFF646A73),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

enum _AssistantHistoryMenuAction { rename, delete }

class _ConversationGroup {
  const _ConversationGroup(this.label, this.conversations);

  final String label;
  final List<AssistantConversationSummary> conversations;
}

List<_ConversationGroup> _groupConversations(
  List<AssistantConversationSummary> conversations,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final grouped = <String, List<AssistantConversationSummary>>{};
  for (final conversation in conversations) {
    final local = conversation.updatedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    final label = switch (difference) {
      <= 0 => '今天',
      1 => '昨天',
      <= 7 => '过去 7 天',
      _ => '更早',
    };
    grouped.putIfAbsent(label, () => []).add(conversation);
  }
  return [
    for (final label in const ['今天', '昨天', '过去 7 天', '更早'])
      if (grouped[label]?.isNotEmpty ?? false)
        _ConversationGroup(label, grouped[label]!),
  ];
}

String _accountInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'D';
  return trimmed.characters.first.toUpperCase();
}
