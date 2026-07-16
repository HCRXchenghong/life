import 'package:daylink_mobile/src/domain/sync/data_sync_models.dart';
import 'package:daylink_mobile/src/presentation/data_sync_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved data and sync layout', (tester) async {
    final source = _FakeDataSyncSource();
    await tester.pumpWidget(
      MaterialApp(
        home: DataSyncPage(source: source, onOpenEncryption: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data-sync-title')), findsOneWidget);
    expect(find.text('自动同步'), findsOneWidget);
    expect(find.text('在已登录设备间保持数据最新'), findsOneWidget);
    expect(find.text('立即同步'), findsOneWidget);
    expect(find.text('刚刚'), findsOneWidget);
    expect(find.text('同步范围'), findsOneWidget);
    expect(find.text('日程、对话与主机'), findsOneWidget);
    expect(find.text('本地缓存'), findsOneWidget);
    expect(find.text('端到端加密'), findsOneWidget);
    expect(find.text('仅你的设备可以解密'), findsOneWidget);
    expect(find.text('已开启'), findsOneWidget);
    expect(find.text('新设备登录后，将自动恢复已同步的数据。'), findsOneWidget);
  });

  testWidgets('wires auto sync, manual sync, cache and encryption actions', (
    tester,
  ) async {
    final source = _FakeDataSyncSource();
    var openedEncryption = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DataSyncPage(
          source: source,
          onOpenEncryption: () => openedEncryption++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(source.state.autoSyncEnabled, isFalse);

    await tester.tap(find.byKey(const Key('sync-now')));
    await tester.pumpAndSettle();
    expect(source.syncCalls, 1);

    await tester.tap(find.byKey(const Key('sync-range')));
    await tester.pumpAndSettle();
    expect(find.textContaining('SSH 密码'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sync-cache')));
    await tester.pumpAndSettle();
    expect(find.text('2 项加密变更 · 2.0 KB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sync-cache-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sync-cache-clear-confirm')));
    await tester.pumpAndSettle();
    expect(source.state.cachedChangeCount, 0);

    await tester.tap(find.byKey(const Key('sync-encryption')));
    await tester.pumpAndSettle();
    expect(openedEncryption, 1);
  });

  testWidgets('shows truthful locked-key state', (tester) async {
    final source = _FakeDataSyncSource(
      encryptionStatus: DataEncryptionStatus.locked,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DataSyncPage(source: source, onOpenEncryption: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待解锁'), findsOneWidget);
    expect(find.text('需要受信设备或恢复密钥'), findsOneWidget);
    expect(find.textContaining('受信设备或恢复密钥解锁'), findsOneWidget);
    expect(find.text('已开启'), findsNothing);
  });
}

class _FakeDataSyncSource implements DataSyncSource {
  _FakeDataSyncSource({
    DataEncryptionStatus encryptionStatus = DataEncryptionStatus.unlocked,
  }) : state = DataSyncState(
         autoSyncEnabled: true,
         lastSyncedAt: DateTime.now().toUtc(),
         encryptionStatus: encryptionStatus,
         cachedChangeCount: 2,
         cachedCiphertextBytes: 2048,
       );

  DataSyncState state;
  var syncCalls = 0;

  @override
  Future<DataSyncState> clearLocalSyncCache() async {
    state = _copy(cachedChangeCount: 0, cachedCiphertextBytes: 0);
    return state;
  }

  @override
  Future<DataSyncState> loadDataSyncState() async => state;

  @override
  Future<DataSyncState> setAutoSyncEnabled(bool enabled) async {
    state = _copy(autoSyncEnabled: enabled);
    return state;
  }

  @override
  Future<DataSyncState> syncNow() async {
    syncCalls++;
    state = _copy(lastSyncedAt: DateTime.now().toUtc());
    return state;
  }

  DataSyncState _copy({
    bool? autoSyncEnabled,
    DateTime? lastSyncedAt,
    int? cachedChangeCount,
    int? cachedCiphertextBytes,
  }) => DataSyncState(
    autoSyncEnabled: autoSyncEnabled ?? state.autoSyncEnabled,
    lastSyncedAt: lastSyncedAt ?? state.lastSyncedAt,
    encryptionStatus: state.encryptionStatus,
    cachedChangeCount: cachedChangeCount ?? state.cachedChangeCount,
    cachedCiphertextBytes: cachedCiphertextBytes ?? state.cachedCiphertextBytes,
  );
}
