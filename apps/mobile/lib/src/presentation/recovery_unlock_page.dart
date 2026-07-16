import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

class RecoveryUnlockPage extends StatefulWidget {
  const RecoveryUnlockPage({
    super.key,
    required this.source,
    this.clipboardClearDelay = const Duration(minutes: 2),
  });

  final ContentEncryptionSource source;
  final Duration clipboardClearDelay;

  @override
  State<RecoveryUnlockPage> createState() => _RecoveryUnlockPageState();
}

class _RecoveryUnlockPageState extends State<RecoveryUnlockPage>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _clipboardTimer;
  String? _pastedClipboardValue;
  var _hasInput = false;
  var _busy = false;
  var _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final hasInput = _controller.text.trim().isNotEmpty;
    if (mounted && hasInput != _hasInput) setState(() => _hasInput = hasInput);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldObscure = state != AppLifecycleState.resumed;
    if (shouldObscure) {
      _focusNode.unfocus();
      unawaited(_clearClipboardIfMatching());
    }
    if (mounted && shouldObscure != _obscured) {
      setState(() => _obscured = shouldObscure);
    }
  }

  Future<void> _pasteRecoveryKey() async {
    if (_busy || _obscured) return;
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = value?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) _showMessage('剪贴板中没有恢复密钥');
      return;
    }
    try {
      final decoded = RecoveryKeyCodec.decode(text);
      decoded.fillRange(0, decoded.length, 0);
    } on FormatException {
      if (mounted) _showMessage('剪贴板中的恢复密钥格式不正确');
      return;
    }
    _controller.value = TextEditingValue(
      text: text.toUpperCase(),
      selection: TextSelection.collapsed(offset: text.length),
    );
    _pastedClipboardValue = text;
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(
      widget.clipboardClearDelay,
      () => unawaited(_clearClipboardIfMatching()),
    );
    if (mounted) _showMessage('恢复密钥已粘贴，剪贴板将在 2 分钟后清除');
  }

  Future<void> _clearClipboardIfMatching() async {
    final pasted = _pastedClipboardValue;
    if (pasted == null) return;
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (value?.text == pasted) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } on Object {
      // Clipboard cleanup is best-effort and never logs sensitive contents.
    } finally {
      _pastedClipboardValue = null;
    }
  }

  Future<void> _restore() async {
    if (_busy || _obscured) return;
    _focusNode.unfocus();
    setState(() => _busy = true);
    try {
      await widget.source.restoreWithRecoveryKey(_controller.text);
      if (!mounted) return;
      _controller.clear();
      _clipboardTimer?.cancel();
      unawaited(_clearClipboardIfMatching());
      if (mounted) Navigator.pop(context, true);
    } on ContentEncryptionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('恢复失败，请检查网络后重试');
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
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    unawaited(_clearClipboardIfMatching());
    _controller
      ..removeListener(_onInputChanged)
      ..clear()
      ..dispose();
    _focusNode.dispose();
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
            key: const Key('recovery-unlock-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '恢复加密内容',
            key: Key('recovery-unlock-title'),
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _divider),
          ),
        ),
        body: ListView(
          key: const Key('recovery-unlock-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 49, 24, 42),
          children: [
            const Center(child: _RecoveryUnlockIcon()),
            const SizedBox(height: 17),
            const Text(
              '输入恢复密钥',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              '验证后，将在此设备恢复已同步的加密内容。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 43),
            const Text(
              '恢复密钥',
              style: TextStyle(color: _muted, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 11),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 132,
                    child: _obscured
                        ? const Center(
                            child: Text(
                              '••••-••••-••••-••••',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 15,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                          )
                        : Stack(
                            children: [
                              TextField(
                                key: const Key('recovery-unlock-input'),
                                controller: _controller,
                                focusNode: _focusNode,
                                enabled: !_busy && !_obscured,
                                maxLines: 3,
                                minLines: 3,
                                keyboardType: TextInputType.visiblePassword,
                                textCapitalization:
                                    TextCapitalization.characters,
                                autocorrect: false,
                                enableSuggestions: false,
                                enableIMEPersonalizedLearning: false,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                contextMenuBuilder: (_, _) =>
                                    const SizedBox.shrink(),
                                inputFormatters: const [
                                  _RecoveryKeyInputFormatter(),
                                ],
                                cursorColor: _blue,
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1.5,
                                  height: 1.55,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    30,
                                    31,
                                    30,
                                    18,
                                  ),
                                  counterText: '',
                                ),
                              ),
                              if (!_hasInput)
                                const Positioned(
                                  left: 30,
                                  top: 38,
                                  right: 24,
                                  child: IgnorePointer(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '粘贴或输入恢复密钥',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: 14),
                                        Text(
                                          'XXXX-XXXX-XXXX-XXXX',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 13.5,
                                            fontFamily: 'monospace',
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  SizedBox(
                    height: 57,
                    width: double.infinity,
                    child: TextButton.icon(
                      key: const Key('recovery-unlock-paste'),
                      onPressed: _busy || _obscured ? null : _pasteRecoveryKey,
                      icon: const Icon(Icons.copy_rounded, size: 21),
                      label: const Text('粘贴恢复密钥'),
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.gpp_good_outlined,
                    size: 24,
                    color: _shield,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '仅在此设备上验证',
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '服务器无法读取，也不会保存你的恢复密钥。',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('recovery-unlock-submit'),
                onPressed: _busy || _obscured ? null : _restore,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('验证并恢复'),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '验证失败不会删除本机数据。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.55),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecoveryUnlockIcon extends StatelessWidget {
  const _RecoveryUnlockIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 59,
    height: 49,
    child: Stack(
      children: [
        Positioned(
          left: 2,
          top: 0,
          child: Icon(Icons.key_outlined, size: 45, color: _blue),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(Icons.shield_outlined, size: 25, color: _blue),
        ),
      ],
    ),
  );
}

class _RecoveryKeyInputFormatter extends TextInputFormatter {
  const _RecoveryKeyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > 128 ||
        !RegExp(r'^[A-Za-z2-7\- \t\r\n]*$').hasMatch(newValue.text)) {
      return oldValue;
    }
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper);
  }
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _shield = Color(0xFF8A95AD);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
