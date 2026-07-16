enum ContentEncryptionSetupStatus {
  notConfigured,
  recoveryPending,
  enabled,
  locked,
}

class ContentEncryptionState {
  const ContentEncryptionState({required this.status});

  final ContentEncryptionSetupStatus status;
}

class RecoveryKeyDraft {
  const RecoveryKeyDraft._({required this.encodedKey});

  factory RecoveryKeyDraft.fromBytes(List<int> bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Recovery key must contain 32 bytes');
    }
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var buffer = 0;
    var bits = 0;
    final output = StringBuffer();
    for (final byte in bytes) {
      if (byte < 0 || byte > 255) throw ArgumentError('Invalid key byte');
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) output.write(alphabet[(buffer << (5 - bits)) & 31]);
    final compact = output.toString();
    final grouped = <String>[];
    for (var index = 0; index < compact.length; index += 4) {
      final end = (index + 4).clamp(0, compact.length);
      grouped.add(compact.substring(index, end));
    }
    return RecoveryKeyDraft._(encodedKey: grouped.join('-'));
  }

  final String encodedKey;

  @override
  String toString() => 'RecoveryKeyDraft(<redacted>)';
}

abstract interface class ContentEncryptionSource {
  Future<ContentEncryptionState> loadContentEncryptionState();

  Future<RecoveryKeyDraft> prepareContentEncryption();

  Future<void> acknowledgeRecoveryKeySaved();
}

class ContentEncryptionException implements Exception {
  const ContentEncryptionException(this.message, {this.locked = false});

  final String message;
  final bool locked;

  @override
  String toString() => message;
}
