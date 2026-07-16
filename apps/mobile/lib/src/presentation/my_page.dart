import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/assistant_settings.dart';
import '../data/ai_gateway_client.dart';
import 'app_navigation.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.username,
    required this.source,
    required this.onOpenAccount,
    required this.onOpenNotifications,
    required this.onOpenSync,
    required this.onLogout,
    required this.onDestinationSelected,
  });

  final String username;
  final AccountEntitlementSource source;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSync;
  final Future<void> Function() onLogout;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  AiEntitlement? _entitlement;
  var _loading = true;
  var _loadFailed = false;
  var _loggingOut = false;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant MyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final entitlement = await widget.source.loadAccountEntitlement();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _entitlement = entitlement;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFF3370FF),
                onRefresh: _load,
                child: SingleChildScrollView(
                  key: const Key('my-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 27, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '我的',
                        key: Key('my-title'),
                        style: TextStyle(
                          color: Color(0xFF1F2329),
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.1,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        '账号、套餐与偏好',
                        style: TextStyle(
                          color: Color(0xFF8F959E),
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _AccountCard(
                        username: widget.username,
                        planLabel: _badgeLabel(),
                        onTap: widget.onOpenAccount,
                      ),
                      const SizedBox(height: 25),
                      const _SectionLabel('AI 用量'),
                      const SizedBox(height: 12),
                      _UsageCard(
                        entitlement: _entitlement,
                        loading: _loading,
                        loadFailed: _loadFailed,
                        onRetry: _load,
                      ),
                      const SizedBox(height: 25),
                      const _SectionLabel('设置'),
                      const SizedBox(height: 12),
                      _SettingsGroup(
                        onOpenAccount: widget.onOpenAccount,
                        onOpenNotifications: widget.onOpenNotifications,
                        onOpenSync: widget.onOpenSync,
                      ),
                      const SizedBox(height: 18),
                      Align(
                        child: TextButton(
                          key: const Key('my-logout'),
                          onPressed: _loggingOut ? null : _logout,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE84C4C),
                            disabledForegroundColor: const Color(0xFFB8BCC4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: _loggingOut
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '退出登录',
                                  style: TextStyle(fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          DaylinkBottomNavigation(
            currentDestination: AppDestination.me,
            onSelected: widget.onDestinationSelected,
          ),
        ],
      ),
    ),
  );

  String _badgeLabel() {
    if (_loading) return '获取中';
    if (_loadFailed) return '暂不可用';
    final entitlement = _entitlement;
    if (entitlement == null || entitlement.plan == null) return '无套餐';
    if (!entitlement.active) return '已到期';
    return '${_planName(entitlement.plan)} 套餐';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF646A73),
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.username,
    required this.planLabel,
    required this.onTap,
  });

  final String username;
  final String planLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFD9DCE1)),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const Key('my-account'),
      onTap: onTap,
      child: SizedBox(
        height: 70,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF3370FF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _avatarLabel(username),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '已安全登录',
                      style: TextStyle(
                        color: Color(0xFF8F959E),
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 92),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  planLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3370FF),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF8F959E),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.entitlement,
    required this.loading,
    required this.loadFailed,
    required this.onRetry,
  });

  final AiEntitlement? entitlement;
  final bool loading;
  final bool loadFailed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD9DCE1)),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title(),
                    key: const Key('my-plan-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _expiryLabel(),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF8F959E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2)),
        SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
            child: loadFailed
                ? Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '额度加载失败',
                          key: Key('my-usage-error'),
                          style: TextStyle(
                            color: Color(0xFF646A73),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(onPressed: onRetry, child: const Text('重试')),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '本月额度',
                            style: TextStyle(
                              color: Color(0xFF1F2329),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _usageLabel(),
                            key: const Key('my-monthly-usage'),
                            style: const TextStyle(
                              color: Color(0xFF646A73),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: _progress(),
                          color: const Color(0xFF3370FF),
                          backgroundColor: const Color(0xFFEDEFF2),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );

  String _title() {
    if (loading) return '正在获取套餐';
    final current = entitlement;
    if (current?.plan == null) return '暂无套餐';
    return '${_planName(current!.plan)} 套餐';
  }

  String _expiryLabel() {
    if (loading || loadFailed) return '';
    final current = entitlement;
    final expiresAt = current?.expiresAt;
    if (expiresAt == null) return '';
    final date = expiresAt.toLocal();
    final prefix = current!.active ? '有效至' : '已于';
    final suffix = current.active ? '' : '到期';
    return '$prefix ${date.year}年${date.month}月${date.day}日$suffix';
  }

  String _usageLabel() {
    if (loading) return '正在加载';
    final current = entitlement;
    if (current == null || !current.active) return '未开通';
    if (current.unlimited) return '无限额';
    final limit = current.monthlyLimit;
    if (limit == null || limit < 1) return '未配置';
    return '${_tokensInYi(current.monthlyUsed)} / ${_tokensInYi(limit)} 亿 Token';
  }

  double? _progress() {
    if (loading || loadFailed) return null;
    final current = entitlement;
    if (current == null || !current.active || current.unlimited) return 0;
    final limit = current.monthlyLimit;
    if (limit == null || limit < 1) return 0;
    return (current.monthlyUsed / limit).clamp(0, 1).toDouble();
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.onOpenAccount,
    required this.onOpenNotifications,
    required this.onOpenSync,
  });

  final VoidCallback onOpenAccount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFD9DCE1)),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsRow(
          key: const Key('my-security'),
          icon: Icons.admin_panel_settings_outlined,
          title: '账号与安全',
          subtitle: '密码与登录设备',
          onTap: onOpenAccount,
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2)),
        _SettingsRow(
          key: const Key('my-notifications'),
          icon: Icons.notifications_none_rounded,
          title: '通知设置',
          subtitle: '日程提醒',
          onTap: onOpenNotifications,
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2)),
        _SettingsRow(
          key: const Key('my-sync'),
          icon: Icons.cloud_sync_outlined,
          title: '数据与同步',
          subtitle: '已同步',
          onTap: onOpenSync,
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 65,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 30,
              child: Icon(icon, size: 25, color: const Color(0xFF646A73)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2329),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8F959E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFF8F959E),
            ),
          ],
        ),
      ),
    ),
  );
}

String _avatarLabel(String username) {
  final normalized = username.trim();
  return normalized.isEmpty ? 'D' : normalized.substring(0, 1).toUpperCase();
}

String _planName(String? plan) => switch (plan) {
  'plus' => 'Plus',
  'pro' => 'Pro',
  'max' => 'Max',
  _ => '未知',
};

String _tokensInYi(int tokens) {
  final safe = tokens < 0 ? 0 : tokens;
  const unit = 100000000;
  final whole = safe ~/ unit;
  final remainder = safe % unit;
  if (remainder == 0) return '$whole';
  final fraction = remainder
      .toString()
      .padLeft(8, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole.$fraction';
}
