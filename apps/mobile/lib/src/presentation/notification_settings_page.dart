import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notification_preferences_repository.dart';
import '../domain/notifications/notification_settings.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.source});

  final NotificationSettingsSource source;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  NotificationSettingsState? _settings;
  var _loading = true;
  var _saving = false;
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
      final settings = await widget.source.loadNotificationSettings();
      if (!mounted || generation != _generation) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      _showMessage('通知设置加载失败，请重试');
    }
  }

  Future<void> _change(
    Future<NotificationSettingsState> Function() operation, {
    String errorMessage = '保存失败，请重试',
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final settings = await operation();
      if (!mounted) return;
      setState(() => _settings = settings);
    } on Object {
      if (mounted) _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleReminders(bool enabled) async {
    await _change(() => widget.source.setRemindersEnabled(enabled));
    if (!mounted || !enabled) return;
    if (_settings?.permissionStatus !=
        NotificationPermissionStatus.authorized) {
      _showMessage('请在系统设置中开启通知权限');
    }
  }

  Future<void> _selectLeadTime() async {
    final current = _settings;
    if (current == null || _saving) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _LeadTimeSheet(selectedMinutes: current.defaultLeadMinutes),
    );
    if (selected == null || selected == current.defaultLeadMinutes) return;
    await _change(() => widget.source.setDefaultLeadMinutes(selected));
  }

  Future<void> _openSystemPermission() async {
    if (_saving) return;
    final current = _settings;
    if (current?.permissionStatus == NotificationPermissionStatus.authorized) {
      try {
        await widget.source.openSystemNotificationSettings();
      } on Object {
        if (mounted) _showMessage('无法打开系统通知设置');
      }
      return;
    }
    await _change(
      widget.source.requestNotificationPermission,
      errorMessage: '通知权限请求失败，请重试',
    );
    if (!mounted ||
        _settings?.permissionStatus ==
            NotificationPermissionStatus.authorized) {
      return;
    }
    try {
      await widget.source.openSystemNotificationSettings();
    } on Object {
      if (mounted) _showMessage('请在系统设置中开启通知权限');
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
    final settings = _settings;
    final interactive = !_loading && !_saving && settings != null;
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
            key: const Key('notification-settings-back'),
            onPressed: () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '通知设置',
            key: Key('notification-settings-title'),
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
          key: const Key('notification-settings-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 27, 24, 48),
          children: [
            const _SectionLabel('日程提醒'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('notification-reminders'),
                  title: '提醒通知',
                  subtitle: '接收日程开始前提醒',
                  trailing: _SettingsSwitch(
                    value: settings?.remindersEnabled ?? true,
                    enabled: interactive,
                    onChanged: _toggleReminders,
                  ),
                ),
                const _CardDivider(),
                _SettingsRow(
                  key: const Key('notification-default-lead'),
                  title: '默认提前提醒',
                  onTap: interactive ? _selectLeadTime : null,
                  trailing: _ValueChevron(
                    value: '${settings?.defaultLeadMinutes ?? 10} 分钟',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 29),
            const _SectionLabel('提醒方式'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('notification-sound-vibration'),
                  title: '声音与震动',
                  subtitle: '提醒时播放声音并震动',
                  trailing: _SettingsSwitch(
                    value: settings?.soundAndVibrationEnabled ?? true,
                    enabled: interactive,
                    onChanged: (enabled) => _change(
                      () => widget.source.setSoundAndVibrationEnabled(enabled),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 29),
            const _SectionLabel('系统'),
            const SizedBox(height: 11),
            _SettingsCard(
              children: [
                _SettingsRow(
                  key: const Key('notification-system-permission'),
                  title: '系统通知权限',
                  onTap: interactive ? _openSystemPermission : null,
                  trailing: _ValueChevron(
                    value: _permissionLabel(settings?.permissionStatus),
                    emphasize:
                        settings?.permissionStatus ==
                        NotificationPermissionStatus.authorized,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '系统权限关闭后，Daylink 无法发送原生提醒。',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(NotificationPermissionStatus? status) =>
      switch (status) {
        NotificationPermissionStatus.authorized => '已开启',
        NotificationPermissionStatus.denied => '未开启',
        NotificationPermissionStatus.unsupported => '不支持',
        null => '检查中',
      };
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
            const SizedBox(width: 12),
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
          fontWeight: FontWeight.w400,
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

class _LeadTimeSheet extends StatelessWidget {
  const _LeadTimeSheet({required this.selectedMinutes});

  final int selectedMinutes;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 19),
            const Text(
              '默认提前提醒',
              style: TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (final minutes
                in NotificationPreferencesRepository.supportedLeadMinutes)
              ListTile(
                key: Key('notification-lead-$minutes'),
                minTileHeight: 50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                title: Text(
                  minutes == 60 ? '1 小时' : '$minutes 分钟',
                  style: const TextStyle(fontSize: 16, color: _text),
                ),
                trailing: minutes == selectedMinutes
                    ? const Icon(Icons.check_rounded, color: _primary, size: 23)
                    : null,
                onTap: () => Navigator.pop(context, minutes),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _primary = Color(0xFF3370FF);
const _divider = Color(0xFFE8EAED);
const _cardBorder = Color(0xFFDCE0E5);
const _chevron = Color(0xFFB7BBC2);
