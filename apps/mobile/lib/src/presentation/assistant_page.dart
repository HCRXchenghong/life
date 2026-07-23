import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/assistant_artifact_actions.dart';
import '../application/assistant_conversation.dart';
import '../application/assistant_conversation_export.dart';
import '../application/assistant_file_picker.dart';
import '../application/assistant_image_actions.dart';
import '../application/assistant_image_picker.dart';
import '../application/assistant_settings.dart';
import '../application/assistant_speech_input.dart';
import '../data/ai_gateway_client.dart';
import '../domain/ai/ai_models.dart';
import '../domain/ai/assistant_artifact_models.dart';
import '../domain/ai/assistant_image_models.dart';
import '../domain/ai/assistant_input_file.dart';
import '../domain/ai/tool_protocol.dart';
import 'app_navigation.dart';
import 'assistant_artifact_preview_sheet.dart';
import 'assistant_conversation_options_sheet.dart';
import 'assistant_history_drawer.dart';

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
    this.history,
    this.artifactActions = const AssistantArtifactActions(),
    this.conversationExports = const AssistantConversationExportActions(),
    this.fileSource = const DeviceAssistantInputFileSource(),
    this.imageSource = const DeviceAssistantInputImageSource(),
    this.speechSource,
    this.accountName = 'Daylink',
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
  final AssistantConversationHistorySource? history;
  final AssistantArtifactActionSource artifactActions;
  final AssistantConversationExportSource conversationExports;
  final AssistantInputFileSource fileSource;
  final AssistantInputImageSource imageSource;
  final AssistantSpeechInputSource? speechSource;
  final String accountName;

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
  final List<AssistantInputFile> _inputFiles = [];
  AssistantImageSize _imageSize = AssistantImageSize.square;
  AssistantImageQuality _imageQuality = AssistantImageQuality.medium;
  final List<_AssistantConversationTurn> _turns = [];
  final Map<String, List<_AssistantConversationTurn>> _turnsByConversation = {};
  String? _activeConversationId;
  late AssistantSpeechInputSource _speechSource;
  late bool _ownsSpeechSource;
  StreamSubscription<AssistantSpeechUpdate>? _speechSubscription;
  var _speechListening = false;
  var _speechStarting = false;
  var _speechTranscript = '';
  var _speechLevel = 0.0;
  var _speechEpoch = 0;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_refreshInput);
    _activeConversationId = widget.history?.activeAssistantConversationId;
    _bindSpeechSource();
    _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant AssistantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.settings, widget.settings)) _loadPreferences();
    if (!identical(oldWidget.history, widget.history)) {
      _activeConversationId = widget.history?.activeAssistantConversationId;
    }
    if (!identical(oldWidget.speechSource, widget.speechSource)) {
      unawaited(_replaceSpeechSource());
    }
  }

  void _bindSpeechSource() {
    _ownsSpeechSource = widget.speechSource == null;
    _speechSource = widget.speechSource ?? NativeAssistantSpeechInputSource();
    _speechSubscription = _speechSource.updates.listen(
      _handleSpeechUpdate,
      onError: _handleSpeechError,
    );
  }

  Future<void> _replaceSpeechSource() async {
    _speechEpoch++;
    if (_speechListening || _speechStarting) {
      await _speechSource.cancel();
    }
    await _speechSubscription?.cancel();
    if (_ownsSpeechSource) await _speechSource.dispose();
    if (!mounted) return;
    setState(() {
      _speechListening = false;
      _speechStarting = false;
      _speechTranscript = '';
      _speechLevel = 0;
    });
    _bindSpeechSource();
  }

  void _refreshInput() {
    if (mounted) setState(() {});
  }

  void _handleSpeechUpdate(AssistantSpeechUpdate update) {
    if (!mounted || !_speechListening) return;
    setState(() {
      _speechTranscript = update.transcript;
      _speechLevel = update.level;
    });
  }

  void _handleSpeechError(Object error) {
    if (!mounted || !_speechListening) return;
    final message = error is AssistantSpeechException
        ? error.message
        : '语音识别失败，请重试';
    setState(() {
      _speechListening = false;
      _speechStarting = false;
      _speechLevel = 0;
    });
    widget.onMessage(message);
  }

  Future<void> _startSpeechInput() async {
    if (_submitting || _speechListening || _speechStarting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final request = ++_speechEpoch;
    setState(() {
      _speechListening = true;
      _speechStarting = true;
      _speechTranscript = '';
      _speechLevel = 0.08;
    });
    try {
      await _speechSource.start();
      if (!mounted || request != _speechEpoch) return;
      setState(() => _speechStarting = false);
    } on AssistantSpeechException catch (error) {
      if (!mounted || request != _speechEpoch) return;
      setState(() {
        _speechListening = false;
        _speechStarting = false;
        _speechLevel = 0;
      });
      widget.onMessage(error.message);
    } on Object {
      if (!mounted || request != _speechEpoch) return;
      setState(() {
        _speechListening = false;
        _speechStarting = false;
        _speechLevel = 0;
      });
      widget.onMessage('语音识别失败，请重试');
    }
  }

  Future<void> _finishSpeechInput() async {
    if (!_speechListening && !_speechStarting) return;
    final transcript = _speechTranscript.trim();
    _speechEpoch++;
    setState(() {
      _speechListening = false;
      _speechStarting = false;
      _speechLevel = 0;
    });
    await _speechSource.stop();
    if (!mounted) return;
    if (transcript.isEmpty) {
      widget.onMessage('没有识别到清晰的语音');
      return;
    }
    final current = _inputController.text.trim();
    _inputController.text = current.isEmpty
        ? transcript
        : '$current $transcript';
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
  }

  Future<void> _cancelSpeechInput() async {
    if (!_speechListening && !_speechStarting) return;
    _speechEpoch++;
    setState(() {
      _speechListening = false;
      _speechStarting = false;
      _speechTranscript = '';
      _speechLevel = 0;
    });
    await _speechSource.cancel();
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
    final typedInput = _inputController.text.trim();
    if ((typedInput.isEmpty && _inputFiles.isEmpty) || _submitting) return;
    final input = typedInput.isNotEmpty
        ? typedInput
        : _inputFiles.every((file) => file.isImage)
        ? '请查看并说明这些图片。'
        : '请读取并总结这些附件。';
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
    final files = List<AssistantInputFile>.unmodifiable(_inputFiles);
    final sourceFiles = files
        .map(_AssistantConversationFile.fromInput)
        .toList(growable: false);
    _inputController.clear();
    setState(() {
      _submitting = true;
      _activeConversationTurn = turnIndex;
      _inputFiles.clear();
      _turns.add(
        _AssistantConversationTurn(prompt: input, sourceFiles: sourceFiles),
      );
    });
    try {
      final reply = await conversation.sendAssistantMessage(
        input: input,
        mode: _mode,
        approvals: _approveTool,
        files: files,
      );
      if (!mounted || request != _conversationEpoch) return;
      setState(() {
        if (reply.conversationId != null) {
          _activeConversationId = reply.conversationId;
        }
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: input,
          sourceFiles: sourceFiles,
          response: reply.text,
          artifacts: reply.artifacts,
        );
        _cacheActiveConversationTurns();
      });
    } on Object catch (error) {
      if (!mounted || request != _conversationEpoch) return;
      final message = _friendlyConversationError(error);
      setState(() {
        _turns[turnIndex] = _AssistantConversationTurn(
          prompt: input,
          sourceFiles: sourceFiles,
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
          sourceFiles: turn.sourceFiles,
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
    final artifactKind = _artifactKindForTool(spec.name);
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x660B1220),
      builder: (context) => artifactKind == null
          ? _GenericToolApprovalDialog(spec: spec, call: call)
          : _ArtifactToolApprovalDialog(
              kind: artifactKind,
              displayName: _artifactDisplayName(artifactKind, call),
            ),
    );
    return approved == true
        ? ApprovalDecision.accept
        : ApprovalDecision.decline;
  }

  Future<void> _pickAssistantFiles() async {
    if (_submitting) return;
    try {
      final selected = await widget.fileSource.pickFiles();
      if (!mounted || selected.isEmpty) return;
      final merged = [..._inputFiles, ...selected];
      if (merged.length > maximumAssistantInputFiles) {
        widget.onMessage('一次最多添加 5 个文件');
        return;
      }
      final totalBytes = merged.fold<int>(
        0,
        (total, file) => total + file.bytes.length,
      );
      if (totalBytes > maximumAssistantInputFilesBytes) {
        widget.onMessage('所选文件合计不能超过 20 MB');
        return;
      }
      setState(() {
        _imageMode = false;
        _inputFiles
          ..clear()
          ..addAll(merged);
      });
    } on AssistantFileSelectionException catch (error) {
      if (mounted) widget.onMessage(error.message);
    } on Object {
      if (mounted) widget.onMessage('无法读取所选文件，请重新选择');
    }
  }

  Future<void> _pickAssistantImages() async {
    if (_submitting) return;
    try {
      final selected = await widget.imageSource.pickImages();
      if (!mounted || selected.isEmpty) return;
      final merged = [..._inputFiles, ...selected];
      if (merged.length > maximumAssistantInputFiles) {
        widget.onMessage('图片和文件合计最多添加 5 个');
        return;
      }
      final totalBytes = merged.fold<int>(
        0,
        (total, file) => total + file.bytes.length,
      );
      if (totalBytes > maximumAssistantInputFilesBytes) {
        widget.onMessage('图片和文件合计不能超过 20 MB');
        return;
      }
      setState(() {
        _imageMode = false;
        _inputFiles
          ..clear()
          ..addAll(merged);
      });
    } on AssistantFileSelectionException catch (error) {
      if (mounted) widget.onMessage(error.message);
    } on Object {
      if (mounted) widget.onMessage('无法读取所选图片，请重新选择');
    }
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
        await _pickAssistantImages();
      case _AssistantAddAction.file:
        await _pickAssistantFiles();
      case _AssistantAddAction.generateImage:
        if (widget.images == null) {
          widget.onMessage('当前账号暂时无法使用 AI 生图');
          return;
        }
        setState(() {
          _inputFiles.clear();
          _imageMode = true;
        });
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

  Future<void> _openHistoryDrawer() async {
    final history = widget.history;
    if (history == null) {
      widget.onOpenHistory();
      return;
    }
    await showAssistantHistoryDrawer(
      context: context,
      source: history,
      accountName: widget.accountName,
      activeConversationId: _activeConversationId,
      onSelect: (conversation) async {
        _cacheActiveConversationTurns();
        await history.selectAssistantConversation(conversation.id);
        if (!mounted) return;
        setState(() {
          _activeConversationId = conversation.id;
          _turns
            ..clear()
            ..addAll(
              _turnsByConversation[conversation.id] ??
                  const <_AssistantConversationTurn>[],
            );
          _inputFiles.clear();
          _imageMode = false;
        });
      },
      onNewConversation: () async => _startNewConversation(),
      onDeleted: (conversationId) async {
        _turnsByConversation.remove(conversationId);
        if (_activeConversationId != conversationId || !mounted) return;
        setState(() {
          _activeConversationId = null;
          _turns.clear();
          _inputFiles.clear();
          _imageMode = false;
        });
      },
      onOpenSettings: () => unawaited(_openConversationOptions()),
      onMessage: widget.onMessage,
    );
  }

  Future<void> _openConversationOptions() async {
    final conversationId = _activeConversationId;
    final history = widget.history;
    final option = await showAssistantConversationOptionsSheet(
      context: context,
      hasConversation: conversationId != null && history != null,
    );
    if (!mounted || option == null) return;
    if (conversationId == null || history == null) {
      widget.onMessage('请先发送一条消息');
      return;
    }
    final title = await _loadActiveConversationTitle(history, conversationId);
    if (!mounted) return;
    if (title == null) {
      widget.onMessage('当前对话已不存在');
      return;
    }
    switch (option) {
      case AssistantConversationOption.rename:
        await _renameConversation(history, conversationId, title);
        return;
      case AssistantConversationOption.export:
        await _exportConversation(title);
        return;
      case AssistantConversationOption.clear:
        await _clearConversation(history, conversationId, title);
        return;
      case AssistantConversationOption.delete:
        await _deleteConversation(history, conversationId, title);
        return;
    }
  }

  Future<String?> _loadActiveConversationTitle(
    AssistantConversationHistorySource history,
    String conversationId,
  ) async {
    try {
      final conversations = await history.loadAssistantConversations();
      for (final conversation in conversations) {
        if (conversation.id == conversationId) return conversation.title;
      }
      return null;
    } on Object {
      widget.onMessage('无法加载当前对话，请稍后重试');
      return null;
    }
  }

  Future<void> _renameConversation(
    AssistantConversationHistorySource history,
    String conversationId,
    String title,
  ) async {
    final renamed = await showAssistantConversationRenameDialog(
      context: context,
      currentTitle: title,
    );
    if (!mounted || renamed == null || renamed == title) return;
    try {
      await history.renameAssistantConversation(conversationId, renamed);
      if (mounted) widget.onMessage('对话已重命名');
    } on Object {
      if (mounted) widget.onMessage('重命名失败，请稍后重试');
    }
  }

  Future<void> _exportConversation(String title) async {
    final exportTurns = _turns
        .where((turn) => turn.response != null || turn.error != null)
        .map(
          (turn) => AssistantConversationExportTurn(
            prompt: turn.prompt,
            response: turn.response ?? turn.error ?? '',
            sourceFileNames: turn.sourceFiles
                .map((file) => file.filename)
                .toList(growable: false),
            artifactNames: turn.artifacts
                .map((artifact) => artifact.displayName)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    if (exportTurns.isEmpty) {
      widget.onMessage('当前设备没有可导出的已加载内容');
      return;
    }
    final format = await showAssistantExportFormatSheet(context: context);
    if (!mounted || format == null) return;
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      await widget.conversationExports.export(
        AssistantConversationExportDocument(title: title, turns: exportTurns),
        format: format,
        sharePositionOrigin: origin,
      );
      if (mounted) widget.onMessage('已打开系统保存面板');
    } on AssistantConversationExportException catch (error) {
      if (mounted) widget.onMessage(error.message);
    } on Object {
      if (mounted) widget.onMessage('导出失败，请稍后重试');
    }
  }

  Future<void> _clearConversation(
    AssistantConversationHistorySource history,
    String conversationId,
    String title,
  ) async {
    final confirmed = await confirmAssistantConversationAction(
      context: context,
      action: AssistantConversationOption.clear,
      title: title,
    );
    if (!confirmed || !mounted) return;
    try {
      await history.clearAssistantConversation(conversationId);
      if (!mounted) return;
      setState(() {
        _turns.clear();
        _inputFiles.clear();
        _imageMode = false;
        _turnsByConversation[conversationId] = const [];
      });
      widget.onMessage('当前对话内容已清空');
    } on Object {
      if (mounted) widget.onMessage('清空失败，请稍后重试');
    }
  }

  Future<void> _deleteConversation(
    AssistantConversationHistorySource history,
    String conversationId,
    String title,
  ) async {
    final confirmed = await confirmAssistantConversationAction(
      context: context,
      action: AssistantConversationOption.delete,
      title: title,
    );
    if (!confirmed || !mounted) return;
    try {
      await history.deleteAssistantConversation(conversationId);
      if (!mounted) return;
      setState(() {
        _activeConversationId = null;
        _turnsByConversation.remove(conversationId);
        _turns.clear();
        _inputFiles.clear();
        _imageMode = false;
      });
      widget.onMessage('对话已删除');
    } on Object {
      if (mounted) widget.onMessage('删除失败，请稍后重试');
    }
  }

  void _cacheActiveConversationTurns() {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;
    _turnsByConversation[conversationId] = List.unmodifiable(_turns);
  }

  void _startNewConversation() {
    if (_speechListening || _speechStarting) {
      unawaited(_cancelSpeechInput());
    }
    _cacheActiveConversationTurns();
    widget.conversation?.startNewAssistantConversation();
    setState(() {
      _activeConversationId = null;
      _turns.clear();
      _inputFiles.clear();
      _imageMode = false;
    });
    widget.onNewConversation();
  }

  @override
  void dispose() {
    _speechEpoch++;
    if (_speechListening || _speechStarting) {
      unawaited(_speechSource.cancel());
    }
    final speechSubscription = _speechSubscription;
    if (speechSubscription != null) {
      unawaited(speechSubscription.cancel());
    }
    if (_ownsSpeechSource) unawaited(_speechSource.dispose());
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
                      onOpenHistory: _openHistoryDrawer,
                      onNewConversation: _startNewConversation,
                      onOpenMore: _openConversationOptions,
                    ),
                  ),
                  Expanded(
                    child: _turns.isEmpty
                        ? _speechListening
                              ? _AssistantSpeechEmptyState(
                                  transcript: _speechTranscript,
                                  starting: _speechStarting,
                                )
                              : _AssistantEmptyState(
                                  hasImageAttachments: _inputFiles.any(
                                    (file) => file.isImage,
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
                  if (_inputFiles.any((file) => file.isImage))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(23, 0, 23, 10),
                      child: _AssistantInputImagesBar(
                        files: _inputFiles
                            .where((file) => file.isImage)
                            .toList(growable: false),
                        enabled: !_submitting,
                        onRemove: (file) =>
                            setState(() => _inputFiles.remove(file)),
                      ),
                    ),
                  if (_inputFiles.any((file) => !file.isImage))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(23, 0, 23, 10),
                      child: _AssistantInputFilesBar(
                        files: _inputFiles
                            .where((file) => !file.isImage)
                            .toList(growable: false),
                        enabled: !_submitting,
                        onRemove: (file) =>
                            setState(() => _inputFiles.remove(file)),
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
                  if (_speechListening)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                      child: _AssistantSpeechPanel(
                        starting: _speechStarting,
                        level: _speechLevel,
                        onCancel: _cancelSpeechInput,
                        onFinish: _finishSpeechInput,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
                      child: _Composer(
                        controller: _inputController,
                        submitting: _submitting,
                        imageMode: _imageMode,
                        hasAttachments: _inputFiles.isNotEmpty,
                        onAddAttachment: _showAddTools,
                        onVoiceInput: _startSpeechInput,
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

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({required this.hasImageAttachments});

  final bool hasImageAttachments;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment(0, -0.05),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          key: Key('assistant-greeting-icon'),
          color: Color(0xFF3370FF),
          size: 31,
        ),
        const SizedBox(height: 17),
        const Text(
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
        if (hasImageAttachments) ...[
          const SizedBox(height: 13),
          const Text(
            '你可以发送图片，让助手查看并处理',
            key: Key('assistant-image-help'),
            style: TextStyle(
              color: Color(0xFF8F959E),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    ),
  );
}

class _AssistantSpeechEmptyState extends StatelessWidget {
  const _AssistantSpeechEmptyState({
    required this.transcript,
    required this.starting,
  });

  final String transcript;
  final bool starting;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.05),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFF3370FF),
          size: 31,
        ),
        const SizedBox(height: 17),
        Text(
          starting ? '正在准备…' : '正在聆听…',
          key: const Key('assistant-speech-heading'),
          style: const TextStyle(
            color: Color(0xFF1F2329),
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 13),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            transcript.isEmpty ? '请开始说话' : transcript,
            key: const Key('assistant-speech-transcript'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8F959E),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AssistantSpeechPanel extends StatelessWidget {
  const _AssistantSpeechPanel({
    required this.starting,
    required this.level,
    required this.onCancel,
    required this.onFinish,
  });

  final bool starting;
  final double level;
  final VoidCallback onCancel;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('assistant-speech-panel'),
    height: 208,
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 17),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      children: [
        Text(
          starting ? '正在准备' : '语音输入',
          style: const TextStyle(
            color: Color(0xFF1F2329),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _AssistantSpeechWaveform(level: level),
        const Spacer(),
        Row(
          children: [
            _AssistantSpeechAction(
              key: const Key('assistant-speech-cancel'),
              icon: Icons.close_rounded,
              foreground: const Color(0xFF1F2329),
              background: Colors.white,
              border: const Color(0xFFE1E4E8),
              onTap: onCancel,
            ),
            const Expanded(
              child: Text(
                '说完后点击完成',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8F959E),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            _AssistantSpeechAction(
              key: const Key('assistant-speech-finish'),
              icon: Icons.check_rounded,
              foreground: Colors.white,
              background: const Color(0xFF3370FF),
              border: const Color(0xFF3370FF),
              onTap: onFinish,
            ),
          ],
        ),
      ],
    ),
  );
}

class _AssistantSpeechWaveform extends StatelessWidget {
  const _AssistantSpeechWaveform({required this.level});

  final double level;

  static const _shape = <double>[
    7,
    10,
    17,
    25,
    22,
    28,
    42,
    21,
    14,
    26,
    17,
    20,
    27,
    34,
    20,
    25,
    19,
    13,
    8,
  ];

  @override
  Widget build(BuildContext context) {
    final intensity = 0.5 + level.clamp(0, 1) * 0.5;
    return SizedBox(
      key: const Key('assistant-speech-waveform'),
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final height in _shape)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                width: 4,
                height: (height * intensity).clamp(6, 44),
                decoration: BoxDecoration(
                  color: const Color(0xFF3370FF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantSpeechAction extends StatelessWidget {
  const _AssistantSpeechAction({
    super.key,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: CircleBorder(side: BorderSide(color: border)),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 48,
        child: Icon(icon, color: foreground, size: 26),
      ),
    ),
  );
}

class _ArtifactToolApprovalDialog extends StatelessWidget {
  const _ArtifactToolApprovalDialog({
    required this.kind,
    required this.displayName,
  });

  final AssistantArtifactKind kind;
  final String displayName;

  @override
  Widget build(BuildContext context) => Dialog(
    key: const Key('assistant-artifact-approval-dialog'),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 38),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '允许生成文件？',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1F2329),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 21),
          Container(
            key: const Key('assistant-artifact-approval-file'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _ArtifactIcon(kind: kind),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2329),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kind.label,
                        style: const TextStyle(
                          color: Color(0xFF8F959E),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '文件将保存到当前账号的本地隔离空间。\n内部存储路径不会发送给模型。',
            style: TextStyle(
              color: Color(0xFF646A73),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('assistant-tool-decline'),
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F2329),
                    side: const BorderSide(color: Color(0xFFD9DCE2)),
                    minimumSize: const Size.fromHeight(49),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('assistant-tool-approve'),
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3370FF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(49),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('允许此次'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _GenericToolApprovalDialog extends StatelessWidget {
  const _GenericToolApprovalDialog({required this.spec, required this.call});

  final ToolSpec spec;
  final ToolCall call;

  @override
  Widget build(BuildContext context) => AlertDialog(
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

class _AssistantInputFilesBar extends StatelessWidget {
  const _AssistantInputFilesBar({
    required this.files,
    required this.enabled,
    required this.onRemove,
  });

  final List<AssistantInputFile> files;
  final bool enabled;
  final ValueChanged<AssistantInputFile> onRemove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = files.length == 1
          ? constraints.maxWidth.clamp(0, 245).toDouble()
          : ((constraints.maxWidth - 8) / 2).clamp(172, 205).toDouble();
      return SizedBox(
        key: const Key('assistant-input-files'),
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: files.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final file = files[index];
            return SizedBox(
              width: itemWidth,
              child: Container(
                key: Key('assistant-input-file-$index'),
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE1E4E8)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _AssistantInputFileBadge(
                      key: Key('assistant-input-file-kind-$index'),
                      file: file,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2329),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatArtifactBytes(file.bytes.length),
                            style: const TextStyle(
                              color: Color(0xFF8F959E),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('assistant-input-file-remove-$index'),
                      onPressed: enabled ? () => onRemove(file) : null,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 29,
                        height: 36,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: const Color(0xFF646A73),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _AssistantInputImagesBar extends StatelessWidget {
  const _AssistantInputImagesBar({
    required this.files,
    required this.enabled,
    required this.onRemove,
  });

  final List<AssistantInputFile> files;
  final bool enabled;
  final ValueChanged<AssistantInputFile> onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('assistant-input-images'),
    height: 122,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final file = files[index];
        return SizedBox(
          key: Key('assistant-input-image-$index'),
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE1E4E8)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        file.bytes,
                        key: Key('assistant-input-image-preview-$index'),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFF2F3F5),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF8F959E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Material(
                      color: const Color(0xFF243342),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 2),
                      ),
                      child: InkWell(
                        key: Key('assistant-input-image-remove-$index'),
                        customBorder: const CircleBorder(),
                        onTap: enabled ? () => onRemove(file) : null,
                        child: const SizedBox.square(
                          dimension: 25,
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8F959E),
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AssistantInputFileBadge extends StatelessWidget {
  const _AssistantInputFileBadge({super.key, required this.file});

  final AssistantInputFile file;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _assistantFileBadgeStyle(file.contentType);
    return Container(
      width: 36,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length > 1 ? 10 : 18,
          fontWeight: FontWeight.w700,
          letterSpacing: label.length > 1 ? -0.4 : 0,
        ),
      ),
    );
  }
}

(String, Color) _assistantFileBadgeStyle(String contentType) =>
    switch (contentType) {
      final type
          when type.contains('wordprocessingml') ||
              type == 'application/msword' =>
        ('W', const Color(0xFF3370FF)),
      final type
          when type.contains('spreadsheetml') ||
              type == 'application/vnd.ms-excel' ||
              type == 'text/csv' ||
              type == 'text/tsv' =>
        ('X', const Color(0xFF12A150)),
      final type
          when type.contains('presentationml') ||
              type == 'application/vnd.ms-powerpoint' =>
        ('P', const Color(0xFFF07B3F)),
      'application/pdf' => ('PDF', const Color(0xFFE5484D)),
      _ => ('<>', const Color(0xFF646A73)),
    };

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.submitting,
    required this.imageMode,
    required this.hasAttachments,
    required this.onAddAttachment,
    required this.onVoiceInput,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool submitting;
  final bool imageMode;
  final bool hasAttachments;
  final VoidCallback onAddAttachment;
  final VoidCallback onVoiceInput;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final hasInput = controller.text.trim().isNotEmpty;
    final canSubmit = hasInput || hasAttachments;
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
                  : canSubmit
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
                        canSubmit
                            ? Icons.arrow_upward_rounded
                            : Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: canSubmit ? 25 : 27,
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
    this.sourceFiles = const [],
    this.response,
    this.artifacts = const [],
    this.image,
    this.error,
    this.imageRequest = false,
  });

  final String prompt;
  final List<_AssistantConversationFile> sourceFiles;
  final String? response;
  final List<AssistantGeneratedArtifact> artifacts;
  final AssistantGeneratedImage? image;
  final String? error;
  final bool imageRequest;
}

class _AssistantConversationFile {
  const _AssistantConversationFile({
    required this.filename,
    required this.contentType,
  });

  factory _AssistantConversationFile.fromInput(AssistantInputFile file) =>
      _AssistantConversationFile(
        filename: file.filename,
        contentType: file.contentType,
      );

  final String filename;
  final String contentType;
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
        if (turn.sourceFiles.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (
                  var index = 0;
                  index < turn.sourceFiles.length;
                  index++
                ) ...[
                  _AssistantSentFileCard(
                    key: Key('assistant-sent-file-$index'),
                    file: turn.sourceFiles[index],
                  ),
                  if (index != turn.sourceFiles.length - 1)
                    const SizedBox(height: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
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
            sourceFiles: turn.sourceFiles,
            artifacts: turn.artifacts,
            onPreviewArtifact: onPreviewArtifact,
            onDownloadArtifact: (artifact) =>
                onDownloadArtifact(context, artifact),
          ),
      ],
    );
  }
}

class _AssistantSentFileCard extends StatelessWidget {
  const _AssistantSentFileCard({super.key, required this.file});

  final _AssistantConversationFile file;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _assistantFileBadgeStyle(file.contentType);
    return Container(
      width: 238,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E4E8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            key: Key('assistant-sent-file-kind-${file.filename}'),
            width: 36,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: label.length > 1 ? 10 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: label.length > 1 ? -0.4 : 0,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              file.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
    required this.sourceFiles,
    required this.artifacts,
    required this.onPreviewArtifact,
    required this.onDownloadArtifact,
  });

  final String response;
  final List<_AssistantConversationFile> sourceFiles;
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
                  key: const Key('assistant-response-card'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE1E4E8)),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AssistantResponseBody(response: visibleResponse),
                      if (sourceFiles.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Wrap(
                          key: const Key('assistant-response-sources'),
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final file in sourceFiles)
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 190,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F3F5),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  file.filename,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF646A73),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
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

class _AssistantResponseBody extends StatelessWidget {
  const _AssistantResponseBody({required this.response});

  final String response;

  @override
  Widget build(BuildContext context) {
    final lines = _parseAssistantResponse(response);
    return Column(
      key: const Key('assistant-response-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) SizedBox(height: _assistantResponseGap(lines[index])),
          _AssistantResponseLineView(line: lines[index]),
        ],
      ],
    );
  }
}

enum _AssistantResponseLineKind {
  paragraph,
  heading,
  bullet,
  numbered,
  unchecked,
  checked,
  spacer,
}

class _AssistantResponseLine {
  const _AssistantResponseLine(this.kind, this.text, {this.marker});

  final _AssistantResponseLineKind kind;
  final String text;
  final String? marker;
}

List<_AssistantResponseLine> _parseAssistantResponse(String response) {
  final parsed = <_AssistantResponseLine>[];
  final heading = RegExp(r'^\s*#{1,6}\s+(.+?)\s*$');
  final checkbox = RegExp(r'^\s*(?:[-*]\s+)?\[([ xX])\]\s+(.+?)\s*$');
  final bullet = RegExp(r'^\s*[-*•]\s+(.+?)\s*$');
  final numbered = RegExp(r'^\s*(\d+[.)])\s+(.+?)\s*$');

  for (final raw in response.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      if (parsed.isNotEmpty &&
          parsed.last.kind != _AssistantResponseLineKind.spacer) {
        parsed.add(
          const _AssistantResponseLine(_AssistantResponseLineKind.spacer, ''),
        );
      }
      continue;
    }
    final headingMatch = heading.firstMatch(line);
    if (headingMatch != null) {
      parsed.add(
        _AssistantResponseLine(
          _AssistantResponseLineKind.heading,
          headingMatch.group(1)!,
        ),
      );
      continue;
    }
    final checkboxMatch = checkbox.firstMatch(line);
    if (checkboxMatch != null) {
      parsed.add(
        _AssistantResponseLine(
          checkboxMatch.group(1)!.trim().isEmpty
              ? _AssistantResponseLineKind.unchecked
              : _AssistantResponseLineKind.checked,
          checkboxMatch.group(2)!,
        ),
      );
      continue;
    }
    final bulletMatch = bullet.firstMatch(line);
    if (bulletMatch != null) {
      parsed.add(
        _AssistantResponseLine(
          _AssistantResponseLineKind.bullet,
          bulletMatch.group(1)!,
        ),
      );
      continue;
    }
    final numberedMatch = numbered.firstMatch(line);
    if (numberedMatch != null) {
      parsed.add(
        _AssistantResponseLine(
          _AssistantResponseLineKind.numbered,
          numberedMatch.group(2)!,
          marker: numberedMatch.group(1),
        ),
      );
      continue;
    }
    parsed.add(
      _AssistantResponseLine(_AssistantResponseLineKind.paragraph, line.trim()),
    );
  }
  while (parsed.isNotEmpty &&
      parsed.last.kind == _AssistantResponseLineKind.spacer) {
    parsed.removeLast();
  }
  return parsed;
}

double _assistantResponseGap(_AssistantResponseLine line) =>
    switch (line.kind) {
      _AssistantResponseLineKind.heading => 14,
      _AssistantResponseLineKind.spacer => 0,
      _ => 8,
    };

class _AssistantResponseLineView extends StatelessWidget {
  const _AssistantResponseLineView({required this.line});

  final _AssistantResponseLine line;

  @override
  Widget build(BuildContext context) => switch (line.kind) {
    _AssistantResponseLineKind.heading => Text(
      line.text,
      style: const TextStyle(
        color: Color(0xFF1F2329),
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
    ),
    _AssistantResponseLineKind.bullet => _AssistantResponseListLine(
      marker: const Text(
        '•',
        style: TextStyle(color: Color(0xFF1F2329), fontSize: 18, height: 1.35),
      ),
      text: line.text,
    ),
    _AssistantResponseLineKind.numbered => _AssistantResponseListLine(
      marker: Text(
        line.marker!,
        style: const TextStyle(
          color: Color(0xFF646A73),
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      text: line.text,
    ),
    _AssistantResponseLineKind.unchecked ||
    _AssistantResponseLineKind.checked => _AssistantResponseListLine(
      marker: Icon(
        line.kind == _AssistantResponseLineKind.checked
            ? Icons.check_circle_rounded
            : Icons.circle_outlined,
        color: line.kind == _AssistantResponseLineKind.checked
            ? const Color(0xFF3370FF)
            : const Color(0xFF8F959E),
        size: 20,
      ),
      text: line.text,
    ),
    _AssistantResponseLineKind.spacer => const SizedBox(height: 3),
    _AssistantResponseLineKind.paragraph => Text(
      line.text,
      style: const TextStyle(
        color: Color(0xFF1F2329),
        fontSize: 15,
        height: 1.5,
      ),
    ),
  };
}

class _AssistantResponseListLine extends StatelessWidget {
  const _AssistantResponseListLine({required this.marker, required this.text});

  final Widget marker;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 26, child: Center(child: marker)),
      const SizedBox(width: 2),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1F2329),
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
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

AssistantArtifactKind? _artifactKindForTool(String toolName) =>
    switch (toolName) {
      'daylink_create_word_document' => AssistantArtifactKind.document,
      'daylink_create_spreadsheet' => AssistantArtifactKind.spreadsheet,
      'daylink_create_presentation' => AssistantArtifactKind.presentation,
      _ => null,
    };

String _artifactDisplayName(AssistantArtifactKind kind, ToolCall call) {
  final rawTitle = (call.arguments['title'] as String?)?.trim();
  final title = rawTitle == null || rawTitle.isEmpty ? 'Daylink 文档' : rawTitle;
  final suffix = '.${kind.extension}';
  return title.toLowerCase().endsWith(suffix) ? title : '$title$suffix';
}

String _reasoningLabel(AiReasoningEffort effort) => switch (effort) {
  AiReasoningEffort.low => '低',
  AiReasoningEffort.medium => '中',
  AiReasoningEffort.high => '高',
  AiReasoningEffort.xhigh => '极高',
};
