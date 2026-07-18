import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/application/assistant_settings.dart';
import 'src/application/daylink_services.dart';
import 'src/application/friend_schedule_list.dart';
import 'src/data/ai_gateway_client.dart';
import 'src/data/app_authentication.dart';
import 'src/data/app_session_monitor.dart';
import 'src/data/operations_repository.dart';
import 'src/data/schedule_repository.dart';
import 'src/domain/ai/ai_models.dart';
import 'src/domain/notifications/notification_settings.dart';
import 'src/domain/schedule/schedule_detail_models.dart';
import 'src/domain/schedule/schedule_editor_models.dart';
import 'src/domain/schedule/schedule_models.dart';
import 'src/domain/share/share_poll_models.dart';
import 'src/domain/sync/data_sync_models.dart';
import 'src/domain/sync/content_encryption_models.dart';
import 'src/presentation/app_navigation.dart';
import 'src/presentation/account_security_page.dart';
import 'src/presentation/assistant_page.dart';
import 'src/presentation/content_master_key_page.dart';
import 'src/presentation/data_sync_page.dart';
import 'src/presentation/device_approval_waiting_page.dart';
import 'src/presentation/device_approval_success_page.dart';
import 'src/presentation/end_to_end_encryption_page.dart';
import 'src/presentation/friend_schedule_editor_page.dart';
import 'src/presentation/friend_schedule_detail_page.dart';
import 'src/presentation/friend_schedule_list_page.dart';
import 'src/presentation/hosts_page.dart';
import 'src/presentation/login_page.dart';
import 'src/presentation/my_page.dart';
import 'src/presentation/notification_settings_page.dart';
import 'src/presentation/password_change_page.dart';
import 'src/presentation/recovery_key_page.dart';
import 'src/presentation/recovery_key_management_page.dart';
import 'src/presentation/recovery_unlock_page.dart';
import 'src/presentation/schedule_detail_page.dart';
import 'src/presentation/schedule_editor_page.dart';
import 'src/presentation/toolbox_page.dart';
import 'src/presentation/trusted_device_approval_page.dart';
import 'src/presentation/trusted_devices_page.dart';
import 'src/presentation/today_schedule_page.dart';

const _configuredApiBaseUrl = String.fromEnvironment(
  'DAYLINK_API_BASE_URL',
  defaultValue: 'https://192.168.101.71:8443/api/',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  runApp(const DaylinkApp());
}

typedef RuntimeFactory =
    Future<AppRuntime> Function(
      AppSessionCredentials session,
      AppAuthentication authentication,
    );

abstract interface class AppRuntime {
  Future<void> reconcile();
  Future<void> close();
}

abstract interface class ForcedSignOutAwareRuntime {
  Stream<String> get forcedSignOuts;
  bool get isSignedOut;
}

abstract interface class ScheduleAwareRuntime {
  ScheduleEventSource get schedules;
}

abstract interface class HostAwareRuntime {
  HostListSource get hosts;
}

class DaylinkApp extends StatefulWidget {
  const DaylinkApp({
    super.key,
    this.authentication,
    this.runtimeFactory,
    this.apiBaseUri,
  });

  final AppAuthentication? authentication;
  final RuntimeFactory? runtimeFactory;
  final Uri? apiBaseUri;

  @override
  State<DaylinkApp> createState() => _DaylinkAppState();
}

