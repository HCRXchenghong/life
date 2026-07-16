import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_authentication.dart';

class TrustedDevicesPage extends StatefulWidget {
  const TrustedDevicesPage({
    super.key,
    required this.authentication,
    required this.onSessionRejected,
  });

  final AppAuthentication authentication;
  final Future<void> Function() onSessionRejected;

  @override
  State<TrustedDevicesPage> createState() => _TrustedDevicesPageState();
}

class _TrustedDevicesPageState extends State<TrustedDevicesPage> {
  List<AppDeviceSession> _devices = const [];
  var _loading = true;
  var _loadFailed = false;
  String? _revokingId;
  var _generation = 0;

  AppDeviceSession? get _currentDevice {
    for (final device in _devices) {
      if (device.current) return device;
    }
    return null;
  }

  List<AppDeviceSession> get _otherDevices =>
      _devices.where((device) => !device.current).toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final sessions = await widget.authentication.loadDeviceSessions();
      final trusted = sessions.where((device) => device.trusted).toList();
      if (trusted.where((device) => device.current).length != 1) {
        throw const FormatException();
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _devices = List.unmodifiable(trusted);
        _loading = false;
      });
    } on AppAuthenticationException catch (error) {
      if (!mounted || generation != _generation) return;
      if (error.sessionRejected) {
        await widget.onSessionRejected();
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _confirmRevoke(AppDeviceSession device) async {
    if (_revokingId != null || device.current || !device.trusted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('撤销 ${device.name}？'),
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
    setState(() => _revokingId = device.id);
    try {
      await widget.authentication.revokeDeviceSession(device.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('设备已撤销'),
          ),
        );
      await _load();
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
      if (mounted) setState(() => _revokingId = null);
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
          key: const Key('trusted-devices-back'),
          onPressed: () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
        ),
        title: const Text(
          '受信设备',
          key: Key('trusted-devices-title'),
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
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const Key('trusted-devices-scroll'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(24, 31, 24, 31),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 62,
              ),
              child: IntrinsicHeight(
                child: _loading
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _blue,
                          ),
                        ),
                      )
                    : _loadFailed
                    ? _LoadFailure(onRetry: _load)
                    : _TrustedDeviceContent(
                        currentDevice: _currentDevice!,
                        otherDevices: _otherDevices,
                        revokingId: _revokingId,
                        onRevoke: _confirmRevoke,
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrustedDeviceContent extends StatelessWidget {
  const _TrustedDeviceContent({
    required this.currentDevice,
    required this.otherDevices,
    required this.revokingId,
    required this.onRevoke,
  });

  final AppDeviceSession currentDevice;
  final List<AppDeviceSession> otherDevices;
  final String? revokingId;
  final ValueChanged<AppDeviceSession> onRevoke;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '这些设备可以解密并同步你的加密内容。',
        style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 39),
      const _SectionLabel('当前设备'),
      const SizedBox(height: 11),
      _DeviceCard(
        child: _DeviceRow(
          device: currentDevice,
          current: true,
          revoking: false,
        ),
      ),
      const SizedBox(height: 34),
      const _SectionLabel('其他设备'),
      const SizedBox(height: 11),
      if (otherDevices.isEmpty)
        const _DeviceCard(
          child: SizedBox(
            height: 82,
            child: Center(
              child: Text(
                '暂无其他受信设备',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
            ),
          ),
        )
      else
        _DeviceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < otherDevices.length; index++) ...[
                _DeviceRow(
                  device: otherDevices[index],
                  current: false,
                  revoking: revokingId == otherDevices[index].id,
                  onTap: revokingId == null
                      ? () => onRevoke(otherDevices[index])
                      : null,
                ),
                if (index != otherDevices.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 17,
                    endIndent: 17,
                    color: _divider,
                  ),
              ],
            ],
          ),
        ),
      const SizedBox(height: 81),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: _muted, size: 19),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              '撤销设备后，该设备将立即退出并停止同步',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
      const Spacer(),
    ],
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _cardBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.current,
    required this.revoking,
    this.onTap,
  });

  final AppDeviceSession device;
  final bool current;
  final bool revoking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('trusted-device-${device.id}'),
    onTap: onTap,
    child: SizedBox(
      height: current ? 76 : 82,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 33,
              child: Icon(_deviceIcon(device.name), color: _blue, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current ? '这台设备' : device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    current
                        ? '${device.name} · 当前使用'
                        : '上次活跃 ${_lastSeenLabel(device.lastSeenAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (current)
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
                  '当前',
                  style: TextStyle(color: _blue, fontSize: 14),
                ),
              )
            else if (revoking)
              const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 25),
          ],
        ),
      ),
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

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('暂时无法读取受信设备', style: TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
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

String _lastSeenLabel(DateTime value) {
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
