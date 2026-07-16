import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.onOpenTrustedDevices,
  });

  final ContentEncryptionSource source;
  final RecoveryKeyReadyCallback onRecoveryKeyReady;
  final EncryptionUnlockCallback onOpenUnlock;
  final EncryptionUnlockCallback? onOpenDeviceRecovery;
  final TrustedDeviceApprovalSource? approvalSource;
  final DeviceApprovalOpenCallback? onOpenDeviceApproval;
  final VoidCallback? onOpenTrustedDevices;

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
        body: status == ContentEncryptionSetupStatus.enabled
            ? _EnabledEncryptionBody(
                busy: _busy,
                pendingApproval: _pendingApproval != null,
                onOpenApproval: _primaryAction,
                onOpenTrustedDevices: widget.onOpenTrustedDevices,
              )
            : _EncryptionSetupBody(
                loading: _loading,
                busy: _busy,
                status: status,
                onPrimaryAction: _primaryAction,
              ),
      ),
    );
  }
}

class _EnabledEncryptionBody extends StatelessWidget {
  const _EnabledEncryptionBody({
    required this.busy,
    required this.pendingApproval,
    required this.onOpenApproval,
    this.onOpenTrustedDevices,
  });

  final bool busy;
  final bool pendingApproval;
  final VoidCallback onOpenApproval;
  final VoidCallback? onOpenTrustedDevices;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const Key('e2ee-scroll'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 31),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 79),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ShieldLockIcon(),
              const SizedBox(height: 27),
              const Text(
                '端到端加密已开启',
                key: Key('e2ee-enabled-heading'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                '日程、对话与主机内容会在\n离开设备前加密。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 43),
              const _SectionLabel('安全密钥'),
              const SizedBox(height: 11),
              Container(
                key: const Key('e2ee-enabled-key-card'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Column(
                  children: [
                    _KeyRow(
                      title: '内容主密钥',
                      subtitle: '仅保存在受信设备中',
                      value: '已保护',
                      showChevron: true,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 17),
                      child: Divider(height: 1, thickness: 1, color: _divider),
                    ),
                    _KeyRow(
                      title: '恢复密钥',
                      subtitle: '用于在新设备恢复内容',
                      value: '已保存',
                      showChevron: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const _SectionLabel('受信设备'),
              const SizedBox(height: 11),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('e2ee-current-device'),
                  onTap: onOpenTrustedDevices,
                  child: SizedBox(
                    height: 76,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            color: _blue,
                            size: 31,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '这台设备',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentDeviceLabel(),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: _blue),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text(
                              '受信',
                              style: TextStyle(color: _blue, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (pendingApproval) ...[
                const SizedBox(height: 15),
                SizedBox(
                  height: 45,
                  child: OutlinedButton(
                    key: const Key('e2ee-enable'),
                    onPressed: busy ? null : onOpenApproval,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _blue,
                            ),
                          )
                        : const Text('查看新设备请求'),
                  ),
                ),
              ],
              const SizedBox(height: 37),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: _muted, size: 19),
                  SizedBox(width: 7),
                  Text(
                    '加密保护在此设备上正常工作',
                    style: TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EncryptionSetupBody extends StatelessWidget {
  const _EncryptionSetupBody({
    required this.loading,
    required this.busy,
    required this.status,
    required this.onPrimaryAction,
  });

  final bool loading;
  final bool busy;
  final ContentEncryptionSetupStatus status;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) => ListView(
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
      const _SectionLabel('安全密钥'),
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
          onPressed: loading || busy ? null : onPrimaryAction,
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
          child: busy
              ? const SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(_buttonLabel(status)),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        '请妥善保存恢复密钥。\n遗失全部受信设备和恢复密钥后，加密内容将无法恢复。',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12.5, height: 1.55),
      ),
    ],
  );
}

class _ShieldLockIcon extends StatelessWidget {
  const _ShieldLockIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.shield_outlined, color: _blue, size: 72),
        Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.lock_outline_rounded, color: _blue, size: 31),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF646A73),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.title,
    required this.subtitle,
    required this.value,
    this.showChevron = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final bool showChevron;

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
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 23),
          ],
        ],
      ),
    ),
  );
}

String _currentDeviceLabel() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'Daylink iPhone',
  TargetPlatform.android => 'Daylink Android',
  _ => 'Daylink 设备',
};

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