class _DaylinkAppState extends State<DaylinkApp> with WidgetsBindingObserver {
  late final AppAuthentication _authentication;
  AppRuntime? _runtime;
  AppSessionCredentials? _session;
  StreamSubscription<String>? _forcedSignOutSubscription;
  bool _bootstrapping = true;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppDestination _selectedDestination = AppDestination.schedule;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authentication =
        widget.authentication ??
        AppAuthenticator(
          apiBaseUri: widget.apiBaseUri ?? Uri.parse(_configuredApiBaseUrl),
        );
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final session = await _authentication.restore();
      if (!mounted) return;
      if (session != null) await _activate(session);
    } on Object {
      // Secure storage or local service startup failure falls back to the login
      // gate without exposing platform details.
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  Future<void> _login(String username, String password) async {
    final session = await _authentication.login(
      username: username,
      password: password,
      deviceName: _deviceName(),
    );
    try {
      await _activate(session);
    } on Object {
      await _authentication.clear();
      throw const AppAuthenticationException('本地服务启动失败，请重试');
    }
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final previous = _session;
    if (previous == null) {
      throw const AppAuthenticationException(
        '登录已失效，请重新登录',
        sessionRejected: true,
      );
    }
    await _detachRuntime();

    late AppSessionCredentials updated;
    try {
      updated = await _authentication.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on AppAuthenticationException catch (error) {
      if (error.sessionRejected) {
        await _authentication.clear();
        _session = null;
        if (mounted) setState(() {});
      } else {
        try {
          await _activate(previous);
        } on Object {
          await _authentication.clear();
          _session = null;
          if (mounted) setState(() {});
          throw const AppAuthenticationException('本地服务启动失败，请重新登录');
        }
      }
      rethrow;
    } on Object {
      try {
        await _activate(previous);
      } on Object {
        await _authentication.clear();
        _session = null;
        if (mounted) setState(() {});
        throw const AppAuthenticationException('本地服务启动失败，请重新登录');
      }
      rethrow;
    }

    try {
      await _activate(updated);
    } on Object {
      await _authentication.clear();
      _session = null;
      if (mounted) setState(() {});
      throw const AppAuthenticationException('本地服务启动失败，请重新登录');
    }
  }

  Future<void> _logout() async {
    await _detachRuntime();
    final logout = _authentication.logout();
    _session = null;
    _selectedDestination = AppDestination.schedule;
    if (mounted) setState(() {});
    await logout;
  }

  Future<void> _activate(AppSessionCredentials session) async {
    final runtime = await (widget.runtimeFactory ?? _startRuntime)(
      session,
      _authentication,
    );
    if (!mounted) {
      await runtime.close();
      return;
    }
    await _forcedSignOutSubscription?.cancel();
    _runtime = runtime;
    _session = session;
    _selectedDestination = AppDestination.schedule;
    if (runtime is ForcedSignOutAwareRuntime) {
      final signOutAware = runtime as ForcedSignOutAwareRuntime;
      _forcedSignOutSubscription = signOutAware.forcedSignOuts.listen((_) {
        unawaited(_handleForcedSignOut(runtime));
      });
      if (signOutAware.isSignedOut) {
        await _handleForcedSignOut(runtime);
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleForcedSignOut(AppRuntime runtime) async {
    if (!identical(_runtime, runtime)) return;
    await _authentication.clear();
    await _detachRuntime();
    _session = null;
    _selectedDestination = AppDestination.schedule;
    if (mounted) setState(() {});
  }

  Future<void> _detachRuntime() async {
    final subscription = _forcedSignOutSubscription;
    final runtime = _runtime;
    _forcedSignOutSubscription = null;
    _runtime = null;
    await subscription?.cancel();
    await runtime?.close();
  }

  static Future<AppRuntime> _startRuntime(
    AppSessionCredentials session,
    AppAuthentication authentication,
  ) => session.passwordChangeRequired
      ? Future<AppRuntime>.value(
          DaylinkSessionRuntime.start(
            apiBaseUri: authentication.apiBaseUri,
            accessToken: authentication.accessToken,
            refreshAccessToken: authentication.refresh,
            clearCredentials: authentication.clear,
          ),
        )
      : DaylinkRuntime.startForAccount(
          session.accountId,
          apiBaseUri: authentication.apiBaseUri,
          accessToken: authentication.accessToken,
          refreshAccessToken: authentication.refresh,
          clearCredentials: authentication.clear,
        );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runtime?.reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_forcedSignOutSubscription?.cancel());
    unawaited(_runtime?.close());
    _authentication.close();
    super.dispose();
  }

  void _showPendingPage(String name) {
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$name页面将在审核通过后开放'),
        ),
      );
  }

  Future<void> _openAccountSecurity() => _navigatorKey.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AccountSecurityPage(
        username: _session!.username,
        authentication: _authentication,
        onChangePassword: () => unawaited(_openPasswordChange()),
        onSessionRejected: _closeDetailsAndLogout,
      ),
    ),
  );

  Future<void> _openPasswordChange() => _navigatorKey.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PasswordChangePage(
        firstLogin: false,
        onChangePassword: _changePasswordFromSettings,
        onLogout: _logout,
        onChanged: () {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          _showMessage('密码已修改');
        },
      ),
    ),
  );

  Future<void> _openNotificationSettings() async {
    final runtime = _runtime;
    if (runtime is! NotificationSettingsSource) {
      _showPendingPage('通知设置');
      return;
    }
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationSettingsPage(
          source: runtime as NotificationSettingsSource,
        ),
      ),
    );
  }

  Future<void> _openDataSync() async {
    final runtime = _runtime;
    if (runtime is! DataSyncSource) {
      _showPendingPage('数据与同步');
      return;
    }
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DataSyncPage(
          source: runtime as DataSyncSource,
          onOpenEncryption: () => unawaited(_openEndToEndEncryption()),
        ),
      ),
    );
  }

  Future<ScheduleSaveResult?> _pushScheduleEditor({
    ScheduleEventModel? initialEvent,
    List<ReminderModel> initialReminders = const [],
  }) async {
    final runtime = _runtime;
    if (runtime is! ScheduleEditorSource) {
      _showPendingPage('新建日程');
      return null;
    }
    final result = await _navigatorKey.currentState!.push<ScheduleSaveResult>(
      MaterialPageRoute<ScheduleSaveResult>(
        builder: (_) => ScheduleEditorPage(
          source: runtime as ScheduleEditorSource,
          onOpenAssistant: _openAssistantFromScheduleEditor,
          initialEvent: initialEvent,
          initialReminders: initialReminders,
        ),
      ),
    );
    if (result == null) return null;
    _showMessage(switch (result.reminderDelivery) {
      ScheduleReminderDelivery.none => '日程已保存',
      ScheduleReminderDelivery.scheduled => '日程已保存，系统提醒已安排',
      ScheduleReminderDelivery.permissionDenied => '日程已保存；请在通知设置中开启系统提醒',
      ScheduleReminderDelivery.deferred => '日程已保存；系统提醒将在稍后重试',
    });
    return result;
  }

  Future<void> _openScheduleEditor() async {
    await _pushScheduleEditor();
  }

  Future<bool> _editSchedule(
    ScheduleEventModel event,
    List<ReminderModel> reminders,
  ) async =>
      await _pushScheduleEditor(
        initialEvent: event,
        initialReminders: reminders,
      ) !=
      null;

  Future<void> _openScheduleDetail(String eventId) async {
    final runtime = _runtime;
    if (runtime is! ScheduleDetailSource) {
      _showPendingPage('日程详情');
      return;
    }
    final result = await _navigatorKey.currentState!
        .push<ScheduleStatusChangeResult>(
          MaterialPageRoute<ScheduleStatusChangeResult>(
            builder: (_) => ScheduleDetailPage(
              eventId: eventId,
              source: runtime as ScheduleDetailSource,
              onEdit: _editSchedule,
            ),
          ),
        );
    if (result == null) return;
    final action = result.status == ScheduleStatus.completed ? '已完成' : '已取消';
    _showMessage(
      result.remindersCancelled ? '日程$action，系统提醒已移除' : '日程$action；系统提醒将在稍后清理',
    );
  }

  void _openAssistantFromScheduleEditor() {
    _navigatorKey.currentState?.pop();
    _selectDestination(AppDestination.assistant);
  }

  Future<void> _openEndToEndEncryption() async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) {
      _showPendingPage('端到端加密');
      return;
    }
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EndToEndEncryptionPage(
          source: runtime as ContentEncryptionSource,
          onRecoveryKeyReady: _openRecoveryKey,
          onOpenUnlock: _openRecoveryUnlock,
          onOpenDeviceRecovery: _openDeviceApprovalRecovery,
          approvalSource: runtime is TrustedDeviceApprovalSource
              ? runtime as TrustedDeviceApprovalSource
              : null,
          onOpenDeviceApproval: _openTrustedDeviceApproval,
          onOpenTrustedDevices: () => unawaited(_openTrustedDevices()),
          onOpenContentMasterKey: () => unawaited(_openContentMasterKey()),
          onOpenRecoveryKeyManagement: () =>
              unawaited(_openRecoveryKeyManagement()),
        ),
      ),
    );
  }

  Future<void> _openTrustedDevices() => _navigatorKey.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TrustedDevicesPage(
        authentication: _authentication,
        onSessionRejected: _closeDetailsAndLogout,
      ),
    ),
  );

  Future<void> _openContentMasterKey() async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) return;
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ContentMasterKeyPage(source: runtime as ContentEncryptionSource),
      ),
    );
  }

  Future<void> _openRecoveryKey(RecoveryKeyDraft draft) async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) return;
    await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryKeyPage(
          source: runtime as ContentEncryptionSource,
          draft: draft,
        ),
      ),
    );
  }

  Future<void> _openRecoveryKeyManagement() async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) return;
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecoveryKeyManagementPage(
          source: runtime as ContentEncryptionSource,
          onRotationReady: _openRecoveryKeyRotation,
        ),
      ),
    );
  }

  Future<void> _openRecoveryKeyRotation(RecoveryKeyRotationDraft draft) async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) return;
    final source = runtime as ContentEncryptionSource;
    await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryKeyPage(
          source: source,
          draft: draft.recoveryKey,
          onAcknowledgeSaved: () =>
              source.acknowledgeRecoveryKeyRotationSaved(draft.rotationId),
        ),
      ),
    );
  }

  Future<void> _openRecoveryUnlock() async {
    final runtime = _runtime;
    if (runtime is! ContentEncryptionSource) return;
    await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            RecoveryUnlockPage(source: runtime as ContentEncryptionSource),
      ),
    );
  }

  Future<void> _openDeviceApprovalRecovery() async {
    final runtime = _runtime;
    if (runtime is! DeviceApprovalRecoverySource) {
      await _openRecoveryUnlock();
      return;
    }
    final recoverySource = runtime as DeviceApprovalRecoverySource;
    final session = await recoverySource.startDeviceApproval();
    final result = await _navigatorKey.currentState!
        .push<DeviceApprovalWaitingResult>(
          MaterialPageRoute<DeviceApprovalWaitingResult>(
            builder: (_) => DeviceApprovalWaitingPage(
              source: recoverySource,
              session: session,
            ),
          ),
        );
    if (result == DeviceApprovalWaitingResult.useRecoveryKey) {
      await _openRecoveryUnlock();
    } else if (result == DeviceApprovalWaitingResult.completed) {
      await _navigatorKey.currentState!.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const DeviceApprovalSuccessPage(),
        ),
      );
    }
  }

  Future<void> _openTrustedDeviceApproval(
    TrustedDeviceApprovalRequest request,
  ) async {
    final runtime = _runtime;
    if (runtime is! TrustedDeviceApprovalSource) return;
    await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TrustedDeviceApprovalPage(
          source: runtime as TrustedDeviceApprovalSource,
          request: request,
        ),
      ),
    );
  }

  Future<void> _changePasswordFromSettings(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _changePassword(currentPassword, newPassword);
    } on AppAuthenticationException catch (error) {
      if (error.sessionRejected) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
      rethrow;
    }
  }

  Future<void> _closeDetailsAndLogout() async {
    await _logout();
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _selectDestination(AppDestination destination) {
    if (destination == AppDestination.schedule ||
        destination == AppDestination.toolbox ||
        destination == AppDestination.assistant ||
        destination == AppDestination.hosts ||
        destination == AppDestination.me) {
      if (_selectedDestination == destination) return;
      setState(() => _selectedDestination = destination);
      return;
    }
    final name = switch (destination) {
      AppDestination.schedule => '日程',
      AppDestination.toolbox => '工具箱',
      AppDestination.assistant => '助手',
      AppDestination.hosts => '主机',
      AppDestination.me => '我的',
    };
    _showPendingPage(name);
  }

  void _selectTool(ToolboxTool tool) {
    if (tool == ToolboxTool.friendSchedule) {
      unawaited(_openFriendSchedules());
      return;
    }
    final name = switch (tool) {
      ToolboxTool.friendSchedule => throw StateError('handled above'),
      ToolboxTool.imageGeneration => 'AI 生图',
      ToolboxTool.wordDocument => 'Word 文档',
      ToolboxTool.spreadsheetPresentation => '表格与演示',
    };
    _showPendingPage(name);
  }

  Future<void> _openFriendSchedules() async {
    final runtime = _runtime;
    if (runtime is! FriendScheduleListSource) {
      _showPendingPage('好友选时间');
      return;
    }
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendScheduleListPage(
          source: runtime as FriendScheduleListSource,
          onCreate: runtime is FriendScheduleCreationSource
              ? () => _openFriendScheduleEditor(
                  runtime as FriendScheduleCreationSource,
                )
              : () async {
                  _showPendingPage('新建选时间');
                  return false;
                },
          onOpenPoll: runtime is FriendScheduleDetailSource
              ? (poll) => _openFriendScheduleDetail(
                  runtime as FriendScheduleDetailSource,
                  poll.id,
                )
              : (_) async {
                  _showPendingPage('选时间详情');
                  return false;
                },
        ),
      ),
    );
  }

  Future<bool> _openFriendScheduleEditor(
    FriendScheduleCreationSource source,
  ) async {
    final created = await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FriendScheduleEditorPage(
          source: source,
          onEditSchedule: _editFriendScheduleConflict,
        ),
      ),
    );
    if (created != true) return false;
    _showMessage('选时间已创建');
    return true;
  }

  Future<bool> _openFriendScheduleDetail(
    FriendScheduleDetailSource source,
    String pollId,
  ) async =>
      await _navigatorKey.currentState!.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              FriendScheduleDetailPage(pollId: pollId, source: source),
        ),
      ) ??
      false;

  Future<bool> _editFriendScheduleConflict(String eventId) async {
    final runtime = _runtime;
    if (runtime is! ScheduleDetailSource) return false;
    final details = await (runtime as ScheduleDetailSource).loadScheduleDetail(
      eventId,
    );
    if (details == null) {
      _showMessage('冲突日程已不存在，请重新检查');
      return false;
    }
    return _editSchedule(details.event, details.reminders);
  }

  Widget _authenticatedHome() {
    final runtime = _runtime;
    if (_selectedDestination == AppDestination.me &&
        runtime is AccountEntitlementSource) {
      return MyPage(
        username: _session!.username,
        source: runtime as AccountEntitlementSource,
        onOpenAccount: () => unawaited(_openAccountSecurity()),
        onOpenNotifications: () => unawaited(_openNotificationSettings()),
        onOpenSync: () => unawaited(_openDataSync()),
        onLogout: _logout,
        onDestinationSelected: _selectDestination,
      );
    }
    if (_selectedDestination == AppDestination.hosts &&
        runtime is HostAwareRuntime) {
      return HostsPage(
        source: (runtime as HostAwareRuntime).hosts,
        onAddHost: () => _showPendingPage('添加主机'),
        onOpenHost: (_) => _showPendingPage('主机详情'),
        onDestinationSelected: _selectDestination,
      );
    }
    if (runtime is ScheduleAwareRuntime) {
      final scheduleRuntime = runtime as ScheduleAwareRuntime;
      if (_selectedDestination == AppDestination.toolbox) {
        return ToolboxPage(
          onToolSelected: _selectTool,
          onDestinationSelected: _selectDestination,
        );
      }
      if (_selectedDestination == AppDestination.assistant) {
        return AssistantPage(
          settings: runtime is AssistantSettingsSource
              ? runtime as AssistantSettingsSource
              : null,
          onDestinationSelected: _selectDestination,
          onOpenHistory: () => _showPendingPage('对话历史'),
          onNewConversation: () => _showPendingPage('新对话'),
          onOpenMore: () => _showPendingPage('助手更多设置'),
          onAddAttachment: () => _showPendingPage('添加附件'),
          onVoiceInput: () => _showPendingPage('语音输入'),
          onSubmit: (_) async => _showPendingPage('安全审批与对话结果'),
          onMessage: _showMessage,
        );
      }
      return TodaySchedulePage(
        source: scheduleRuntime.schedules,
        onCreateEvent: () => unawaited(_openScheduleEditor()),
        onOpenEvent: (eventId) => unawaited(_openScheduleDetail(eventId)),
        onOpenAssistant: () => _selectDestination(AppDestination.assistant),
        onDestinationSelected: _selectDestination,
      );
    }
    return const ColoredBox(
      key: Key('authenticated-page-pending-review'),
      color: Color(0xFFF7F8FA),
    );
  }

  void _showMessage(String message) {
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: _scaffoldMessengerKey,
    debugShowCheckedModeBanner: false,
    title: 'Daylink',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3370FF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      splashFactory: InkSparkle.splashFactory,
    ),
    home: _bootstrapping
        ? const ColoredBox(color: Color(0xFFF7F8FA))
        : _session == null
        ? LoginPage(onLogin: _login)
        : _session!.passwordChangeRequired
        ? PasswordChangePage(
            onChangePassword: _changePassword,
            onLogout: _logout,
          )
        : _authenticatedHome(),
  );
}

