import 'dart:async';

import 'package:daylink_mobile/main.dart';
import 'package:daylink_mobile/src/data/app_authentication.dart';
import 'package:daylink_mobile/src/application/assistant_settings.dart';
import 'package:daylink_mobile/src/data/ai_gateway_client.dart';
import 'package:daylink_mobile/src/data/operations_repository.dart';
import 'package:daylink_mobile/src/data/schedule_repository.dart';
import 'package:daylink_mobile/src/domain/operations/operations_models.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out app renders the approved login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      DaylinkApp(
        authentication: _FakeAuthentication(),
        runtimeFactory: (_, _) async => _FakeRuntime(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daylink'), findsOneWidget);
    expect(find.text('登录 Daylink'), findsOneWidget);
    expect(find.text('继续管理你的日程与主机'), findsOneWidget);
    expect(find.text('账号由 Daylink 管理员创建'), findsOneWidget);
    expect(find.byKey(const Key('login-username')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.textContaining('注册'), findsNothing);
  });

  testWidgets('login form submits credentials and opens password setup', (
    tester,
  ) async {
    final authentication = _FakeAuthentication();
    await tester.pumpWidget(
      DaylinkApp(
        authentication: authentication,
        runtimeFactory: (_, _) async => _FakeRuntime(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-username')),
      'daylink-user',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'temporary-password',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('login-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(authentication.lastUsername, 'daylink-user');
    expect(authentication.lastPassword, 'temporary-password');
    expect(find.text('设置新密码'), findsOneWidget);
    expect(find.byKey(const Key('password-current')), findsOneWidget);
    expect(find.byKey(const Key('password-new')), findsOneWidget);
    expect(find.byKey(const Key('password-confirm')), findsOneWidget);
  });

  testWidgets('first-login password change rotates session and enters app', (
    tester,
  ) async {
    final authentication = _FakeAuthentication(
      restored: _FakeAuthentication.session(
        username: 'first-login-user',
        passwordChangeRequired: true,
      ),
    );
    await tester.pumpWidget(
      DaylinkApp(
        authentication: authentication,
        runtimeFactory: (_, _) async => _FakeRuntime(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首次登录需要修改密码'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('password-current')),
      'Temporary1!',
    );
    await tester.enterText(
      find.byKey(const Key('password-new')),
      'Replacement2!',
    );
    await tester.enterText(
      find.byKey(const Key('password-confirm')),
      'Replacement2!',
    );
    tester.testTextInput.hide();
    final submit = find.byKey(const Key('password-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(authentication.lastCurrentPassword, 'Temporary1!');
    expect(authentication.lastNewPassword, 'Replacement2!');
    expect(
      find.byKey(const Key('authenticated-page-pending-review')),
      findsOneWidget,
    );
  });

  testWidgets('password setup logout returns immediately to login', (
    tester,
  ) async {
    final authentication = _FakeAuthentication(
      restored: _FakeAuthentication.session(
        username: 'first-login-user',
        passwordChangeRequired: true,
      ),
    );
    await tester.pumpWidget(
      DaylinkApp(
        authentication: authentication,
        runtimeFactory: (_, _) async => _FakeRuntime(),
      ),
    );
    await tester.pumpAndSettle();

    final logout = find.byKey(const Key('password-logout'));
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(authentication.loggedOut, isTrue);
    expect(find.text('登录 Daylink'), findsOneWidget);
  });

  testWidgets('server revocation immediately returns to login', (tester) async {
    final authentication = _FakeAuthentication(
      restored: _FakeAuthentication.session(
        username: 'disabled-user',
        passwordChangeRequired: false,
      ),
    );
    final runtime = _FakeForcedRuntime();
    await tester.pumpWidget(
      DaylinkApp(
        authentication: authentication,
        runtimeFactory: (_, _) async => runtime,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('登录 Daylink'), findsNothing);

    runtime.forceSignOut();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();

    expect(authentication.cleared, isTrue);
    expect(find.text('登录 Daylink'), findsOneWidget);
  });

  testWidgets('restored authenticated account enters the schedule shell', (
    tester,
  ) async {
    final authentication = _FakeAuthentication(
      restored: _FakeAuthentication.session(
        username: 'active-user',
        passwordChangeRequired: false,
      ),
    );
    await tester.pumpWidget(
      DaylinkApp(
        authentication: authentication,
        runtimeFactory: (_, _) async => _FakeScheduleRuntime(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('今日日程'), findsOneWidget);
    expect(find.text('日程'), findsOneWidget);
    expect(find.text('工具箱'), findsOneWidget);
    expect(find.text('助手'), findsOneWidget);
    expect(find.text('主机'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-toolbox')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toolbox-title')), findsOneWidget);
    expect(find.text('好友选时间'), findsOneWidget);
    expect(find.text('AI 生图'), findsOneWidget);
    expect(find.text('Word 文档'), findsOneWidget);
    expect(find.text('表格与演示'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-assistant')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-greeting')), findsOneWidget);
    expect(find.text('本地助手'), findsOneWidget);
    expect(find.text('询问 Daylink'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-hosts')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hosts-title')), findsOneWidget);
    expect(find.byKey(const Key('hosts-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-me')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-title')), findsOneWidget);
    expect(find.text('active-user'), findsOneWidget);
    expect(find.text('2 / 10 亿 Token'), findsOneWidget);

    await tester.tap(find.byKey(const Key('my-security')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('security-title')), findsOneWidget);
    expect(find.text('active-user'), findsOneWidget);
    expect(find.text('Daylink iPhone'), findsOneWidget);
    expect(find.text('当前设备 · 刚刚活跃'), findsOneWidget);
    await tester.tap(find.byKey(const Key('security-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-schedule')));
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);
  });
}

class _FakeAuthentication implements AppAuthentication {
  _FakeAuthentication({this.restored});

  static AppSessionCredentials session({
    required String username,
    required bool passwordChangeRequired,
  }) => AppSessionCredentials(
    accountId: '123e4567-e89b-12d3-a456-426614174000',
    username: username,
    passwordChangeRequired: passwordChangeRequired,
    accessToken: 'dlka_${_repeat('a')}',
    accessExpiresAt: DateTime.utc(2030),
    refreshToken: 'dlkr_${_repeat('b')}',
    refreshExpiresAt: DateTime.utc(2031),
  );

  final AppSessionCredentials? restored;
  String? lastUsername;
  String? lastPassword;
  String? lastCurrentPassword;
  String? lastNewPassword;
  bool cleared = false;
  bool loggedOut = false;

  @override
  Uri get apiBaseUri => Uri.parse('https://daylink.example/api/');

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> clear() async {
    cleared = true;
  }

  @override
  Future<AppSessionCredentials> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    return session(
      username: restored?.username ?? 'daylink-user',
      passwordChangeRequired: false,
    );
  }

  @override
  void close() {}

  @override
  Future<AppSessionCredentials> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    lastUsername = username;
    lastPassword = password;
    return session(username: username, passwordChangeRequired: true);
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    cleared = true;
  }

  @override
  Future<bool> refresh() async => false;

  @override
  Future<List<AppDeviceSession>> loadDeviceSessions() async => [
    AppDeviceSession(
      id: '123e4567-e89b-12d3-a456-426614174001',
      name: 'Daylink iPhone',
      current: true,
      lastSeenAt: DateTime.now().toUtc(),
      createdAt: DateTime.utc(2030, 1, 1),
    ),
  ];

  @override
  Future<void> revokeOtherDeviceSessions() async {}

  @override
  Future<AppSessionCredentials?> restore() async => restored;
}

String _repeat(String value) => List.filled(40, value).join();

class _FakeRuntime implements AppRuntime {
  @override
  Future<void> close() async {}

  @override
  Future<void> reconcile() async {}
}

class _FakeScheduleRuntime
    implements
        AppRuntime,
        ScheduleAwareRuntime,
        HostAwareRuntime,
        AccountEntitlementSource {
  final _source = _EmptyScheduleSource();
  final _hosts = _EmptyHostSource();

  @override
  ScheduleEventSource get schedules => _source;

  @override
  HostListSource get hosts => _hosts;

  @override
  Future<AiEntitlement> loadAccountEntitlement() async => AiEntitlement(
    active: true,
    plan: 'plus',
    cardType: 'month',
    expiresAt: DateTime.utc(2030, 1, 1, 12),
    monthlyUsed: 200000000,
    monthlyLimit: 1000000000,
    monthlyResetsAt: DateTime.utc(2030, 1),
    supportedModes: const [AiExecutionMode.localAI, AiExecutionMode.sshAgent],
  );

  @override
  Future<void> close() async {}

  @override
  Future<void> reconcile() async {}
}

class _EmptyHostSource implements HostListSource {
  @override
  Future<List<HostSearchResult>> searchHosts({
    String query = '',
    String? groupId,
    String? tagId,
    bool favoritesOnly = false,
  }) async => const [];
}

class _EmptyScheduleSource implements ScheduleEventSource {
  @override
  Future<List<ReminderModel>> remindersForEvents(
    Iterable<String> eventIds,
  ) async => const [];

  @override
  Stream<List<ScheduleEventModel>> watchActiveEvents() =>
      Stream.value(const []);
}

class _FakeForcedRuntime implements AppRuntime, ForcedSignOutAwareRuntime {
  final _events = StreamController<String>.broadcast();
  bool _signedOut = false;

  void forceSignOut() {
    _signedOut = true;
    _events.add('account_disabled');
  }

  @override
  Stream<String> get forcedSignOuts => _events.stream;

  @override
  bool get isSignedOut => _signedOut;

  @override
  Future<void> close() => _events.close();

  @override
  Future<void> reconcile() async {}
}
