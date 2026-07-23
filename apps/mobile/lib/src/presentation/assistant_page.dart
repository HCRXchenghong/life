import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/assistant_artifact_actions.dart';
import '../application/assistant_conversation.dart';
import '../application/assistant_image_actions.dart';
import '../application/assistant_settings.dart';
import '../data/ai_gateway_client.dart';
import '../domain/ai/ai_models.dart';
import '../domain/ai/assistant_artifact_models.dart';
import '../domain/ai/assistant_image_models.dart';
import '../domain/ai/tool_protocol.dart';
import 'app_navigation.dart';
import 'assistant_artifact_preview_sheet.dart';

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
    this.images,
    this.imageActions = const AssistantImageActions(),
    this.conversation,
    this.artifactActions = const AssistantArtifactActions(),
    this.onAddFile,
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
  final AssistantImageGenerationSource? images;
  final AssistantImageActionSource imageActions;
  final AssistantConversationSource? conversation;
  final AssistantArtifactActionSource artifactActions;
  final VoidCallback? onAddFile;

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
  var _imageMode = false;
  var _generationEpoch = 0;
  int? _activeImageTurn;
  var _conversationEpoch = 0;
  int? _activeConversationTurn;
  AssistantImageSize _imageSize = AssistantImageSize.square;
  AssistantImageQuality _imageQuality = AssistantImageQuality.medium;
  final List<_AssistantConversationTurn> _turns = [];

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
    if (_imageMode) {
      await _generateImage(input);
      return;
    }
    final conversation = widget.conversation;
    if (conversation != null && _mode == AssistantMode.local) {
      await _sendConversationMessage(conversation, input);
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(input);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendConversationMessage(
    AssistantConversationSource conversation,
    String input,
  ) async {
    final request = ++_conversationEpoch;
    final turnIndex = _turns.length;
    _inputController.clear();
    setState(() {
      _submitting = true;
      _activeConversationTurn = turnIndex;
      _turns.add(_AssistantConversationTurn(prompt: input));
    });
    try {
      final reply = await conversation.sendAssistantMessage(
        input: input,
        mode: _mode,
        approvals: _approveTool,
      );
      if (!mounted || request != _conversationEpoch) return;
      setState(() {
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: input,
          response: reply.text,
          artifacts: reply.artifacts,
        );
      });
    } on Object catch (error) {
      if (!mounted || request != _conversationEpoch) return;
      final message = _friendlyConversationError(error);
      setState(() {
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: input,
          error: message,
        );
      });
      widget.onMessage(message);
    } finally {
      if (mounted && request == _conversationEpoch) {
        setState(() {
          _submitting = false;
          _activeConversationTurn = null;
        });
      }
    }
  }

  void _cancelConversationMessage() {
    final turnIndex = _activeConversationTurn;
    _conversationEpoch++;
    widget.conversation?.cancelAssistantMessage();
    setState(() {
      _submitting = false;
      _activeConversationTurn = null;
      if (turnIndex != null && turnIndex < _turns.length) {
        final turn = _turns[turnIndex];
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: turn.prompt,
          error: '已取消请求',
        );
      }
    });
    widget.onMessage('已取消请求');
  }

  void _cancelGeneration() {
    if (_imageMode) {
      _cancelImageGeneration();
    } else {
      _cancelConversationMessage();
    }
  }

  Future<ApprovalDecision> _approveTool(ToolSpec spec, ToolCall call) async {
    if (!mounted) return ApprovalDecision.cancel;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_toolApprovalTitle(spec)),
        content: Text(
          _toolApprovalDescription(spec, call),
          style: const TextStyle(
            color: Color(0xFF4E5969),
            fontSize: 14,
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('assistant-tool-decline'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('assistant-tool-approve'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3370FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('允许此次'),
          ),
        ],
      ),
    );
    return approved == true
        ? ApprovalDecision.accept
        : ApprovalDecision.decline;
  }

  Future<void> _showAddTools() async {
    final action = await showModalBottomSheet<_AssistantAddAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      builder: (_) => const _AssistantAddSheet(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AssistantAddAction.image:
        widget.onAddAttachment();
      case _AssistantAddAction.file:
        (widget.onAddFile ?? widget.onAddAttachment)();
      case _AssistantAddAction.generateImage:
        if (widget.images == null) {
          widget.onMessage('当前账号暂时无法使用 AI 生图');
          return;
        }
        setState(() => _imageMode = true);
    }
  }

  Future<void> _generateImage(String prompt) async {
    final source = widget.images;
    if (source == null) {
      widget.onMessage('当前账号暂时无法使用 AI 生图');
      return;
    }
    final request = ++_generationEpoch;
    final turnIndex = _turns.length;
    _inputController.clear();
    setState(() {
      _submitting = true;
      _activeImageTurn = turnIndex;
      _turns.add(
        _AssistantConversationTurn(prompt: prompt, imageRequest: true),
      );
    });
    try {
      final image = await source.generateAssistantImage(
        prompt: prompt,
        size: _imageSize,
        quality: _imageQuality,
      );
      if (!mounted || request != _generationEpoch) return;
      setState(() {
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: prompt,
          image: image,
          imageRequest: true,
        );
      });
    } on Object catch (error) {
      if (!mounted || request != _generationEpoch) return;
      final message = _friendlyImageError(error);
      setState(() {
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: prompt,
          error: message,
          imageRequest: true,
        );
      });
      widget.onMessage(message);
    } finally {
      if (mounted && request == _generationEpoch) {
        setState(() {
          _submitting = false;
          _activeImageTurn = null;
        });
      }
    }
  }

  void _cancelImageGeneration() {
    final turnIndex = _activeImageTurn;
    _generationEpoch++;
    widget.images?.cancelAssistantImageGeneration();
    setState(() {
      _submitting = false;
      _activeImageTurn = null;
      if (turnIndex != null && turnIndex < _turns.length) {
        final turn = _turns[turnIndex];
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: turn.prompt,
          error: '已取消生成',
          imageRequest: true,
        );
      }
    });
    widget.onMessage('已取消生成');
  }

  Future<void> _saveImage(AssistantGeneratedImage image) async {
    try {
      await widget.imageActions.saveToGallery(image);
      if (mounted) widget.onMessage('图片已保存到相册');
    } on Object {
      if (mounted) widget.onMessage('保存失败，请检查相册权限后重试');
    }
  }

  Future<void> _shareImage(
    BuildContext context,
    AssistantGeneratedImage image,
  ) async {
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      await widget.imageActions.share(image, sharePositionOrigin: origin);
    } on Object {
      if (mounted) widget.onMessage('分享失败，请稍后重试');
    }
  }

  Future<void> _previewArtifact(AssistantGeneratedArtifact artifact) =>
      showAssistantArtifactPreviewSheet(
        context: context,
        artifact: artifact,
        onDownload: () => _downloadArtifact(context, artifact),
      );

  Future<void> _downloadArtifact(
    BuildContext context,
    AssistantGeneratedArtifact artifact,
  ) async {
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      await widget.artifactActions.download(
        artifact,
        sharePositionOrigin: origin,
      );
      if (mounted) widget.onMessage('已打开系统保存面板');
    } on Object {
      if (mounted) widget.onMessage('文件导出失败，请稍后重试');
    }
  }

  void _startNewConversation() {
    widget.conversation?.startNewAssistantConversation();
    setState(() {
      _turns.clear();
      _imageMode = false;
    });
    widget.onNewConversation();
  }

  @override
  void dispose() {
    if (_submitting && _imageMode) {
      widget.images?.cancelAssistantImageGeneration();
    } else if (_submitting) {
      widget.conversation?.cancelAssistantMessage();
    }
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
                      onNewConversation: _startNewConversation,
                      onOpenMore: widget.onOpenMore,
                    ),
                  ),
                  Expanded(
                    child: _turns.isEmpty
                        ? const Align(
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
                          )
                        : _AssistantConversation(
                            turns: _turns,
                            onSave: _saveImage,
                            onShare: _shareImage,
                            onRegenerate: (image) {
                              setState(() => _imageMode = true);
                              _generateImage(image.prompt);
                            },
                            onPreviewArtifact: _previewArtifact,
                            onDownloadArtifact: _downloadArtifact,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 0, 23, 13),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 9,
                        children: _imageMode
                            ? [
                                _ImageModeChip(
                                  onClose: _submitting
                                      ? null
                                      : () =>
                                            setState(() => _imageMode = false),
                                ),
                                _ImageSizeChip(
                                  value: _imageSize,
                                  enabled: !_submitting,
                                  onSelected: (value) =>
                                      setState(() => _imageSize = value),
                                ),
                                _ImageQualityChip(
                                  value: _imageQuality,
                                  enabled: !_submitting,
                                  onSelected: (value) =>
                                      setState(() => _imageQuality = value),
                                ),
                              ]
                            : [
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
                      imageMode: _imageMode,
                      onAddAttachment: _showAddTools,
                      onVoiceInput: widget.onVoiceInput,
                      onSubmit: _submit,
                      onCancel: _cancelGeneration,
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
    required this.imageMode,
    required this.onAddAttachment,
    required this.onVoiceInput,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool submitting;
  final bool imageMode;
  final VoidCallback onAddAttachment;
  final VoidCallback onVoiceInput;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

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
              decoration: InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                hintText: imageMode ? '描述要生成的图片' : '询问 Daylink',
                hintStyle: const TextStyle(
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
                  ? onCancel
                  : hasInput
                  ? onSubmit
                  : onVoiceInput,
              child: SizedBox.square(
                dimension: 44,
                child: submitting
                    ? const Icon(
                        Icons.stop_rounded,
                        key: Key('assistant-cancel-generation'),
                        color: Colors.white,
                        size: 22,
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

enum _AssistantAddAction { image, file, generateImage }

class _AssistantAddSheet extends StatelessWidget {
  const _AssistantAddSheet();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-add-sheet'),
    padding: const EdgeInsets.fromLTRB(22, 15, 22, 21),
    decoration: const BoxDecoration(
      color: Color(0xFFF7F8FA),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD7DAE0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 21),
        const Text(
          '添加到对话',
          style: TextStyle(
            color: Color(0xFF1F2329),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 19),
        Row(
          children: [
            Expanded(
              child: _AssistantAddTile(
                actionKey: const Key('assistant-add-image'),
                icon: Icons.image_outlined,
                label: '图片',
                onTap: () => Navigator.pop(context, _AssistantAddAction.image),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _AssistantAddTile(
                actionKey: const Key('assistant-add-file'),
                icon: Icons.insert_drive_file_outlined,
                label: '文件',
                onTap: () => Navigator.pop(context, _AssistantAddAction.file),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _AssistantAddTile(
                actionKey: const Key('assistant-generate-image'),
                icon: Icons.auto_awesome_outlined,
                label: '生成图片',
                highlighted: true,
                onTap: () =>
                    Navigator.pop(context, _AssistantAddAction.generateImage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF3370FF),
                size: 19,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '图片会在当前对话中生成，可继续修改、保存或分享；用量计入当前账号月额度。',
                  style: TextStyle(
                    color: Color(0xFF4E5969),
                    fontSize: 13,
                    height: 1.5,
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

class _AssistantAddTile extends StatelessWidget {
  const _AssistantAddTile({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Material(
    color: highlighted ? const Color(0xFFEEF3FF) : Colors.white,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: highlighted ? const Color(0xFF8EADFF) : const Color(0xFFE1E4E8),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: actionKey,
      onTap: onTap,
      child: SizedBox(
        height: 105,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF3370FF), size: 29),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ImageModeChip extends StatelessWidget {
  const _ImageModeChip({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-image-mode'),
    height: 39,
    padding: const EdgeInsets.only(left: 13, right: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF3FF),
      border: Border.all(color: const Color(0xFFB7CAFF)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome_outlined,
          size: 17,
          color: Color(0xFF3370FF),
        ),
        const SizedBox(width: 7),
        const Text(
          '生成图片',
          style: TextStyle(
            color: Color(0xFF245BDB),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        IconButton(
          key: const Key('assistant-close-image-mode'),
          onPressed: onClose,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 32),
          icon: const Icon(Icons.close_rounded, size: 17),
          color: const Color(0xFF646A73),
        ),
      ],
    ),
  );
}

class _ImageSizeChip extends StatelessWidget {
  const _ImageSizeChip({
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  final AssistantImageSize value;
  final bool enabled;
  final ValueChanged<AssistantImageSize> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AssistantImageSize>(
    key: const Key('assistant-image-size'),
    enabled: enabled,
    tooltip: '图片比例',
    position: PopupMenuPosition.over,
    onSelected: onSelected,
    itemBuilder: (_) => AssistantImageSize.values
        .map((size) => PopupMenuItem(value: size, child: Text(size.label)))
        .toList(growable: false),
    child: _ToolChip(label: value.label, compact: true),
  );
}

class _ImageQualityChip extends StatelessWidget {
  const _ImageQualityChip({
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  final AssistantImageQuality value;
  final bool enabled;
  final ValueChanged<AssistantImageQuality> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AssistantImageQuality>(
    key: const Key('assistant-image-quality'),
    enabled: enabled,
    tooltip: '图片质量',
    position: PopupMenuPosition.over,
    onSelected: onSelected,
    itemBuilder: (_) => AssistantImageQuality.values
        .map(
          (quality) =>
              PopupMenuItem(value: quality, child: Text(quality.label)),
        )
        .toList(growable: false),
    child: _ToolChip(label: value.label, compact: true),
  );
}

class _AssistantConversationTurn {
  const _AssistantConversationTurn({
    required this.prompt,
    this.response,
    this.artifacts = const [],
    this.image,
    this.error,
    this.imageRequest = false,
  });

  final String prompt;
  final String? response;
  final List<AssistantGeneratedArtifact> artifacts;
  final AssistantGeneratedImage? image;
  final String? error;
  final bool imageRequest;
}

class _AssistantConversation extends StatelessWidget {
  const _AssistantConversation({
    required this.turns,
    required this.onSave,
    required this.onShare,
    required this.onRegenerate,
    required this.onPreviewArtifact,
    required this.onDownloadArtifact,
  });

  final List<_AssistantConversationTurn> turns;
  final Future<void> Function(AssistantGeneratedImage image) onSave;
  final Future<void> Function(
    BuildContext context,
    AssistantGeneratedImage image,
  )
  onShare;
  final ValueChanged<AssistantGeneratedImage> onRegenerate;
  final ValueChanged<AssistantGeneratedArtifact> onPreviewArtifact;
  final Future<void> Function(
    BuildContext context,
    AssistantGeneratedArtifact artifact,
  )
  onDownloadArtifact;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('assistant-conversation'),
    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
    reverse: true,
    itemCount: turns.length,
    separatorBuilder: (_, _) => const SizedBox(height: 22),
    itemBuilder: (context, reverseIndex) {
      final turn = turns[turns.length - reverseIndex - 1];
      return _AssistantConversationCard(
        turn: turn,
        onSave: onSave,
        onShare: onShare,
        onRegenerate: onRegenerate,
        onPreviewArtifact: onPreviewArtifact,
        onDownloadArtifact: onDownloadArtifact,
      );
    },
  );
}

class _AssistantConversationCard extends StatelessWidget {
  const _AssistantConversationCard({
    required this.turn,
    required this.onSave,
    required this.onShare,
    required this.onRegenerate,
    required this.onPreviewArtifact,
    required this.onDownloadArtifact,
  });

  final _AssistantConversationTurn turn;
  final Future<void> Function(AssistantGeneratedImage image) onSave;
  final Future<void> Function(
    BuildContext context,
    AssistantGeneratedImage image,
  )
  onShare;
  final ValueChanged<AssistantGeneratedImage> onRegenerate;
  final ValueChanged<AssistantGeneratedArtifact> onPreviewArtifact;
  final Future<void> Function(
    BuildContext context,
    AssistantGeneratedArtifact artifact,
  )
  onDownloadArtifact;

  @override
  Widget build(BuildContext context) {
    final image = turn.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 315),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EDF5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              turn.prompt,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        if (turn.error != null)
          _ImageErrorCard(message: turn.error!)
        else if (turn.imageRequest && image == null)
          const _ImageGeneratingCard()
        else if (image != null)
          _GeneratedImageCard(
            image: image,
            onSave: () => onSave(image),
            onShare: () => onShare(context, image),
            onRegenerate: () => onRegenerate(image),
          )
        else if (turn.response == null)
          const _AssistantThinking()
        else
          _AssistantReplyCard(
            response: turn.response!,
            artifacts: turn.artifacts,
            onPreviewArtifact: onPreviewArtifact,
            onDownloadArtifact: (artifact) =>
                onDownloadArtifact(context, artifact),
          ),
      ],
    );
  }
}

class _AssistantThinking extends StatelessWidget {
  const _AssistantThinking();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Color(0xFF3370FF),
        ),
      ),
    ),
  );
}

class _AssistantReplyCard extends StatelessWidget {
  const _AssistantReplyCard({
    required this.response,
    required this.artifacts,
    required this.onPreviewArtifact,
    required this.onDownloadArtifact,
  });

  final String response;
  final List<AssistantGeneratedArtifact> artifacts;
  final ValueChanged<AssistantGeneratedArtifact> onPreviewArtifact;
  final ValueChanged<AssistantGeneratedArtifact> onDownloadArtifact;

  @override
  Widget build(BuildContext context) {
    final visibleResponse = response.trim().isEmpty && artifacts.isNotEmpty
        ? '已生成${artifacts.first.kind.label}'
        : response.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE1E4E8)),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 19,
            color: Color(0xFF3370FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (visibleResponse.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE1E4E8)),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    visibleResponse,
                    style: const TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              for (final artifact in artifacts) ...[
                if (visibleResponse.isNotEmpty) const SizedBox(height: 12),
                _AssistantArtifactCard(
                  artifact: artifact,
                  onPreview: () => onPreviewArtifact(artifact),
                  onDownload: () => onDownloadArtifact(artifact),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantArtifactCard extends StatelessWidget {
  const _AssistantArtifactCard({
    required this.artifact,
    required this.onPreview,
    required this.onDownload,
  });

  final AssistantGeneratedArtifact artifact;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('assistant-artifact-${artifact.id}'),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          key: Key('assistant-artifact-open-${artifact.id}'),
          onTap: onPreview,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
            child: Row(
              children: [
                _ArtifactIcon(kind: artifact.kind),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artifact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2329),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${artifact.kind.label} · '
                        '${formatArtifactBytes(artifact.byteSize)}',
                        style: const TextStyle(
                          color: Color(0xFF8F959E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8EAED)),
        SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: Key('assistant-artifact-preview-${artifact.id}'),
                  onPressed: onPreview,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3370FF),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text(
                    '预览',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const VerticalDivider(
                width: 1,
                indent: 9,
                endIndent: 9,
                color: Color(0xFFE8EAED),
              ),
              Expanded(
                child: TextButton(
                  key: Key('assistant-artifact-download-${artifact.id}'),
                  onPressed: onDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3370FF),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text(
                    '下载',
                    style: TextStyle(fontWeight: FontWeight.w600),
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

class _ArtifactIcon extends StatelessWidget {
  const _ArtifactIcon({required this.kind});

  final AssistantArtifactKind kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      AssistantArtifactKind.document => (
        const Color(0xFF3370FF),
        Icons.description_rounded,
      ),
      AssistantArtifactKind.spreadsheet => (
        const Color(0xFF12A150),
        Icons.table_chart_rounded,
      ),
      AssistantArtifactKind.presentation => (
        const Color(0xFFF07B3F),
        Icons.slideshow_rounded,
      ),
    };
    return Container(
      width: 50,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 27),
    );
  }
}

class _ImageGeneratingCard extends StatelessWidget {
  const _ImageGeneratingCard();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-image-generating'),
    height: 154,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF3370FF),
            ),
          ),
          SizedBox(height: 13),
          Text(
            '正在生成图片…',
            style: TextStyle(color: Color(0xFF646A73), fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class _ImageErrorCard extends StatelessWidget {
  const _ImageErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-image-error'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3F0),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFD54941)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF4E5969), fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

class _GeneratedImageCard extends StatelessWidget {
  const _GeneratedImageCard({
    required this.image,
    required this.onSave,
    required this.onShare,
    required this.onRegenerate,
  });

  final AssistantGeneratedImage image;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-generated-image'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: switch (image.size) {
              AssistantImageSize.square => 1,
              AssistantImageSize.landscape => 1.5,
              AssistantImageSize.portrait => 2 / 3,
            },
            child: Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFF1F2F4),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            _ImageActionButton(
              actionKey: const Key('assistant-save-image'),
              icon: Icons.download_rounded,
              label: '保存',
              onTap: onSave,
            ),
            _ImageActionButton(
              actionKey: const Key('assistant-share-image'),
              icon: Icons.ios_share_rounded,
              label: '分享',
              onTap: onShare,
            ),
            const Spacer(),
            _ImageActionButton(
              actionKey: const Key('assistant-regenerate-image'),
              icon: Icons.refresh_rounded,
              label: '再生成',
              onTap: onRegenerate,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: actionKey,
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF4E5969),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

String _friendlyImageError(Object error) {
  if (error is AiGatewayException) {
    return switch (error.code) {
      'subscription_required' => '当前账号没有可用的 AI 套餐',
      'quota_exceeded' || 'monthly_quota_exceeded' => '本月 AI 额度已用完',
      'session_rejected' || 'invalid_token' => '登录已失效，请重新登录',
      'image_model_unavailable' => '后台尚未配置可用的生图模型',
      'rate_limited' => '生成请求太频繁，请稍后再试',
      _ => '图片生成失败，请稍后重试',
    };
  }
  return '图片生成失败，请稍后重试';
}

String _friendlyConversationError(Object error) {
  if (error is AiGatewayException) {
    return switch (error.code) {
      'subscription_required' => '当前账号没有可用的 AI 套餐',
      'quota_exceeded' || 'monthly_quota_exceeded' => '本月 AI 额度已用完',
      'session_rejected' || 'invalid_token' => '登录已失效，请重新登录',
      'rate_limited' => '请求太频繁，请稍后再试',
      _ => '助手暂时无法响应，请稍后重试',
    };
  }
  final message = error.toString();
  if (message.contains('登录已失效')) return '登录已失效，请重新登录';
  if (message.contains('SSH 主机')) return '请先在主机页面选择 SSH 主机';
  return '助手暂时无法响应，请稍后重试';
}

String _toolApprovalDescription(ToolSpec spec, ToolCall call) {
  final title = call.arguments['title'] as String?;
  final action = switch (spec.name) {
    'daylink_create_word_document' => '生成 Word 文档',
    'daylink_create_spreadsheet' => '生成 Excel 表格',
    'daylink_create_presentation' => '生成 PPT 演示文稿',
    _ => null,
  };
  if (action == null) {
    return '助手请求执行“${spec.name}”。确认后只允许执行当前这一次操作。';
  }
  final titleLine = title == null || title.trim().isEmpty
      ? ''
      : '\n\n文件标题：${title.trim()}';
  return '$action$titleLine\n\n文件只会保存到当前登录账号的本地隔离空间。';
}

String _toolApprovalTitle(ToolSpec spec) => switch (spec.name) {
  'daylink_create_word_document' ||
  'daylink_create_spreadsheet' ||
  'daylink_create_presentation' => '允许生成文件？',
  _ => '允许执行此操作？',
};

String _reasoningLabel(AiReasoningEffort effort) => switch (effort) {
  AiReasoningEffort.low => '低',
  AiReasoningEffort.medium => '中',
  AiReasoningEffort.high => '高',
  AiReasoningEffort.xhigh => '极高',
};