String _deviceName() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'Daylink iPhone',
  TargetPlatform.android => 'Daylink Android',
  _ => 'Daylink device',
};

class DaylinkRuntime
    implements
        AppRuntime,
        ForcedSignOutAwareRuntime,
        ScheduleAwareRuntime,
        HostAwareRuntime,
        AssistantSettingsSource,
        AccountEntitlementSource,
        NotificationSettingsSource,
        DataSyncSource,
        ContentEncryptionSource,
        TrustedDeviceApprovalSource,
        DeviceApprovalRecoverySource,
        ScheduleEditorSource,
        ScheduleDetailSource,
        FriendScheduleDetailSource {
  DaylinkRuntime._(
    this.services,
    this._assistantSettings,
    this._friendSchedules,
  );

  final DaylinkServices services;
  final DaylinkAssistantSettings _assistantSettings;
  final DaylinkFriendSchedules _friendSchedules;
  final StreamController<String> _forcedSignOutController =
      StreamController<String>.broadcast();
  bool _signedOut = false;
  bool _closed = false;

  @override
  ScheduleEventSource get schedules => services.schedules;

  @override
  HostListSource get hosts => services.operations;

  static Future<DaylinkRuntime> startForAccount(
    String accountId, {
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
  }) async {
    final services = await DaylinkServices.start(
      accountId: accountId,
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
    );
    final runtime = DaylinkRuntime._(
      services,
      DaylinkAssistantSettings(
        apiBaseUri: apiBaseUri,
        accessToken: accessToken,
      ),
      DaylinkFriendSchedules(
        services: services,
        apiBaseUri: apiBaseUri,
        accessToken: accessToken,
        refreshAccessToken: refreshAccessToken,
      ),
    );
    services.monitorSession(
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
      clearCredentials: clearCredentials,
      onForcedSignOut: runtime._forceSignOut,
    );
    return runtime;
  }

  @override
  Stream<String> get forcedSignOuts => _forcedSignOutController.stream;

  @override
  bool get isSignedOut => _signedOut;

  @override
  Future<AssistantPreferences> loadAssistantPreferences() =>
      _assistantSettings.loadAssistantPreferences();

  @override
  Future<void> updateAssistantPreferences({
    required String model,
    required AiReasoningEffort reasoningEffort,
  }) => _assistantSettings.updateAssistantPreferences(
    model: model,
    reasoningEffort: reasoningEffort,
  );

  @override
  Future<AiEntitlement> loadAccountEntitlement() =>
      _assistantSettings.loadAccountEntitlement();

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() =>
      _friendSchedules.loadFriendSchedules();

  @override
  Future<String> loadFriendScheduleTimezoneId() =>
      _friendSchedules.loadFriendScheduleTimezoneId();

  @override
  Future<void> createFriendSchedule(CreateSharePollDraft draft) =>
      _friendSchedules.createFriendSchedule(draft);

  @override
  Future<List<FriendScheduleConflict>> findFriendScheduleConflicts(
    List<SharePollSlotDraft> ranges,
  ) => _friendSchedules.findFriendScheduleConflicts(ranges);

  @override
  Future<FriendPollDetails> loadFriendScheduleDetails(String pollId) =>
      _friendSchedules.loadFriendScheduleDetails(pollId);

  @override
  Future<FriendPollInvite> createFriendInvite({
    required String pollId,
    required String displayName,
  }) => _friendSchedules.createFriendInvite(
    pollId: pollId,
    displayName: displayName,
  );

  @override
  Future<void> revokeFriendInvite({
    required String pollId,
    required String inviteId,
  }) => _friendSchedules.revokeFriendInvite(pollId: pollId, inviteId: inviteId);

  @override
  Future<void> confirmFriendSchedule({
    required FriendPollDetails details,
    required FriendTimeSuggestion suggestion,
  }) => _friendSchedules.confirmFriendSchedule(
    details: details,
    suggestion: suggestion,
  );

  @override
  Future<ScheduleEditorDefaults> loadScheduleEditorDefaults() =>
      services.scheduleEditor.loadScheduleEditorDefaults();

  @override
  Future<ScheduleSaveResult> saveScheduleEvent({
    required ScheduleEventModel event,
    required List<ReminderModel> reminders,
  }) => services.scheduleEditor.saveScheduleEvent(
    event: event,
    reminders: reminders,
  );

  @override
  Future<ScheduleDetailData?> loadScheduleDetail(String eventId) =>
      services.scheduleEditor.loadScheduleDetail(eventId);

  @override
  Future<ScheduleStatusChangeResult> setScheduleStatus({
    required String eventId,
    required ScheduleStatus status,
  }) => services.scheduleEditor.setScheduleStatus(
    eventId: eventId,
    status: status,
  );

  @override
  Future<NotificationSettingsState> loadNotificationSettings() =>
      services.loadNotificationSettings();

  @override
  Future<NotificationSettingsState> setRemindersEnabled(bool enabled) =>
      services.setRemindersEnabled(enabled);

  @override
  Future<NotificationSettingsState> setDefaultLeadMinutes(int minutes) =>
      services.setDefaultLeadMinutes(minutes);

  @override
  Future<NotificationSettingsState> setSoundAndVibrationEnabled(bool enabled) =>
      services.setSoundAndVibrationEnabled(enabled);

  @override
  Future<NotificationSettingsState> requestNotificationPermission() =>
      services.requestNotificationPermission();

  @override
  Future<void> openSystemNotificationSettings() =>
      services.openSystemNotificationSettings();

  @override
  Future<DataSyncState> loadDataSyncState() => services.loadDataSyncState();

  @override
  Future<DataSyncState> setAutoSyncEnabled(bool enabled) =>
      services.setAutoSyncEnabled(enabled);

  @override
  Future<DataSyncState> syncNow() => services.syncNow();

  @override
  Future<DataSyncState> clearLocalSyncCache() => services.clearLocalSyncCache();

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() =>
      services.loadContentEncryptionState();

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() =>
      services.prepareContentEncryption();

  @override
  Future<void> acknowledgeRecoveryKeySaved() =>
      services.acknowledgeRecoveryKeySaved();

  @override
  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation() =>
      services.prepareRecoveryKeyRotation();

  @override
  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId) =>
      services.acknowledgeRecoveryKeyRotationSaved(rotationId);

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) =>
      services.restoreWithRecoveryKey(encodedKey);

  @override
  Future<TrustedDeviceApprovalRequest?> loadPendingDeviceApproval() =>
      services.loadPendingDeviceApproval();

  @override
  Future<void> approveDevice(TrustedDeviceApprovalRequest request) =>
      services.approveDevice(request);

  @override
  Future<void> rejectDevice(TrustedDeviceApprovalRequest request) =>
      services.rejectDevice(request);

  @override
  Future<DeviceApprovalWaitingSession> startDeviceApproval() =>
      services.startDeviceApproval();

  @override
  Future<DeviceApprovalWaitingStatus> checkDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) => services.checkDeviceApproval(session);

  @override
  Future<void> cancelDeviceApproval(DeviceApprovalWaitingSession session) =>
      services.cancelDeviceApproval(session);

  Future<void> _forceSignOut(String reason) async {
    if (_signedOut) return;
    _signedOut = true;
    await services.close();
    if (!_forcedSignOutController.isClosed) {
      _forcedSignOutController.add(reason);
    }
  }

  @override
  Future<void> reconcile() =>
      _signedOut ? Future<void>.value() : services.reconcile();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await services.close();
    await _forcedSignOutController.close();
  }
}

