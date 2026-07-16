import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

class TrustedDeviceApprovalPage extends StatefulWidget {
  const TrustedDeviceApprovalPage({
    super.key,
    required this.source,
    required this.request,
  });

  final TrustedDeviceApprovalSource source;
  final TrustedDeviceApprovalRequest request;

  @override
  State<TrustedDeviceApprovalPage> createState() =>
      _TrustedDeviceApprovalPageState();
}

class _TrustedDeviceApprovalPageState extends State<TrustedDeviceApprovalPage> {
  Timer? _expiryTimer;
  var _busy = false;

  bool get _expired => widget.request.expired;

  @override
  void initState() {
    super.initState();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _expired) setState(() {});
    });
  }

  Future<void> _approve() async {
    if (_busy || _expired) return;
    setState(() => _busy = true);
    try {
      await widget.source.approveDevice(widget.request);
      if (mounted) Navigator.pop(context, true);
    } on ContentEncryptionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('批准失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy || _expired) return;
    setState(() => _busy = true);
    try {
      await widget.source.rejectDevice(widget.request);
      if (mounted) Navigator.pop(context, false);
    } on ContentEncryptionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('拒绝失败，请稍后重试');
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
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
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
            key: const Key('device-approval-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '批准新设备',
            key: Key('device-approval-title'),
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
          key: const Key('device-approval-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 43, 26, 38),
          children: [
            const _DeviceShieldIcon(),
            const SizedBox(height: 24),
            const Text(
              '允许这台新设备？',
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
              '批准后，它可以恢复你的加密内容。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 42),
            const Text(
              '新设备',
              style: TextStyle(
                color: _section,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 11),
            Container(
              key: const Key('device-approval-card'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 91,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            color: _section,
                            size: 36,
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.request.deviceName,
                                  key: const Key('device-approval-device'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _activityLabel(widget.request),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  SizedBox(
                    height: 117,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '验证码',
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          widget.request.verificationCode,
                          key: const Key('device-approval-code'),
                          style: const TextStyle(
                            color: _code,
                            fontSize: 31,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 8,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 27),
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: _section, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请核对两台设备验证码一致',
                    style: TextStyle(color: _body, fontSize: 14.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 55),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('device-approval-confirm'),
                onPressed: _busy || _expired ? null : _approve,
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
                    : const Text('确认并批准'),
              ),
            ),
            const SizedBox(height: 9),
            TextButton(
              key: const Key('device-approval-reject'),
              onPressed: _busy || _expired ? null : _reject,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('拒绝'),
            ),
            const SizedBox(height: 40),
            Text(
              _expired ? '批准请求已失效。' : '批准请求将在 10 分钟后失效。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeviceShieldIcon extends StatelessWidget {
  const _DeviceShieldIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 54,
    child: Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.phone_iphone_rounded, color: _blue, size: 43),
          Positioned(
            right: -11,
            bottom: -3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _background,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: _blue,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _activityLabel(TrustedDeviceApprovalRequest request) {
  final prefix = request.locationLabel?.trim();
  return prefix == null || prefix.isEmpty ? '刚刚申请' : '$prefix · 刚刚申请';
}

const _background = Color(0xFFF7F8FA);
const _blue = Color(0xFF3370FF);
const _text = Color(0xFF15171A);
const _body = Color(0xFF3B3F49);
const _muted = Color(0xFF8A92A6);
const _section = Color(0xFF68728A);
const _code = Color(0xFF3F4A66);
const _divider = Color(0xFFE5E8EF);
const _cardBorder = Color(0xFFDDE2EC);
