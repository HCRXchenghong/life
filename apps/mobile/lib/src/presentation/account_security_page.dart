import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_authentication.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({
    super.key,
    required this.username,
    required this.authentication,
    required this.onChangePassword,
    required this.onSessionRejected,
  });

  final String username;
  final AppAuthentication authentication;
  final VoidCallback onChangePassword;
  final Future<void> Function() onSessionRejected;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  List<AppDeviceSession> _devices = const [];
  var _loading = true;
  var _loadFailed = false;
  var _revoking = false;
  var _generation = 0;

  bool get _hasOtherDevices => _devices.any((device) => !device.current);

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
      final devices = await widget.authentication.loadDeviceSessions();
      if (!mounted || generation != _generation) return;
      setState(() {
        _devices = devices;
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

  Future<void> _confirmRevokeOthers() async {
    if (_revoking || !_hasOtherDevices) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出其他设备？'),
        content: const Text('其他设备将立即失去访问权限，当前设备保持登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('security-revoke-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _revoking = true);
    try {
      await widget.authentication.revokeOtherDeviceSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('其他设备已退出'),
          ),
        );
      await _load();
    } on AppAuthenticationException catch (error) {
      if (!mounted) return;
      if (error.sessionRejected) {
        await widget.onSessionRejected();
        return;
      }
      _showError(error.message);
    } on Object {
      if (mounted) _showError('退出其他设备失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  void _showError(String message) {
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
          key: const Key('security-back'),
          onPressed: () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
        ),
        title: const Text(
          '账号与安全',
          key: Key('security-title'),
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
        color: _primary,
        onRefresh: _load,
        child: ListView(
          key: const Key('security-scroll'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 48),
          children: [
            const _SectionLabel('账号'),
            const SizedBox(height: 12),
            _AccountCard(
              username: widget.username,
              onChangePassword: widget.onChangePassword,
            ),
            const SizedBox(height: 29),
            const _SectionLabel('登录设备'),
            const SizedBox(height: 12),
            _DeviceCard(
              devices: _devices,
              loading: _loading,
              failed: _loadFailed,
              onRetry: _load,
            ),
            const SizedBox(height: 13),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '移除设备后，该设备将立即退出登录。',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
              ),
            ),
            const SizedBox(height: 27),
            Center(
              child: TextButton(
                key: const Key('security-revoke-others'),
                onPressed: _loading || _revoking || !_hasOtherDevices
                    ? null
                    : _confirmRevokeOthers,
                style: TextButton.styleFrom(
                  foregroundColor: _danger,
                  disabledForegroundColor: const Color(0xFFB8BCC4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _revoking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          color: _danger,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('退出其他设备'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w400,
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.username, required this.onChangePassword});

  final String username;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) => _OutlinedCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('用户名', style: _rowTitleStyle),
                const Spacer(),
                Flexible(
                  child: Text(
                    username,
                    key: const Key('security-username'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: _divider,
        ),
        InkWell(
          key: const Key('security-change-password'),
          onTap: onChangePassword,
          child: const SizedBox(
            height: 66,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('修改密码', style: _rowTitleStyle),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 25, color: _muted),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.devices,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final List<AppDeviceSession> devices;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _OutlinedCard(
        child: SizedBox(
          height: 166,
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
          ),
        ),
      );
    }
    if (failed) {
      return _OutlinedCard(
        child: SizedBox(
          height: 132,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '暂时无法读取登录设备',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    return _OutlinedCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < devices.length; index++) ...[
            _DeviceRow(device: devices[index]),
            if (index != devices.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: _divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final AppDeviceSession device;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: Key('security-device-${device.id}'),
    height: 84,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 36,
            child: Icon(Icons.phone_iphone_rounded, size: 29, color: _muted),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _activityLabel(device),
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (device.current)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '当前设备',
                style: TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right_rounded, size: 25, color: _muted),
        ],
      ),
    ),
  );
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _border),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

String _activityLabel(AppDeviceSession device) {
  if (device.current) return '当前设备 · 刚刚活跃';
  final value = device.lastSeenAt.toLocal();
  final now = DateTime.now();
  final delta = now.difference(value);
  if (!delta.isNegative && delta < const Duration(minutes: 2)) {
    return '刚刚活跃';
  }
  if (value.year == now.year) return '${value.month}月${value.day}日活跃';
  return '${value.year}年${value.month}月${value.day}日活跃';
}

const _background = Color(0xFFF8F9FB);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _primary = Color(0xFF1677FF);
const _danger = Color(0xFFE5484D);
const _border = Color(0xFFD9DCE1);
const _divider = Color(0xFFE8EAED);
const _rowTitleStyle = TextStyle(
  color: _text,
  fontSize: 16,
  fontWeight: FontWeight.w400,
);
