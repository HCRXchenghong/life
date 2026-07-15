import 'dart:async';

import 'package:daylink_mobile/main.dart';
import 'package:daylink_mobile/src/data/app_authentication.dart';
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

  testWidgets('login form submits credentials and leaves the login gate', (
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
    expect(
      find.byKey(const Key('authenticated-page-pending-review')),
      findsOneWidget,
    );
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
  bool cleared = false;

  @override
  Uri get apiBaseUri => Uri.parse('https://daylink.example/api/');

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> clear() async {
    cleared = true;
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
  Future<bool> refresh() async => false;

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
