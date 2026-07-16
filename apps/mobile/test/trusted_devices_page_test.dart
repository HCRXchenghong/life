import 'package:daylink_mobile/src/data/app_authentication.dart';
import 'package:daylink_mobile/src/presentation/trusted_devices_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved trusted-device list from live data', (
    tester,
  ) async {
    _configurePhone(tester);
    final authentication = _FakeAuthentication();
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDevicesPage(
          authentication: authentication,
          onSessionRejected: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trusted-devices-title')), findsOneWidget);
    expect(find.text('这些设备可以解密并同步你的加密内容。'), findsOneWidget);
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('这台设备'), findsOneWidget);
    expect(find.text('Daylink iPhone · 当前使用'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('其他设备'), findsOneWidget);
    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.text('iPad Air'), findsOneWidget);
    expect(find.text('Daylink Android'), findsNothing);
    expect(find.text('撤销设备后，该设备将立即退出并停止同步'), findsOneWidget);
  });

  testWidgets('revokes only the selected trusted device after confirmation', (
    tester,
  ) async {
    _configurePhone(tester);
    final authentication = _FakeAuthentication();
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedDevicesPage(
          authentication: authentication,
          onSessionRejected: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.byKey(
      const Key('trusted-device-123e4567-e89b-12d3-a456-426614174002'),
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('撤销 MacBook Pro？'), findsOneWidget);
    expect(find.text('该设备将立即退出并停止同步。再次使用时，需要重新登录并恢复加密内容。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trusted-device-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(authentication.revokedIds, ['123e4567-e89b-12d3-a456-426614174002']);
    expect(find.text('MacBook Pro'), findsNothing);
    expect(find.text('iPad Air'), findsOneWidget);
    expect(find.text('设备已撤销'), findsOneWidget);
  });
}

void _configurePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FakeAuthentication implements AppAuthentication {
  final revokedIds = <String>[];

  @override
  Uri get apiBaseUri => Uri.parse('https://daylink.example/api/');

  List<AppDeviceSession> get _devices => [
    AppDeviceSession(
      id: '123e4567-e89b-12d3-a456-426614174001',
      name: 'Daylink iPhone',
      current: true,
      trusted: true,
      lastSeenAt: DateTime.now().toUtc(),
      createdAt: DateTime.utc(2030, 7, 1),
    ),
    if (!revokedIds.contains('123e4567-e89b-12d3-a456-426614174002'))
      AppDeviceSession(
        id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'MacBook Pro',
        current: false,
        trusted: true,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5)).toUtc(),
        createdAt: DateTime.utc(2030, 7, 2),
      ),
    AppDeviceSession(
      id: '123e4567-e89b-12d3-a456-426614174003',
      name: 'iPad Air',
      current: false,
      trusted: true,
      lastSeenAt: DateTime.now().subtract(const Duration(days: 1)).toUtc(),
      createdAt: DateTime.utc(2030, 7, 3),
    ),
    AppDeviceSession(
      id: '123e4567-e89b-12d3-a456-426614174004',
      name: 'Daylink Android',
      current: false,
      trusted: false,
      lastSeenAt: DateTime.now().toUtc(),
      createdAt: DateTime.utc(2030, 7, 4),
    ),
  ];

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
  Future<void> revokeDeviceSession(String deviceId) async {
    revokedIds.add(deviceId);
  }

  @override
  Future<void> revokeOtherDeviceSessions() async {}

  @override
  Future<AppSessionCredentials?> restore() async => null;
}
