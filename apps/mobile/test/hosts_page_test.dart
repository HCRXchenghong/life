import 'package:daylink_mobile/src/data/operations_repository.dart';
import 'package:daylink_mobile/src/domain/operations/operations_models.dart';
import 'package:daylink_mobile/src/presentation/app_navigation.dart';
import 'package:daylink_mobile/src/presentation/hosts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved minimal hosts layout from account data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _FakeHostSource(_hosts);

    await tester.pumpWidget(
      MaterialApp(
        home: HostsPage(
          source: source,
          onAddHost: () {},
          onOpenHost: (_) {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hosts-title')), findsOneWidget);
    expect(find.text('连接和管理你的设备'), findsOneWidget);
    expect(find.text('搜索主机'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('生产服务器'), findsOneWidget);
    expect(find.text('192.168.1.20 · Ubuntu'), findsOneWidget);
    expect(find.text('Mac Studio'), findsOneWidget);
    expect(find.text('192.168.1.35 · macOS'), findsOneWidget);
    expect(find.text('Windows 工作站'), findsOneWidget);
    expect(find.text('192.168.1.50 · Windows'), findsOneWidget);
    expect(find.text('在线'), findsNWidgets(2));
    expect(find.text('离线'), findsOneWidget);

    final hostsIcon = tester.widget<Icon>(
      find.byIcon(Icons.desktop_windows_outlined).last,
    );
    final scheduleIcon = tester.widget<Icon>(
      find.byIcon(Icons.event_available_outlined),
    );
    expect(hostsIcon.color, const Color(0xFF3370FF));
    expect(scheduleIcon.color, const Color(0xFF646A73));
    expect(tester.takeException(), isNull);
  });

  testWidgets('search, favorite filter, rows and navigation are functional', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _FakeHostSource(_hosts);
    final actions = <String>[];
    final destinations = <AppDestination>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HostsPage(
          source: source,
          onAddHost: () => actions.add('add'),
          onOpenHost: (host) => actions.add(host.id),
          onDestinationSelected: destinations.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hosts-add')));
    await tester.tap(find.byKey(const Key('host-production')));
    expect(actions, ['add', 'production']);

    await tester.enterText(find.byKey(const Key('hosts-search')), 'Mac');
    await tester.pump(const Duration(milliseconds: 251));
    await tester.pumpAndSettle();
    expect(source.lastQuery, 'Mac');
    expect(find.text('Mac Studio'), findsOneWidget);
    expect(find.text('生产服务器'), findsNothing);

    await tester.enterText(find.byKey(const Key('hosts-search')), '');
    await tester.pump(const Duration(milliseconds: 251));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hosts-filter-favorites')));
    await tester.pumpAndSettle();
    expect(source.lastFavoritesOnly, isTrue);
    expect(find.text('生产服务器'), findsOneWidget);
    expect(find.text('Mac Studio'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-schedule')));
    await tester.tap(find.byKey(const Key('nav-toolbox')));
    await tester.tap(find.byKey(const Key('nav-assistant')));
    await tester.tap(find.byKey(const Key('nav-me')));
    expect(destinations, [
      AppDestination.schedule,
      AppDestination.toolbox,
      AppDestination.assistant,
      AppDestination.me,
    ]);
  });
}

const _hosts = [
  HostSearchResult(
    host: HostProfileModel(
      id: 'production',
      name: '生产服务器',
      address: '192.168.1.20',
      port: 22,
      username: 'deploy',
      terminalMode: TerminalMode.persistent,
      favorite: true,
      agentState: 'online',
      system: 'Ubuntu',
    ),
    tags: [],
  ),
  HostSearchResult(
    host: HostProfileModel(
      id: 'mac-studio',
      name: 'Mac Studio',
      address: '192.168.1.35',
      port: 22,
      username: 'seron',
      terminalMode: TerminalMode.direct,
      agentState: 'offline',
      system: 'macOS',
    ),
    tags: [],
  ),
  HostSearchResult(
    host: HostProfileModel(
      id: 'windows',
      name: 'Windows 工作站',
      address: '192.168.1.50',
      port: 22,
      username: 'operator',
      terminalMode: TerminalMode.direct,
      agentState: 'online',
      system: 'Windows',
    ),
    tags: [],
  ),
];

class _FakeHostSource implements HostListSource {
  _FakeHostSource(this.hosts);

  final List<HostSearchResult> hosts;
  String lastQuery = '';
  bool lastFavoritesOnly = false;

  @override
  Future<List<HostSearchResult>> searchHosts({
    String query = '',
    String? groupId,
    String? tagId,
    bool favoritesOnly = false,
  }) async {
    lastQuery = query;
    lastFavoritesOnly = favoritesOnly;
    final normalized = query.trim().toLowerCase();
    return hosts
        .where(
          (result) =>
              (!favoritesOnly || result.host.favorite) &&
              (normalized.isEmpty ||
                  result.host.name.toLowerCase().contains(normalized) ||
                  result.host.address.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
  }
}
