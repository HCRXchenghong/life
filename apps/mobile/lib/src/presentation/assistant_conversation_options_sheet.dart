import 'package:flutter/material.dart';

import '../application/assistant_conversation.dart';

enum AssistantConversationOption { rename, export, clear, delete }

Future<AssistantConversationOption?> showAssistantConversationOptionsSheet({
  required BuildContext context,
  required bool hasConversation,
}) => showModalBottomSheet<AssistantConversationOption>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x990B1220),
  builder: (context) =>
      _ConversationOptionsSheet(hasConversation: hasConversation),
);

Future<String?> showAssistantConversationRenameDialog({
  required BuildContext context,
  required String currentTitle,
}) {
  var editedTitle = currentTitle;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('assistant-options-rename-dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('重命名对话'),
      content: TextFormField(
        key: const Key('assistant-options-rename-input'),
        initialValue: currentTitle,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(hintText: '输入对话名称', counterText: ''),
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
          key: const Key('assistant-options-rename-confirm'),
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
}

Future<AssistantConversationExportFormat?> showAssistantExportFormatSheet({
  required BuildContext context,
}) => showModalBottomSheet<AssistantConversationExportFormat>(
  context: context,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x990B1220),
  builder: (context) => Material(
    key: const Key('assistant-export-format-sheet'),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D7DD),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择导出格式',
              style: TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 15),
            _ExportFormatRow(
              actionKey: const Key('assistant-export-pdf'),
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF',
              subtitle: '分页保存当前可见对话',
              onTap: () =>
                  Navigator.pop(context, AssistantConversationExportFormat.pdf),
            ),
            _ExportFormatRow(
              actionKey: const Key('assistant-export-markdown'),
              icon: Icons.code_rounded,
              title: 'Markdown',
              subtitle: '保留标题、附件和生成文件名称',
              onTap: () => Navigator.pop(
                context,
                AssistantConversationExportFormat.markdown,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<bool> confirmAssistantConversationAction({
  required BuildContext context,
  required AssistantConversationOption action,
  required String title,
}) async {
  final deleting = action == AssistantConversationOption.delete;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: Key(
        deleting
            ? 'assistant-options-delete-dialog'
            : 'assistant-options-clear-dialog',
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(deleting ? '删除此对话？' : '清空当前内容？'),
      content: Text(
        deleting
            ? '“$title”将从当前账号中删除，此操作无法撤销。'
            : '当前显示的内容和上下文将被清空，但会保留“$title”这个对话。',
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
          key: Key(
            deleting
                ? 'assistant-options-delete-confirm'
                : 'assistant-options-clear-confirm',
          ),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: deleting
                ? const Color(0xFFE5484D)
                : const Color(0xFF3370FF),
          ),
          child: Text(deleting ? '删除' : '清空'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _ConversationOptionsSheet extends StatelessWidget {
  const _ConversationOptionsSheet({required this.hasConversation});

  final bool hasConversation;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('assistant-conversation-options-sheet'),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 11, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D7DD),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 44),
                const Expanded(
                  child: Text(
                    '对话选项',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('assistant-options-close'),
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F6F8),
                    foregroundColor: const Color(0xFF1F2329),
                    minimumSize: const Size.square(44),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ConversationOptionRow(
              actionKey: const Key('assistant-options-rename'),
              icon: Icons.edit_outlined,
              title: '重命名对话',
              subtitle: '修改当前对话名称',
              enabled: hasConversation,
              onTap: () =>
                  Navigator.pop(context, AssistantConversationOption.rename),
            ),
            _ConversationOptionRow(
              actionKey: const Key('assistant-options-export'),
              icon: Icons.file_download_outlined,
              title: '导出对话',
              subtitle: '保存为 PDF 或 Markdown',
              enabled: hasConversation,
              onTap: () =>
                  Navigator.pop(context, AssistantConversationOption.export),
            ),
            _ConversationOptionRow(
              actionKey: const Key('assistant-options-clear'),
              icon: Icons.cleaning_services_outlined,
              title: '清空当前内容',
              subtitle: '保留对话名称并重新开始',
              enabled: hasConversation,
              onTap: () =>
                  Navigator.pop(context, AssistantConversationOption.clear),
            ),
            const Divider(height: 1, color: Color(0xFFE8EAED)),
            _ConversationOptionRow(
              actionKey: const Key('assistant-options-delete'),
              icon: Icons.delete_outline_rounded,
              title: '删除对话',
              subtitle: '此操作无法撤销',
              enabled: hasConversation,
              destructive: true,
              showChevron: false,
              onTap: () =>
                  Navigator.pop(context, AssistantConversationOption.delete),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConversationOptionRow extends StatelessWidget {
  const _ConversationOptionRow({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final primary = !enabled
        ? const Color(0xFFB7BBC3)
        : destructive
        ? const Color(0xFFE5484D)
        : const Color(0xFF1F2329);
    return InkWell(
      key: actionKey,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 15),
        child: Row(
          children: [
            SizedBox(width: 38, child: Icon(icon, color: primary, size: 25)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled
                          ? const Color(0xFF8F959E)
                          : const Color(0xFFC2C5CB),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: enabled
                    ? const Color(0xFF8F959E)
                    : const Color(0xFFD4D7DD),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExportFormatRow extends StatelessWidget {
  const _ExportFormatRow({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: actionKey,
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    leading: Icon(icon, color: const Color(0xFF3370FF)),
    title: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1F2329),
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Color(0xFF8F959E), fontSize: 13),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8F959E)),
  );
}
