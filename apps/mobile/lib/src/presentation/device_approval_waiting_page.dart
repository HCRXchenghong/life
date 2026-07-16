import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

enum DeviceApprovalWaitingResult { completed, useRecoveryKey, cancelled }

class DeviceApprovalWaitingPage extends StatefulWidget {
  const DeviceApprovalWaitingPage({
    super.key,
    required this.source,
    required this.session,
  });

  final DeviceApprovalRecoverySource source;
  final DeviceApprovalWaitingSession session;

  @override
  State<DeviceApprovalWaitingPage> createState() =>
      _DeviceApprovalWaitingPageState();
}

class _DeviceApprovalWaitingPageState extends State<DeviceApprovalWaitingPage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _poller;
  var _checking = false;
  var _acting = false;
  var _active = true;
  DeviceApprovalWaitingStatus _status = DeviceApprovalWaitingStatus.pending;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remaining = _timeRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _startPolling();
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_active == active) return;
    _active = active;
    if (active) {
      _startPolling();
      unawaited(_check());
    } else {
      _poller?.cancel();
      _poller = null;
    }
  }

  void _startPolling() {
    _poller?.cancel();
    if (!_active || _status != DeviceApprovalWaitingStatus.pending) return;
    _poller = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_check()),
    );
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _timeRemaining();
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero &&
        _status == DeviceApprovalWaitingStatus.pending) {
      unawaited(_check());
    }
  }

  Duration _timeRemaining() {
    final difference = widget.session.expiresAt.difference(
      DateTime.now().toUtc(),
    );
    return difference.isNegative ? Duration.zero : difference;
  }

  Future<void> _check() async {
    if (!_active ||
        _checking ||
        _acting ||
        _status != DeviceApprovalWaitingStatus.pending) {
      return;
    }
    _checking = true;
    try {
      final status = await widget.source.checkDeviceApproval(widget.session);
      if (!mounted) return;
      if (status == DeviceApprovalWaitingStatus.completed) {
        _poller?.cancel();
        Navigator.of(context).pop(DeviceApprovalWaitingResult.completed);
        return;
      }
      if (status != _status) {
        setState(() => _status = status);
        if (status != DeviceApprovalWaitingStatus.pending) {
          _poller?.cancel();
          _poller = null;
        }
      }
    } on ContentEncryptionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('暂时无法检查批准状态，将自动重试');
    } finally {
      _checking = false;
    }
  }

  Future<void> _finish(DeviceApprovalWaitingResult result) async {
    if (_acting) return;
    if (_status != DeviceApprovalWaitingStatus.pending) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() => _acting = true);
    try {
      await widget.source.cancelDeviceApproval(widget.session);
      if (mounted) Navigator.of(context).pop(result);
    } on ContentEncryptionException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
      setState(() => _acting = false);
    } on Object {
      if (!mounted) return;
      _showMessage('取消请求失败，请检查网络后重试');
      setState(() => _acting = false);
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
    _ticker?.cancel();
    _poller?.cancel();
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
          key: const Key('approval-waiting-back'),
          onPressed: _acting ? null : () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
        ),
        title: const Text(
          '恢复加密内容',
          key: Key('approval-waiting-title'),
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
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const Key('approval-waiting-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 39, 26, 25),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _DeviceShieldIcon(),
                  const SizedBox(height: 21),
                  const Text(
                    '等待受信设备确认',
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
                    '请在已登录的 Daylink 设备上\n批准此请求。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '验证码',
                      style: TextStyle(color: _muted, fontSize: 14.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('approval-waiting-card'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 17, 18, 20),
                          child: Column(
                            children: [
                              const Text(
                                '请核对两台设备显示一致',
                                style: TextStyle(color: _muted, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.session.verificationCode,
                                key: const Key('approval-waiting-code'),
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 35,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4.3,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: _divider),
                        SizedBox(
                          height: 72,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 17),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.phone_iphone_rounded,
                                  color: _blue,
                                  size: 25,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '这台新设备',
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.session.deviceName,
                                        key: const Key(
                                          'approval-waiting-device',
                                        ),
                                        style: const TextStyle(
                                          color: _muted,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: _blue, size: 17),
                      SizedBox(width: 7),
                      Text(
                        '内容密钥只会加密发送到此设备',
                        style: TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    key: const Key('approval-waiting-status'),
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_status == DeviceApprovalWaitingStatus.pending)
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _blue,
                            ),
                          )
                        else
                          Icon(_statusIcon, size: 20, color: _blue),
                        const SizedBox(width: 10),
                        Text(
                          _statusLabel,
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      key: const Key('approval-waiting-recovery'),
                      onPressed: _acting
                          ? null
                          : () => unawaited(
                              _finish(
                                DeviceApprovalWaitingResult.useRecoveryKey,
                              ),
                            ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('改用恢复密钥'),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextButton(
                    key: const Key('approval-waiting-cancel'),
                    onPressed: _acting
                        ? null
                        : () => unawaited(
                            _finish(DeviceApprovalWaitingResult.cancelled),
                          ),
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      textStyle: const TextStyle(fontSize: 14.5),
                    ),
                    child: _acting
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('取消请求'),
                  ),
                  const Spacer(),
                  Text(
                    '批准请求将在 ${_countdownLabel(_remaining)} 后失效。',
                    key: const Key('approval-waiting-expiry'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  String get _statusLabel => switch (_status) {
    DeviceApprovalWaitingStatus.pending => '等待批准...',
    DeviceApprovalWaitingStatus.completed => '已批准',
    DeviceApprovalWaitingStatus.rejected => '请求已被拒绝',
    DeviceApprovalWaitingStatus.expired => '请求已失效',
  };

  IconData get _statusIcon => switch (_status) {
    DeviceApprovalWaitingStatus.completed => Icons.check_circle_outline,
    DeviceApprovalWaitingStatus.rejected => Icons.block_rounded,
    DeviceApprovalWaitingStatus.expired => Icons.schedule_rounded,
    DeviceApprovalWaitingStatus.pending => Icons.more_horiz,
  };
}

class _DeviceShieldIcon extends StatelessWidget {
  const _DeviceShieldIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 72,
    height: 54,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 5,
          top: 8,
          child: Icon(Icons.phone_iphone_rounded, color: _blue, size: 39),
        ),
        Positioned(
          right: 5,
          top: 8,
          child: Icon(Icons.phone_iphone_rounded, color: _blue, size: 39),
        ),
        Positioned(
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _background,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.shield_outlined, color: _blue, size: 26),
            ),
          ),
        ),
      ],
    ),
  );
}

String _countdownLabel(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 99 * 60 + 59);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
