import 'package:daylink_mobile/src/domain/notifications/notification_settings.dart';
import 'package:daylink_mobile/src/presentation/notification_settings_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders approved notification settings layout', (tester) async {
    final source = _FakeNotificationSettingsSource();
    await tester.pumpWidget(
      MaterialApp(home: NotificationSettingsPage(source: source)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-settings-title')),
      findsOneWidget,
    );
    expect(find.text('日程提醒'), findsOneWidget);
    expect(find.text('提醒通知'), findsOneWidget);
    expect(find.text('接收日程开始前提醒'), findsOneWidget);
    expect(find.text('默认提前提醒'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget);
    expect(find.text('提醒方式'), findsOneWidget);
    expect(find.text('声音与震动'), findsOneWidget);
    expect(find.text('系统通知权限'), findsOneWidget);
    expect(find.text('已开启'), findsOneWidget);
    expect(find.text('系统权限关闭后，Daylink 无法发送原生提醒。'), findsOneWidget);
  });

  testWidgets('persists switches, lead time and opens system settings', (
    tester,
  ) async {
    final source = _FakeNotificationSettingsSource();
    await tester.pumpWidget(
      MaterialApp(home: NotificationSettingsPage(source: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(source.state.remindersEnabled, isFalse);

    await tester.tap(find.byKey(const Key('notification-default-lead')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-lead-30')));
    await tester.pumpAndSettle();
    expect(source.state.defaultLeadMinutes, 30);
    expect(find.text('30 分钟'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch).last);
    await tester.pumpAndSettle();
    expect(source.state.soundAndVibrationEnabled, isFalse);

    await tester.tap(find.byKey(const Key('notification-system-permission')));
    await tester.pumpAndSettle();
    expect(source.openedSystemSettings, 1);
  });
}

class _FakeNotificationSettingsSource implements NotificationSettingsSource {
  NotificationSettingsState state = const NotificationSettingsState(
    remindersEnabled: true,
    defaultLeadMinutes: 10,
    soundAndVibrationEnabled: true,
    permissionStatus: NotificationPermissionStatus.authorized,
  );
  var openedSystemSettings = 0;

  @override
  Future<NotificationSettingsState> loadNotificationSettings() async => state;

  @override
  Future<void> openSystemNotificationSettings() async {
    openedSystemSettings++;
  }

  @override
  Future<NotificationSettingsState> requestNotificationPermission() async =>
      state;

  @override
  Future<NotificationSettingsState> setDefaultLeadMinutes(int minutes) async {
    state = NotificationSettingsState(
      remindersEnabled: state.remindersEnabled,
      defaultLeadMinutes: minutes,
      soundAndVibrationEnabled: state.soundAndVibrationEnabled,
      permissionStatus: state.permissionStatus,
    );
    return state;
  }

  @override
  Future<NotificationSettingsState> setRemindersEnabled(bool enabled) async {
    state = NotificationSettingsState(
      remindersEnabled: enabled,
      defaultLeadMinutes: state.defaultLeadMinutes,
      soundAndVibrationEnabled: state.soundAndVibrationEnabled,
      permissionStatus: state.permissionStatus,
    );
    return state;
  }

  @override
  Future<NotificationSettingsState> setSoundAndVibrationEnabled(
    bool enabled,
  ) async {
    state = NotificationSettingsState(
      remindersEnabled: state.remindersEnabled,
      defaultLeadMinutes: state.defaultLeadMinutes,
      soundAndVibrationEnabled: enabled,
      permissionStatus: state.permissionStatus,
    );
    return state;
  }
}
