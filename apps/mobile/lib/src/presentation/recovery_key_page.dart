import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

class RecoveryKeyPage extends StatefulWidget {
  const RecoveryKeyPage({
    super.key,
    required this.source,
    required this.draft,
    this.onAcknowledgeSaved,
    this.clipboardClearDelay = const Duration(minutes: 2),
  });

  final ContentEncryptionSource source;
  final RecoveryKeyDraft draft;
  final Future<void> Function()? onAcknowledgeSaved;
  final Duration clipboardClearDelay;

  @override
  State<RecoveryKeyPage> createState() => _RecoveryKeyPageState();
}

class _RecoveryKeyPageState extends State<RecoveryKeyPage>
    with WidgetsBindingObserver {
  Timer? _clipboardTimer;
  var _busy = false;
  var _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldObscure = state != AppLifecycleState.resumed;
    if (shouldObscure) unawaited(_clearClipboardIfMatching());
    if (mounted && _obscured != shouldObscure) {
      setState(() => _obscured = shouldObscure);
    }
  }

  Future<void> _copyRecoveryKey() async {
    if (_busy || _obscured) return;
    await Clipboard.setData(ClipboardData(text: widget.draft.encodedKey));
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(
      widget.clipboardClearDelay,
      () => unawaited(_clearClipboardIfMatching()),
    );
    if (!mounted) return;
    _showMessage('恢复密钥已复制，剪贴板将在 2 分钟后清除');
  }

  Future<void> _clearClipboardIfMatching() async {
    try {
      final value = await Clipboard.getData(Clipboard.kTextPlain);
      if (value?.text == widget.draft.encodedKey) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } on Object {
      // Clipboard cleanup is best-effort and must never expose the secret.
    }
  }

  Future<void> _acknowledgeSaved() async {
    if (_busy || _obscured) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认已安全保存？'),
        content: const Text('确认后，本页将不再显示恢复密钥。请确保你已离线妥善保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('recovery-key-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认已保存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final acknowledge = widget.onAcknowledgeSaved;
      if (acknowledge == null) {
        await widget.source.acknowledgeRecoveryKeySaved();
      } else {
        await acknowledge();
      }
      _clipboardTimer?.cancel();
      unawaited(_clearClipboardIfMatching());
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('确认失败，恢复密钥仍保留在此设备，请重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  List<String> _recoveryKeyLines() {
    if (_obscured) {
      return const [
        '••••-••••-••••-••••-••••',
        '••••-••••-••••-••••',
        '••••-••••-••••-••••',
      ];
    }
    final groups = widget.draft.encodedKey.split('-');
    if (groups.length < 9) return [widget.draft.encodedKey];
    return [
      groups.take(5).join('-'),
      groups.skip(5).take(4).join('-'),
      groups.skip(9).join('-'),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    unawaited(_clearClipboardIfMatching());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyLines = _recoveryKeyLines();
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
            key: const Key('recovery-key-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '保存恢复密钥',
            key: Key('recovery-key-title'),
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
          key: const Key('recovery-key-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 51, 24, 42),
          children: [
            const Icon(Icons.key_outlined, size: 47, color: _blue),
            const SizedBox(height: 17),
            const Text(
              '保存你的恢复密钥',
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
              '新设备登录时，用它恢复加密内容。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 44),
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
                    height: 127,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var index = 0;
                            index < keyLines.length;
                            index++
                          ) ...[
                            Text(
                              keyLines[index],
                              key: ValueKey('recovery-key-line-$index'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                                letterSpacing: 1.9,
                                height: 1.95,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                      key: const Key('recovery-key-copy'),
                      onPressed: _busy || _obscured ? null : _copyRecoveryKey,
                      icon: const Icon(Icons.copy_rounded, size: 21),
                      label: const Text('复制恢复密钥'),
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
                        '请离线妥善保存',
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '服务器不会保存这串恢复密钥。确认后，本页将不再显示。',
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
                key: const Key('recovery-key-saved'),
                onPressed: _busy || _obscured ? null : _acknowledgeSaved,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: const Color(0xFFD6DCEB),
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
                    : const Text('我已安全保存'),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '遗失恢复密钥和全部受信设备后，加密内容将无法恢复。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _shield = Color(0xFF8A95AD);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
