import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/data_sync_models.dart';

class DataSyncPage extends StatefulWidget {
  const DataSyncPage({
    super.key,
    required this.source,
    required this.onOpenEncryption,
  });

  final DataSyncSource source;
  final VoidCallback onOpenEncryption;

  @override
  State<DataSyncPage> createState() => _DataSyncPageState();
}

class _DataSyncPageState extends State<DataSyncPage>
    with WidgetsBindingObserver {
  DataSyncState? _state;
  var _loading = true;
  var _busy = false;
  var _syncing = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final state = await widget.source.loadDataSyncState();
      if (!mounted || generation != _generation) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      _showMessage('同步状态加载失败，请重试');
    }
  }

  Future<void> _setAutoSync(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _syncing = enabled;
    });
    try {
      final state = await widget.source.setAutoSyncEnabled(enabled);
      if (mounted) setState(() => _state = state);
    } on Object {
      if (mounted) {
        await _load(silent: true);
        _showMessage(enabled ? '已开启自动同步，将在网络恢复后重试' : '保存失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _syncing = true;
    });
    try {
      final state = await widget.source.syncNow();
      if (!mounted) return;
      setState(() => _state = state);
      _showMessage(
        state.encryptionStatus == DataEncryptionStatus.unlocked
            ? '同步完成'
            : '加密数据已同步，解锁后即可恢复',
      );
    } on Object {
      if (mounted) _showMessage('同步失败，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _showSyncRange() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _InfoSheet(
      title: '同步范围',
      body: '日程与提醒、助手对话、主机配置及相关设置。SSH 密码、私钥和 API Key 不作为普通内容上传。',
    ),
  );

  Future<void> _manageCache() async {
    final state = _state;
    if (state == null || _busy) return;
    final clear = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CacheSheet(state: state),
    );
    if (clear != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除同步缓存？'),
        content: const Text('只会清除已下载的加密变更，不会删除本机日程、对话或主机。下次同步会重新下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('sync-cache-clear-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final state = await widget.source.clearLocalSyncCache();
      if (!mounted) return;
      setState(() => _state = state);
      _showMessage('同步缓存已清除');
    } on Object {
      if (mounted) _showMessage('清除失败，请重试');
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final interactive = !_loading && !_busy && state != null;
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
            key: const Key('data-sync-back'),
            onPressed: () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '数据与同步',
            key: Key('data-sync-title'),
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
          key: const Key('data-sync-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 27, 24, 48),
          children: [
            const _SectionLabel('同步'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('sync-auto'),
                  title: '自动同步',
                  subtitle: '在已登录设备间保持数据最新',
                  trailing: _SettingsSwitch(
                    value: state?.autoSyncEnabled ?? true,
                    enabled: interactive,
                    onChanged: _setAutoSync,
                  ),
                ),
                const _CardDivider(),
                _SettingsRow(
                  key: const Key('sync-now'),
                  title: '立即同步',
                  onTap: interactive ? _syncNow : null,
                  trailing: _ValueChevron(
                    value: _syncing
                        ? '同步中'
                        : _formatLastSynced(state?.lastSyncedAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 29),
            const _SectionLabel('数据'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('sync-range'),
                  title: '同步范围',
                  onTap: interactive ? _showSyncRange : null,
                  trailing: const _ValueChevron(
                    value: '日程、对话与主机',
                    emphasize: false,
                  ),
                ),
                const _CardDivider(),
                _SettingsRow(
                  key: const Key('sync-cache'),
                  title: '本地缓存',
                  onTap: interactive ? _manageCache : null,
                  trailing: const _ValueChevron(value: '管理'),
                ),
              ],
            ),
            const SizedBox(height: 29),
            const _SectionLabel('安全'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('sync-encryption'),
                  title: '端到端加密',
                  subtitle: _encryptionSubtitle(state?.encryptionStatus),
                  onTap: interactive ? widget.onOpenEncryption : null,
                  trailing: _ValueChevron(
                    value: _encryptionLabel(state?.encryptionStatus),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                state?.encryptionStatus == DataEncryptionStatus.unlocked
                    ? '新设备登录后，将自动恢复已同步的数据。'
                    : '新设备需要通过受信设备或恢复密钥解锁后，才能恢复数据。',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLastSynced(DateTime? value) {
  if (value == null) return '未同步';
  final local = value.toLocal();
  final now = DateTime.now();
  final delta = now.difference(local);
  if (!delta.isNegative && delta < const Duration(minutes: 2)) return '刚刚';
  if (!delta.isNegative && delta < const Duration(hours: 1)) {
    return '${delta.inMinutes} 分钟前';
  }
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.month}月${local.day}日';
}

String _encryptionLabel(DataEncryptionStatus? status) => switch (status) {
  DataEncryptionStatus.unlocked => '已开启',
  DataEncryptionStatus.locked => '待解锁',
  DataEncryptionStatus.unavailable => '未设置',
  null => '检查中',
};

String _encryptionSubtitle(DataEncryptionStatus? status) => switch (status) {
  DataEncryptionStatus.unlocked => '仅你的设备可以解密',
  DataEncryptionStatus.locked => '需要受信设备或恢复密钥',
  DataEncryptionStatus.unavailable => '建立密钥后才能同步内容',
  null => '正在检查密钥状态',
};

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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _cardBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: subtitle == null ? 58 : 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: 0.88,
    child: CupertinoSwitch(
      value: value,
      activeTrackColor: _primary,
      inactiveTrackColor: const Color(0xFFD9DCE1),
      onChanged: enabled ? onChanged : null,
    ),
  );
}

class _ValueChevron extends StatelessWidget {
  const _ValueChevron({required this.value, this.emphasize = true});

  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: emphasize ? _primary : _muted,
          fontSize: 15,
          height: 1.3,
        ),
      ),
      const SizedBox(width: 5),
      const Icon(Icons.chevron_right_rounded, size: 23, color: _chevron),
    ],
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 16),
    child: Divider(height: 1, thickness: 1, color: _divider),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 27),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                body,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CacheSheet extends StatelessWidget {
  const _CacheSheet({required this.state});

  final DataSyncState state;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '本地缓存',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${state.cachedChangeCount} 项加密变更 · ${_formatBytes(state.cachedCiphertextBytes)}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                key: const Key('sync-cache-clear'),
                onPressed: state.cachedChangeCount == 0
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('清除同步缓存'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _formatBytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _primary = Color(0xFF3370FF);
const _divider = Color(0xFFE8EAED);
const _cardBorder = Color(0xFFDCE0E5);
const _chevron = Color(0xFFB7BBC2);
