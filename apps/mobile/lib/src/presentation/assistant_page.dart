import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/assistant_settings.dart';
import '../domain/ai/ai_models.dart';
import 'app_navigation.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.onDestinationSelected,
    required this.onOpenHistory,
    required this.onNewConversation,
    required this.onOpenMore,
    required this.onAddAttachment,
    required this.onVoiceInput,
    required this.onSubmit,
    required this.onMessage,
    this.settings,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final VoidCallback onOpenHistory;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenMore;
  final VoidCallback onAddAttachment;
  final VoidCallback onVoiceInput;
  final Future<void> Function(String input) onSubmit;
  final ValueChanged<String> onMessage;
  final AssistantSettingsSource? settings;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _inputController = TextEditingController();
  AssistantMode _mode = AssistantMode.local;
  Set<AssistantMode> _supportedModes = AssistantMode.values.toSet();
  List<String> _models = const [];
  String? _selectedModel;
  var _modelPinned = false;
  var _reasoningEffort = AiReasoningEffort.high;
  var _savingPreferences = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_refreshInput);
    _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant AssistantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.settings, widget.settings)) _loadPreferences();
  }

  void _refreshInput() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final settings = widget.settings;
    if (settings == null) return;
    try {
      final preferences = await settings.loadAssistantPreferences();
      if (!mounted) return;
      setState(() {
        _models = preferences.availableModels;
        _selectedModel = preferences.selectedModel;
        _reasoningEffort = preferences.reasoningEffort;
        _supportedModes = preferences.supportedModes;
        if (!_supportedModes.contains(_mode)) {
          _mode = _supportedModes.contains(AssistantMode.local)
              ? AssistantMode.local
              : _supportedModes.firstOrNull ?? AssistantMode.local;
        }
      });
    } on Object {
      if (mounted) widget.onMessage('无法加载 AI 配置，请稍后重试');
    }
  }

  Future<void> _selectModel(String model) async {
    final previousModel = _selectedModel;
    final previousPinned = _modelPinned;
    setState(() {
      _selectedModel = model;
      _modelPinned = true;
      _savingPreferences = true;
    });
    try {
      await widget.settings?.updateAssistantPreferences(
        model: model,
        reasoningEffort: _reasoningEffort,
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _selectedModel = previousModel;
        _modelPinned = previousPinned;
      });
      widget.onMessage('模型设置保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _selectReasoning(AiReasoningEffort effort) async {
    final previousEffort = _reasoningEffort;
    final model = _selectedModel;
    setState(() {
      _reasoningEffort = effort;
      _savingPreferences = true;
    });
    try {
      if (model != null) {
        await widget.settings?.updateAssistantPreferences(
          model: model,
          reasoningEffort: effort,
        );
      }
    } on Object {
      if (!mounted) return;
      setState(() => _reasoningEffort = previousEffort);
      widget.onMessage('推理强度保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _submit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(input);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _inputController
      ..removeListener(_refreshInput)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: _Header(
                      mode: _mode,
                      supportedModes: _supportedModes,
                      onModeSelected: (mode) => setState(() => _mode = mode),
                      onOpenHistory: widget.onOpenHistory,
                      onNewConversation: widget.onNewConversation,
                      onOpenMore: widget.onOpenMore,
                    ),
                  ),
                  const Expanded(
                    child: Align(
                      alignment: Alignment(0, -0.05),
                      child: Text(
                        '有什么可以帮忙的？',
                        key: Key('assistant-greeting'),
                        style: TextStyle(
                          color: Color(0xFF1F2329),
                          fontSize: 25,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 0, 23, 13),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 9,
                        children: [
                          _ModelChip(
                            models: _models,
                            label: _modelPinned && _selectedModel != null
                                ? _selectedModel!
                                : '自动选择',
                            enabled: !_savingPreferences,
                            onSelected: _selectModel,
                          ),
                          _ReasoningChip(
                            value: _reasoningEffort,
                            enabled: !_savingPreferences,
                            onSelected: _selectReasoning,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
                    child: _Composer(
                      controller: _inputController,
                      submitting: _submitting,
                      onAddAttachment: widget.onAddAttachment,
                      onVoiceInput: widget.onVoiceInput,
                      onSubmit: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DaylinkBottomNavigation(
            currentDestination: AppDestination.assistant,
            onSelected: widget.onDestinationSelected,
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.supportedModes,
    required this.onModeSelected,
    required this.onOpenHistory,
    required this.onNewConversation,
    required this.onOpenMore,
  });

  final AssistantMode mode;
  final Set<AssistantMode> supportedModes;
  final ValueChanged<AssistantMode> onModeSelected;
  final VoidCallback onOpenHistory;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Row(
      children: [
        _HeaderSurface(
          width: 46,
          child: InkWell(
            key: const Key('assistant-history'),
            customBorder: const CircleBorder(),
            onTap: onOpenHistory,
            child: const Center(child: _TwoLineMenuIcon()),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<AssistantMode>(
          key: const Key('assistant-mode'),
          enabled: supportedModes.isNotEmpty,
          tooltip: '切换助手模式',
          position: PopupMenuPosition.under,
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: onModeSelected,
          itemBuilder: (context) => [
            if (supportedModes.contains(AssistantMode.local))
              const PopupMenuItem(
                value: AssistantMode.local,
                child: Text('本地助手'),
              ),
            if (supportedModes.contains(AssistantMode.sshAgent))
              const PopupMenuItem(
                value: AssistantMode.sshAgent,
                child: Text('SSH Agent'),
              ),
          ],
          child: _HeaderSurface(
            width: mode == AssistantMode.local ? 127 : 133,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      mode == AssistantMode.local ? '本地助手' : 'SSH Agent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 19,
                    color: Color(0xFF1F2329),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _HeaderSurface(
          width: 104,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('assistant-new-conversation'),
                  onTap: onNewConversation,
                  child: const Icon(
                    Icons.edit_square,
                    size: 22,
                    color: Color(0xFF1F2329),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  key: const Key('assistant-more'),
                  onTap: onOpenMore,
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    size: 24,
                    color: Color(0xFF1F2329),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeaderSurface extends StatelessWidget {
  const _HeaderSurface({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE8EAED)),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(width: width, height: 46, child: child),
  );
}

class _TwoLineMenuIcon extends StatelessWidget {
  const _TwoLineMenuIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 19,
    height: 16,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_line(width: 19), const SizedBox(height: 5), _line(width: 13)],
    ),
  );

  Widget _line({required double width}) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2329),
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.models,
    required this.label,
    required this.enabled,
    required this.onSelected,
  });

  final List<String> models;
  final String label;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const Key('assistant-model'),
    enabled: enabled && models.isNotEmpty,
    tooltip: '选择模型',
    position: PopupMenuPosition.over,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(12),
    ),
    onSelected: onSelected,
    itemBuilder: (context) => models
        .map(
          (model) => PopupMenuItem(
            value: model,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(model, overflow: TextOverflow.ellipsis),
            ),
          ),
        )
        .toList(growable: false),
    child: _ToolChip(label: label),
  );
}

class _ReasoningChip extends StatelessWidget {
  const _ReasoningChip({
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  final AiReasoningEffort value;
  final bool enabled;
  final ValueChanged<AiReasoningEffort> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AiReasoningEffort>(
    key: const Key('assistant-reasoning'),
    enabled: enabled,
    tooltip: '选择推理强度',
    position: PopupMenuPosition.over,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(12),
    ),
    onSelected: onSelected,
    itemBuilder: (context) => AiReasoningEffort.values
        .map(
          (effort) => PopupMenuItem(
            value: effort,
            child: Text(_reasoningLabel(effort)),
          ),
        )
        .toList(growable: false),
    child: _ToolChip(label: _reasoningLabel(value), compact: true),
  );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: compact ? 92 : 190),
    height: 39,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4E5969),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: Color(0xFF646A73),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.submitting,
    required this.onAddAttachment,
    required this.onVoiceInput,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onAddAttachment;
  final VoidCallback onVoiceInput;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final hasInput = controller.text.trim().isNotEmpty;
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E4E8)),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(color: Color(0xFFE1E4E8)),
            ),
            child: InkWell(
              key: const Key('assistant-add'),
              customBorder: const CircleBorder(),
              onTap: onAddAttachment,
              child: const SizedBox.square(
                dimension: 42,
                child: Icon(
                  Icons.add_rounded,
                  size: 26,
                  color: Color(0xFF646A73),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('assistant-input'),
              controller: controller,
              enabled: !submitting,
              maxLines: 1,
              maxLength: 32768,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                hintText: '询问 Daylink',
                hintStyle: TextStyle(
                  color: Color(0xFF8F959E),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: const TextStyle(color: Color(0xFF1F2329), fontSize: 16),
            ),
          ),
          if (!hasInput)
            IconButton(
              key: const Key('assistant-microphone'),
              onPressed: onVoiceInput,
              icon: const Icon(
                Icons.mic_none_rounded,
                color: Color(0xFF646A73),
                size: 25,
              ),
            ),
          Material(
            color: const Color(0xFF3370FF),
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('assistant-primary-action'),
              customBorder: const CircleBorder(),
              onTap: submitting
                  ? null
                  : hasInput
                  ? onSubmit
                  : onVoiceInput,
              child: SizedBox.square(
                dimension: 44,
                child: submitting
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        hasInput
                            ? Icons.arrow_upward_rounded
                            : Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: hasInput ? 25 : 27,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _reasoningLabel(AiReasoningEffort effort) => switch (effort) {
  AiReasoningEffort.low => '低',
  AiReasoningEffort.medium => '中',
  AiReasoningEffort.high => '高',
  AiReasoningEffort.xhigh => '极高',
};
