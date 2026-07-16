import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_authentication.dart';

class TrustedDeviceDetailsPage extends StatefulWidget {
  const TrustedDeviceDetailsPage({
    super.key,
    required this.device,
    required this.authentication,
    required this.onSessionRejected,
  });

  final AppDeviceSession device;
  final AppAuthentication authentication;
  final Future<void> Function() onSessionRejected;

  @override
  State<TrustedDeviceDetailsPage> createState() =>
      _TrustedDeviceDetailsPageState();
}

class _TrustedDeviceDetailsPageState extends State<TrustedDeviceDetailsPage> {
  var _busy = false;

  Future<void> _confirmRevoke() async {
    if (_busy || widget.device.current || !widget.device.trusted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('撤销 ${widget.device.name}？'),
        content: const Text('该设备将立即退出并停止同步。再次使用时，需要重新登录并恢复加密内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('trusted-device-revoke-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.authentication.revokeDeviceSession(widget.device.id);
      if (mounted) Navigator.of(context).pop(true);
    } on AppAuthenticationException catch (error) {
      if (!mounted) return;
      if (error.sessionRejected) {
        await widget.onSessionRejected();
        return;
      }
      _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('撤销设备失败，请稍后重试');
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
            key: const Key('trusted-device-details-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '设备详情',
            key: Key('trusted-device-details-title'),
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
            key: const Key('trusted-device-details-scroll'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 51, 24, 31),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 82,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _deviceIcon(widget.device.name),
                      color: _blue,
                      size: 66,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.device.name,
                      key: const Key('trusted-device-details-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _blue),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          '受信设备',
                          style: TextStyle(color: _blue, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      '设备信息',
                      style: TextStyle(
                        color: Color(0xFF646A73),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Container(
                      key: const Key('trusted-device-details-card'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        children: [
                          const _InfoRow(label: '受信状态', value: '可以同步加密内容'),
                          const _CardDivider(),
                          _InfoRow(
                            label: '上次活跃',
                            value: _dateLabel(widget.device.lastSeenAt),
                          ),
                          const _CardDivider(),
                          _InfoRow(
                            label: '首次登录',
                            value: _dateLabel(widget.device.createdAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 55),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        key: const Key('trusted-device-details-revoke'),
                        onPressed: _busy ? null : _confirmRevoke,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _danger,
                          disabledForegroundColor: _danger.withValues(
                            alpha: 0.55,
                          ),
                          side: const BorderSide(color: _danger),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _danger,
                                ),
                              )
                            : const Text('撤销此设备'),
                      ),
                    ),
                    const SizedBox(height: 38),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: _muted, size: 19),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '撤销后，该设备将立即退出并停止同步',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 17),
    child: Divider(height: 1, thickness: 1, color: _divider),
  );
}

IconData _deviceIcon(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('mac') ||
      normalized.contains('windows') ||
      normalized.contains('ubuntu') ||
      normalized.contains('laptop')) {
    return Icons.laptop_mac_rounded;
  }
  if (normalized.contains('ipad') || normalized.contains('tablet')) {
    return Icons.tablet_mac_rounded;
  }
  return Icons.phone_iphone_rounded;
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '今天 $time';
  }
  if (local.year == now.year) {
    return '${local.month}月${local.day}日 $time';
  }
  return '${local.year}年${local.month}月${local.day}日 $time';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _danger = Color(0xFFE5484D);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
