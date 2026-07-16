enum DataEncryptionStatus { unlocked, locked, unavailable }

class DataSyncState {
  const DataSyncState({
    required this.autoSyncEnabled,
    required this.lastSyncedAt,
    required this.encryptionStatus,
    required this.cachedChangeCount,
    required this.cachedCiphertextBytes,
  });

  final bool autoSyncEnabled;
  final DateTime? lastSyncedAt;
  final DataEncryptionStatus encryptionStatus;
  final int cachedChangeCount;
  final int cachedCiphertextBytes;
}

abstract interface class DataSyncSource {
  Future<DataSyncState> loadDataSyncState();

  Future<DataSyncState> setAutoSyncEnabled(bool enabled);

  Future<DataSyncState> syncNow();

  Future<DataSyncState> clearLocalSyncCache();
}
