import 'dart:typed_data';

import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/data_sync_repository.dart';
import 'package:daylink_mobile/src/domain/sync/data_sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DataSyncRepository repository;

  setUp(() {
    database = AppDatabase.inMemory();
    repository = DataSyncRepository(database);
  });

  tearDown(() => database.close());

  test(
    'stores encrypted changes and advances cursor transactionally',
    () async {
      await repository.applyPage(
        changes: [
          EncryptedSyncChangeDraft(
            cursor: 1,
            collection: 'schedule_events',
            objectId: '123e4567-e89b-12d3-a456-426614174001',
            operationId: '123e4567-e89b-12d3-a456-426614174002',
            deviceId: '123e4567-e89b-12d3-a456-426614174003',
            revision: 1,
            deleted: false,
            ciphertext: Uint8List.fromList([1, 2, 3]),
            nonce: Uint8List.fromList(List<int>.filled(12, 7)),
            keyVersion: 1,
            clientUpdatedAt: DateTime.utc(2030),
            serverUpdatedAt: DateTime.utc(2030, 1, 1, 0, 0, 1),
          ),
        ],
        cursor: 1,
        syncedAt: DateTime.utc(2030, 1, 1, 0, 0, 2),
      );

      final state = await repository.loadState(
        encryptionStatus: DataEncryptionStatus.locked,
      );
      expect(await repository.cursor(), 1);
      expect(state.cachedChangeCount, 1);
      expect(state.cachedCiphertextBytes, 15);
      expect(state.lastSyncedAt, DateTime.utc(2030, 1, 1, 0, 0, 2));
      expect(state.encryptionStatus, DataEncryptionStatus.locked);
    },
  );

  test(
    'clearing cache resets cursor without deleting account content',
    () async {
      await repository.setAutoSyncEnabled(false);
      await repository.clearCache();

      final state = await repository.loadState();
      expect(state.autoSyncEnabled, isFalse);
      expect(state.cachedChangeCount, 0);
      expect(await repository.cursor(), 0);
    },
  );
}
