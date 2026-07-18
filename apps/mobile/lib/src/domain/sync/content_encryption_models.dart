import 'dart:typed_data';

enum ContentEncryptionSetupStatus {
  notConfigured,
  recoveryPending,
  enabled,
  locked,
}

class ContentEncryptionState {
  const ContentEncryptionState({required this.status, this.keyVersion})
    : assert(keyVersion == null || keyVersion > 0);

  final ContentEncryptionSetupStatus status;
  final int? keyVersion;

  bool get isUnlocked =>
      status == ContentEncryptionSetupStatus.enabled ||
      status == ContentEncryptionSetupStatus.recoveryPending;
}

const currentContentKeyVersion = 1;
const contentEncryptionAlgorithmLabel = 'AES-256-GCM';

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
        buffer = bits == 0 ? 0 : buffer & ((1 << bits) - 1);
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

class RecoveryKeyRotationDraft {
  const RecoveryKeyRotationDraft({
    required this.rotationId,
    required this.recoveryKey,
  });

  final String rotationId;
  final RecoveryKeyDraft recoveryKey;

  @override
  String toString() =>
      'RecoveryKeyRotationDraft(rotationId: $rotationId, recoveryKey: <redacted>)';
}

abstract interface class ContentEncryptionSource {
  Future<ContentEncryptionState> loadContentEncryptionState();

  Future<RecoveryKeyDraft> prepareContentEncryption();

  Future<void> acknowledgeRecoveryKeySaved();

  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation();

  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId);

  Future<void> restoreWithRecoveryKey(String encodedKey);
}

class TrustedDeviceApprovalRequest {
  const TrustedDeviceApprovalRequest({
    required this.id,
    required this.deviceName,
    required this.requesterPublicKey,
    required this.verificationCode,
    required this.createdAt,
    required this.expiresAt,
    this.locationLabel,
  });

  final String id;
  final String deviceName;
  final Uint8List requesterPublicKey;
  final String verificationCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? locationLabel;

  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());

  @override
  String toString() =>
      'TrustedDeviceApprovalRequest(id: $id, deviceName: $deviceName, '
      'requesterPublicKey: <redacted>, verificationCode: <redacted>)';
}

abstract interface class TrustedDeviceApprovalSource {
  Future<TrustedDeviceApprovalRequest?> loadPendingDeviceApproval();

  Future<void> approveDevice(TrustedDeviceApprovalRequest request);

  Future<void> rejectDevice(TrustedDeviceApprovalRequest request);
}

class DeviceApprovalWaitingSession {
  DeviceApprovalWaitingSession({
    required this.id,
    required List<int> requestToken,
    required this.verificationCode,
    required this.deviceName,
    required this.createdAt,
    required this.expiresAt,
  }) : requestToken = Uint8List.fromList(requestToken);

  final String id;
  final Uint8List requestToken;
  final String verificationCode;
  final String deviceName;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());

  @override
  String toString() =>
      'DeviceApprovalWaitingSession(id: $id, requestToken: <redacted>, '
      'verificationCode: <redacted>, deviceName: $deviceName)';
}

enum DeviceApprovalWaitingStatus { pending, completed, rejected, expired }

abstract interface class DeviceApprovalRecoverySource {
  Future<DeviceApprovalWaitingSession> startDeviceApproval();

  Future<DeviceApprovalWaitingStatus> checkDeviceApproval(
    DeviceApprovalWaitingSession session,
  );

  Future<void> cancelDeviceApproval(DeviceApprovalWaitingSession session);
}

abstract final class RecoveryKeyCodec {
  static Uint8List decode(String value) {
    if (value.length > 128) throw const FormatException();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = Uint8List(32);
    var outputIndex = 0;
    var symbolCount = 0;
    var buffer = 0;
    var bits = 0;
    for (final original in value.codeUnits) {
      if (original == 0x2D ||
          original == 0x20 ||
          original == 0x09 ||
          original == 0x0A ||
          original == 0x0D) {
        continue;
      }
      final code = original >= 0x61 && original <= 0x7A
          ? original - 0x20
          : original;
      final decoded = alphabet.indexOf(String.fromCharCode(code));
      if (decoded < 0) {
        output.fillRange(0, output.length, 0);
        throw const FormatException();
      }
      symbolCount++;
      buffer = (buffer << 5) | decoded;
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        if (outputIndex >= output.length) {
          output.fillRange(0, output.length, 0);
          throw const FormatException();
        }
        output[outputIndex++] = (buffer >> bits) & 0xFF;
        buffer = bits == 0 ? 0 : buffer & ((1 << bits) - 1);
      }
    }
    if (symbolCount != 52 ||
        outputIndex != output.length ||
        bits != 4 ||
        buffer != 0) {
      output.fillRange(0, output.length, 0);
      throw const FormatException();
    }
    return output;
  }
}

class ContentEncryptionException implements Exception {
  const ContentEncryptionException(this.message, {this.locked = false});

  final String message;
  final bool locked;

  @override
  String toString() => message;
}