/// Keeps forced sign-out active before a first-login password change without
/// opening the account database or any user content.
class DaylinkSessionRuntime implements AppRuntime, ForcedSignOutAwareRuntime {
  DaylinkSessionRuntime._(this._monitor);

  final AppSessionMonitor _monitor;
  final StreamController<String> _forcedSignOutController =
      StreamController<String>.broadcast();
  bool _signedOut = false;
  bool _closed = false;

  static DaylinkSessionRuntime start({
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
  }) {
    late DaylinkSessionRuntime runtime;
    final monitor = AppSessionMonitor(
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
      clearCredentials: clearCredentials,
      onForcedSignOut: (reason) => runtime._forceSignOut(reason),
    );
    runtime = DaylinkSessionRuntime._(monitor);
    monitor.start();
    return runtime;
  }

  @override
  Stream<String> get forcedSignOuts => _forcedSignOutController.stream;

  @override
  bool get isSignedOut => _signedOut;

  Future<void> _forceSignOut(String reason) async {
    if (_signedOut) return;
    _signedOut = true;
    if (!_forcedSignOutController.isClosed) {
      _forcedSignOutController.add(reason);
    }
  }

  @override
  Future<void> reconcile() => _monitor.reconcile();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _monitor.close();
    await _forcedSignOutController.close();
  }
}
