import 'package:daylink_mobile/src/application/assistant_settings.dart';
import 'package:daylink_mobile/src/data/ai_gateway_client.dart';
import 'package:daylink_mobile/src/presentation/app_navigation.dart';
import 'package:daylink_mobile/src/presentation/my_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders actual monthly quota and no weekly quota', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MyPage(
          username: 'seron',
          source: _FakeEntitlementSource(_proEntitlement),
          onOpenAccount: () {},
          onOpenNotifications: () {},
          onOpenSync: () {},
          onLogout: () async {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-title')), findsOneWidget);
    expect(find.text('账号、套餐与偏好'), findsOneWidget);
    expect(find.text('seron'), findsOneWidget);
    expect(find.text('Pro 套餐'), findsNWidgets(2));
    expect(find.text('有效至 2026年12月31日'), findsOneWidget);
    expect(find.text('本月额度'), findsOneWidget);
    expect(find.text('1.8 / 5 亿 Token'), findsOneWidget);
    expect(find.textContaining('本周'), findsNothing);
    expect(find.text('账号与安全'), findsOneWidget);
    expect(find.text('通知设置'), findsOneWidget);
    expect(find.text('数据与同步'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);

    final meIcon = tester.widget<Icon>(
      find.byIcon(Icons.person_outline_rounded),
    );
    final hostsIcon = tester.widget<Icon>(
      find.byIcon(Icons.desktop_windows_outlined),
    );
    expect(meIcon.color, const Color(0xFF3370FF));
    expect(hostsIcon.color, const Color(0xFF646A73));
    expect(tester.takeException(), isNull);
  });

  testWidgets('account actions, logout and navigation are functional', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final actions = <String>[];
    final destinations = <AppDestination>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MyPage(
          username: 'daylink-user',
          source: _FakeEntitlementSource(_proEntitlement),
          onOpenAccount: () => actions.add('security'),
          onOpenNotifications: () => actions.add('notifications'),
          onOpenSync: () => actions.add('sync'),
          onLogout: () async => actions.add('logout'),
          onDestinationSelected: destinations.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-account')));
    await tester.tap(find.byKey(const Key('my-security')));
    await tester.tap(find.byKey(const Key('my-notifications')));
    await tester.tap(find.byKey(const Key('my-sync')));
    await tester.tap(find.byKey(const Key('my-logout')));
    await tester.pumpAndSettle();
    expect(actions, [
      'security',
      'security',
      'notifications',
      'sync',
      'logout',
    ]);

    await tester.tap(find.byKey(const Key('nav-schedule')));
    await tester.tap(find.byKey(const Key('nav-toolbox')));
    await tester.tap(find.byKey(const Key('nav-assistant')));
    await tester.tap(find.byKey(const Key('nav-hosts')));
    expect(destinations, [
      AppDestination.schedule,
      AppDestination.toolbox,
      AppDestination.assistant,
      AppDestination.hosts,
    ]);
  });

  testWidgets('Max plan reflects the unlimited monthly allowance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyPage(
          username: 'max-user',
          source: _FakeEntitlementSource(
            AiEntitlement(
              active: true,
              plan: 'max',
              cardType: 'year',
              expiresAt: DateTime.utc(2027, 1, 1, 12),
              monthlyUsed: 900000000,
              monthlyLimit: null,
              monthlyResetsAt: DateTime.utc(2026, 8),
              supportedModes: const [
                AiExecutionMode.localAI,
                AiExecutionMode.sshAgent,
              ],
            ),
          ),
          onOpenAccount: () {},
          onOpenNotifications: () {},
          onOpenSync: () {},
          onLogout: () async {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Max 套餐'), findsNWidgets(2));
    expect(find.text('无限额'), findsOneWidget);
  });
}

final _proEntitlement = AiEntitlement(
  active: true,
  plan: 'pro',
  cardType: 'year',
  expiresAt: DateTime.utc(2026, 12, 31, 12),
  monthlyUsed: 180000000,
  monthlyLimit: 500000000,
  monthlyResetsAt: DateTime.utc(2027, 1),
  supportedModes: const [AiExecutionMode.localAI, AiExecutionMode.sshAgent],
);

class _FakeEntitlementSource implements AccountEntitlementSource {
  _FakeEntitlementSource(this.entitlement);

  final AiEntitlement entitlement;

  @override
  Future<AiEntitlement> loadAccountEntitlement() async => entitlement;
}
