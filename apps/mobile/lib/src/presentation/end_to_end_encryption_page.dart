import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

typedef RecoveryKeyReadyCallback =
    Future<void> Function(RecoveryKeyDraft draft);
typedef EncryptionUnlockCallback = Future<void> Function();
typedef DeviceApprovalOpenCallback =
    Future<void> Function(TrustedDeviceApprovalRequest request);

class EndToEndEncryptionPage extends StatefulWidget {
  const EndToEndEncryptionPage({
    super.key,
    required this.source,
    required this.onRecoveryKeyReady,
    required this.onOpenUnlock,
    this.onOpenDeviceRecovery,
    this.approvalSource,
    this.onOpenDeviceApproval,
  });

  final ContentEncryptionSource source;
  final RecoveryKeyReadyCallback onRecoveryKeyReady;
  final EncryptionUnlockCallback onOpenUnlock;
  final EncryptionUnlockCallback? onOpenDeviceRecovery;
  final TrustedDeviceApprovalSource? approvalSource;
  final DeviceApprovalOpenCallback? onOpenDeviceApproval;

  @override
  State<EndToEndEncryptionPage> createState() => _EndToEndEncryptionPageState();
}

class _EndToEndEncryptionPageState extends State<EndToEndEncryptionPage> {
  ContentEncryptionState? _state;
  var _loading = true;
  var _busy = false;
  var _generation = 0;
  TrustedDeviceApprovalRequest? _pendingApproval;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final state = await widget.source.loadContentEncryptionState();
      if (!mounted || generation != _generation) return;
      TrustedDeviceApprovalRequest? approval;
      if (state.status == ContentEncryptionSetupStatus.enabled &&
          widget.approvalSource != null) {
        try {
          approval = await widget.approvalSource!.loadPendingDeviceApproval();
        } on Object {
          approval = null;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _state = state;
        _pendingApproval = approval;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      _showMessage('加密状态加载失败，请重试');
    }
  }

  Future<void> _primaryAction() async {
    final status = _state?.status;
    if (_busy ||
        status == null ||
        (status == ContentEncryptionSetupStatus.enabled &&
            _pendingApproval == null)) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (status == ContentEncryptionSetupStatus.enabled) {
        final approval = _pendingApproval;
        final open = widget.onOpenDeviceApproval;
        if (approval != null && open != null) await open(approval);
        if (mounted) await _load();
        return;
      }
      if (status == ContentEncryptionSetupStatus.locked) {
        await (widget.onOpenDeviceRecovery ?? widget.onOpenUnlock)();
        if (!mounted) return;
        await _load();
        return;
      }
      final draft = await widget.source.prepareContentEncryption();
      if (!mounted) return;
      await widget.onRecoveryKeyReady(draft);
      if (!mounted) return;
      await _load();
    } on ContentEncryptionException catch (error) {
      if (!mounted) return;
      if (error.locked) {
        await widget.onOpenUnlock();
        if (mounted) await _load();
        return;
      }
      _showMessage(error.message);
      await _load();
    } on Object {
      if (mounted) _showMessage('开启失败，请检查网络后重试');
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
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _state?.status ?? ContentEncryptionSetupStatus.notConfigured;
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
            key: const Key('e2ee-back'),
            onPressed: () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '端到端加密',
            key: Key('e2ee-title'),
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
          key: const Key('e2ee-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 58, 26, 48),
          children: [
            const Icon(Icons.lock_outline_rounded, size: 47, color: _blue),
            const SizedBox(height: 18),
            const Text(
              '开启端到端加密',
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
              '日程、对话与主机内容会在离开设备前加密。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 50),
            const Text(
              '安全密钥',
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
                  _KeyRow(
                    title: '内容主密钥',
                    subtitle: '仅保存在受信设备中',
                    value: _contentKeyLabel(status),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  _KeyRow(
                    title: '恢复密钥',
                    subtitle: '用于在新设备恢复内容',
                    value: _recoveryKeyLabel(status),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 27),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('e2ee-enable'),
                onPressed:
                    _loading ||
                        _busy ||
                        (status == ContentEncryptionSetupStatus.enabled &&
                            _pendingApproval == null)
                    ? null
                    : _primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor:
                      status == ContentEncryptionSetupStatus.enabled
                      ? _blue.withValues(alpha: 0.55)
                      : const Color(0xFFD6DCEB),
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
                    : Text(
                        status == ContentEncryptionSetupStatus.enabled &&
                                _pendingApproval != null
                            ? '查看新设备请求'
                            : _buttonLabel(status),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '请妥善保存恢复密钥。\n遗失全部受信设备和恢复密钥后，加密内容将无法恢复。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(color: _muted, fontSize: 14)),
        ],
      ),
    ),
  );
}

String _contentKeyLabel(ContentEncryptionSetupStatus status) =>
    switch (status) {
      ContentEncryptionSetupStatus.notConfigured => '未创建',
      ContentEncryptionSetupStatus.recoveryPending ||
      ContentEncryptionSetupStatus.enabled => '已创建',
      ContentEncryptionSetupStatus.locked => '待解锁',
    };

String _recoveryKeyLabel(ContentEncryptionSetupStatus status) =>
    switch (status) {
      ContentEncryptionSetupStatus.notConfigured => '未生成',
      ContentEncryptionSetupStatus.recoveryPending => '待保存',
      ContentEncryptionSetupStatus.enabled => '已保存',
      ContentEncryptionSetupStatus.locked => '可用于解锁',
    };

String _buttonLabel(ContentEncryptionSetupStatus status) => switch (status) {
  ContentEncryptionSetupStatus.notConfigured => '开启并生成恢复密钥',
  ContentEncryptionSetupStatus.recoveryPending => '继续保存恢复密钥',
  ContentEncryptionSetupStatus.enabled => '已开启',
  ContentEncryptionSetupStatus.locked => '通过受信设备恢复',
};

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
