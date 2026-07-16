import 'package:daylink_mobile/src/data/app_authentication.dart';
import 'package:daylink_mobile/src/presentation/account_security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved account and live device layout', (
    tester,
  ) async {
    final authentication = _FakeAuthentication();
    var passwordOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityPage(
          username: 'daylink-user',
          authentication: authentication,
          onChangePassword: () => passwordOpened = true,
          onSessionRejected: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账号与安全'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('daylink-user'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('Daylink iPhone'), findsOneWidget);
    expect(find.text('Daylink Android'), findsOneWidget);
    expect(find.text('当前设备 · 刚刚活跃'), findsOneWidget);
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('退出其他设备'), findsOneWidget);
    expect(find.text('日程'), findsNothing);

    await tester.tap(find.byKey(const Key('security-change-password')));
    expect(passwordOpened, isTrue);
  });

  testWidgets('confirms revocation and keeps the current device', (
    tester,
  ) async {
    final authentication = _FakeAuthentication();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityPage(
          username: 'daylink-user',
          authentication: authentication,
          onChangePassword: () {},
          onSessionRejected: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('security-revoke-others')));
    await tester.pumpAndSettle();
    expect(find.text('退出其他设备？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('security-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(authentication.revokeCalls, 1);
    expect(find.text('Daylink iPhone'), findsOneWidget);
    expect(find.text('Daylink Android'), findsNothing);
    expect(find.text('其他设备已退出'), findsOneWidget);
  });
}

class _FakeAuthentication implements AppAuthentication {
  var revokeCalls = 0;

  List<AppDeviceSession> get _devices => [
    AppDeviceSession(
      id: '123e4567-e89b-12d3-a456-426614174001',
      name: 'Daylink iPhone',
      current: true,
      lastSeenAt: DateTime.now().toUtc(),
      createdAt: DateTime.utc(2030, 7, 1),
    ),
    if (revokeCalls == 0)
      AppDeviceSession(
        id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Daylink Android',
        current: false,
        lastSeenAt: DateTime.now().subtract(const Duration(days: 1)).toUtc(),
        createdAt: DateTime.utc(2030, 7, 2),
      ),
  ];

  @override
  Uri get apiBaseUri => Uri.parse('https://daylink.example/api/');

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> clear() async {}

  @override
  Future<AppSessionCredentials> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  void close() {}

  @override
  Future<List<AppDeviceSession>> loadDeviceSessions() async => _devices;

  @override
  Future<AppSessionCredentials> login({
    required String username,
    required String password,
    required String deviceName,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<bool> refresh() async => false;

  @override
  Future<void> revokeOtherDeviceSessions() async {
    revokeCalls++;
  }

  @override
  Future<AppSessionCredentials?> restore() async => null;
}
