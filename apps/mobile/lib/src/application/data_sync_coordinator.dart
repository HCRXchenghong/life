import '../data/app_session_monitor.dart';
import '../data/data_sync_client.dart';
import '../data/data_sync_repository.dart';
import '../domain/sync/data_sync_models.dart';

typedef EncryptionStatusProvider = Future<DataEncryptionStatus> Function();

class DataSyncCoordinator implements DataSyncSource {
  factory DataSyncCoordinator({
    required DataSyncRepository repository,
    required DataSyncClient client,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    EncryptionStatusProvider? encryptionStatus,
  }) => DataSyncCoordinator._(
    repository,
    client,
    accessToken,
    refreshAccessToken,
    encryptionStatus ?? (() async => DataEncryptionStatus.locked),
  );

  DataSyncCoordinator._(
    this._repository,
    this._client,
    this._accessToken,
    this._refreshAccessToken,
    this._encryptionStatus,
  );

  final DataSyncRepository _repository;
  final DataSyncClient _client;
  final AccessTokenProvider _accessToken;
  final SessionRefreshCallback _refreshAccessToken;
  final EncryptionStatusProvider _encryptionStatus;
  Future<DataSyncState>? _activeSync;
  bool _closed = false;

  @override
  Future<DataSyncState> loadDataSyncState() async =>
      _repository.loadState(encryptionStatus: await _encryptionStatus());

  @override
  Future<DataSyncState> setAutoSyncEnabled(bool enabled) async {
    _ensureOpen();
    await _repository.setAutoSyncEnabled(enabled);
    return enabled ? syncNow() : loadDataSyncState();
  }

  @override
  Future<DataSyncState> syncNow() {
    _ensureOpen();
    final active = _activeSync;
    if (active != null) return active;
    final operation = _pull().whenComplete(() => _activeSync = null);
    _activeSync = operation;
    return operation;
  }

  Future<DataSyncState> _pull() async {
    var cursor = await _repository.cursor();
    var refreshed = false;
    for (var pageIndex = 0; pageIndex < 1000; pageIndex++) {
      if (_closed) throw const DataSyncClientException('同步已取消');
      final token = await _accessToken();
      if (token == null) {
        throw const DataSyncClientException(
          '登录已失效，请重新登录',
          sessionRejected: true,
        );
      }
      DataSyncPage page;
      try {
        page = await _client.changes(accessToken: token, cursor: cursor);
      } on DataSyncClientException catch (error) {
        if (!error.sessionRejected || refreshed) rethrow;
        refreshed = true;
        if (!await _refreshAccessToken()) rethrow;
        pageIndex--;
        continue;
      }
      await _repository.applyPage(
        changes: page.changes,
        cursor: page.cursor,
        syncedAt: DateTime.now().toUtc(),
      );
      cursor = page.cursor;
      if (!page.hasMore) return loadDataSyncState();
    }
    throw const DataSyncClientException('同步变更过多，请稍后重试');
  }

  Future<void> reconcile() async {
    if (_closed || !await _repository.autoSyncEnabled()) return;
    try {
      await syncNow();
    } on Object {
      // Offline and locked-key states are retried by SSE, foreground resume,
      // or an explicit user action. They must never clear authentication.
    }
  }

  @override
  Future<DataSyncState> clearLocalSyncCache() async {
    _ensureOpen();
    await _repository.clearCache();
    return loadDataSyncState();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Data sync is closed');
  }
}
