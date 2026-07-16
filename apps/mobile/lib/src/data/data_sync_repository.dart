import 'package:drift/drift.dart';

import '../domain/sync/data_sync_models.dart';
import 'app_database.dart';

class EncryptedSyncChangeDraft {
  const EncryptedSyncChangeDraft({
    required this.cursor,
    required this.collection,
    required this.objectId,
    required this.operationId,
    required this.deviceId,
    required this.revision,
    required this.deleted,
    required this.ciphertext,
    required this.nonce,
    required this.keyVersion,
    required this.clientUpdatedAt,
    required this.serverUpdatedAt,
  });

  final int cursor;
  final String collection;
  final String objectId;
  final String operationId;
  final String deviceId;
  final int revision;
  final bool deleted;
  final Uint8List? ciphertext;
  final Uint8List? nonce;
  final int? keyVersion;
  final DateTime clientUpdatedAt;
  final DateTime serverUpdatedAt;
}

class DataSyncRepository {
  DataSyncRepository(this._db);

  static const _stateId = 1;
  final AppDatabase _db;

  Future<DataSyncState> loadState({
    DataEncryptionStatus encryptionStatus = DataEncryptionStatus.locked,
  }) async {
    final state = await (_db.select(
      _db.dataSyncPreferences,
    )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
    final cached = await _db.select(_db.encryptedSyncChanges).get();
    var bytes = 0;
    for (final change in cached) {
      bytes += change.ciphertext?.length ?? 0;
      bytes += change.nonce?.length ?? 0;
    }
    return DataSyncState(
      autoSyncEnabled: state?.autoSyncEnabled ?? true,
      lastSyncedAt: state?.lastSyncedAt?.toUtc(),
      encryptionStatus: encryptionStatus,
      cachedChangeCount: cached.length,
      cachedCiphertextBytes: bytes,
    );
  }

  Future<bool> autoSyncEnabled() async {
    final state = await (_db.select(
      _db.dataSyncPreferences,
    )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
    return state?.autoSyncEnabled ?? true;
  }

  Future<int> cursor() async {
    final state = await (_db.select(
      _db.dataSyncPreferences,
    )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
    return state?.cursor ?? 0;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final current = await (_db.select(
      _db.dataSyncPreferences,
    )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
    await _db
        .into(_db.dataSyncPreferences)
        .insertOnConflictUpdate(
          DataSyncPreferencesCompanion.insert(
            id: const Value(_stateId),
            autoSyncEnabled: Value(enabled),
            cursor: Value(current?.cursor ?? 0),
            lastSyncedAt: Value(current?.lastSyncedAt),
          ),
        );
  }

  Future<void> applyPage({
    required List<EncryptedSyncChangeDraft> changes,
    required int cursor,
    required DateTime syncedAt,
  }) async {
    final currentCursor = await this.cursor();
    if (cursor < currentCursor) {
      throw StateError('Sync cursor cannot move backwards');
    }
    await _db.transaction(() async {
      if (changes.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(
            _db.encryptedSyncChanges,
            changes
                .map(
                  (change) => EncryptedSyncChangesCompanion.insert(
                    cursor: Value(change.cursor),
                    collectionName: change.collection,
                    objectId: change.objectId,
                    operationId: change.operationId,
                    deviceId: change.deviceId,
                    revision: change.revision,
                    deleted: change.deleted,
                    ciphertext: Value(change.ciphertext),
                    nonce: Value(change.nonce),
                    keyVersion: Value(change.keyVersion),
                    clientUpdatedAt: change.clientUpdatedAt.toUtc(),
                    serverUpdatedAt: change.serverUpdatedAt.toUtc(),
                  ),
                )
                .toList(growable: false),
          );
        });
      }
      final state = await (_db.select(
        _db.dataSyncPreferences,
      )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
      await _db
          .into(_db.dataSyncPreferences)
          .insertOnConflictUpdate(
            DataSyncPreferencesCompanion.insert(
              id: const Value(_stateId),
              autoSyncEnabled: Value(state?.autoSyncEnabled ?? true),
              cursor: Value(cursor),
              lastSyncedAt: Value(syncedAt.toUtc()),
            ),
          );
    });
  }

  Future<void> clearCache() async {
    await _db.transaction(() async {
      await _db.delete(_db.encryptedSyncChanges).go();
      final state = await (_db.select(
        _db.dataSyncPreferences,
      )..where((table) => table.id.equals(_stateId))).getSingleOrNull();
      await _db
          .into(_db.dataSyncPreferences)
          .insertOnConflictUpdate(
            DataSyncPreferencesCompanion.insert(
              id: const Value(_stateId),
              autoSyncEnabled: Value(state?.autoSyncEnabled ?? true),
              cursor: const Value(0),
              lastSyncedAt: const Value(null),
            ),
          );
    });
  }
}
