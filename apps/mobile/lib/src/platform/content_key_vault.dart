import '../rust/api/mobile.dart' as rust;

enum LocalContentKeyStatus {
  missing,
  pendingRecoveryConfirmation,
  pendingRecoveryRotation,
  ready,
}

class LocalContentKeyInitialization {
  const LocalContentKeyInitialization({
    required this.deviceId,
    required this.keyVersion,
    required this.recoveryKey,
    required this.recoverySalt,
    required this.recoveryNonce,
    required this.recoveryCiphertext,
  });

  final String deviceId;
  final int keyVersion;
  final List<int> recoveryKey;
  final List<int> recoverySalt;
  final List<int> recoveryNonce;
  final List<int> recoveryCiphertext;
}

class LocalRecoveryKeyRotation {
  const LocalRecoveryKeyRotation({
    required this.rotationId,
    required this.expectedRevision,
    required this.deviceId,
    required this.keyVersion,
    required this.recoveryKey,
    required this.recoverySalt,
    required this.recoveryNonce,
    required this.recoveryCiphertext,
  });

  final String rotationId;
  final int expectedRevision;
  final String deviceId;
  final int keyVersion;
  final List<int> recoveryKey;
  final List<int> recoverySalt;
  final List<int> recoveryNonce;
  final List<int> recoveryCiphertext;
}

class LocalDeviceApprovalRequestKey {
  const LocalDeviceApprovalRequestKey({
    required this.requestId,
    required this.publicKey,
    required this.requestToken,
    required this.verificationCode,
    required this.expiresAtUnixMs,
  });

  final String requestId;
  final List<int> publicKey;
  final List<int> requestToken;
  final String verificationCode;
  final int expiresAtUnixMs;
}

class LocalDeviceApprovalPackage {
  const LocalDeviceApprovalPackage({
    required this.approverPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.keyVersion,
    required this.verificationCode,
  });

  final List<int> approverPublicKey;
  final List<int> nonce;
  final List<int> ciphertext;
  final int keyVersion;
  final String verificationCode;
}

abstract interface class ContentKeyVault {
  Future<List<int>> generateDeviceVaultKey();

  Future<LocalContentKeyStatus> status({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  });

  Future<LocalContentKeyInitialization> initialize({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  });

  Future<void> acknowledgeRecoveryKeySaved({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  });

  Future<LocalRecoveryKeyRotation> prepareRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required int expectedRevision,
  });

  Future<void> commitRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String rotationId,
  });

  Future<void> discardRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String rotationId,
  });

  Future<void> discardPending({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  });

  Future<bool> restore({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required List<int> recoveryKey,
    required int keyVersion,
    required List<int> recoverySalt,
    required List<int> recoveryNonce,
    required List<int> recoveryCiphertext,
  });

  Future<String> deviceApprovalVerificationCode({
    required String accountId,
    required String requestId,
    required List<int> requesterPublicKey,
  });

  Future<LocalDeviceApprovalRequestKey> createDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required int expiresAtUnixMs,
  });

  Future<LocalDeviceApprovalRequestKey?> loadDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  });

  Future<void> discardDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
  });

  Future<LocalDeviceApprovalPackage> approveDeviceRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> requesterPublicKey,
  });

  Future<bool> completeDeviceApproval({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> approverPublicKey,
    required List<int> nonce,
    required List<int> ciphertext,
    required int keyVersion,
    required List<int> recoverySalt,
    required List<int> recoveryNonce,
    required List<int> recoveryCiphertext,
  });
}

class NativeContentKeyVault implements ContentKeyVault {
  const NativeContentKeyVault();

  @override
  Future<List<int>> generateDeviceVaultKey() => rust.generateDeviceVaultKey();

  @override
  Future<LocalContentKeyStatus> status({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async => switch (await rust.contentKeyStatus(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
  )) {
    rust.BridgeContentKeyStatus.missing => LocalContentKeyStatus.missing,
    rust.BridgeContentKeyStatus.pendingRecoveryConfirmation =>
      LocalContentKeyStatus.pendingRecoveryConfirmation,
    rust.BridgeContentKeyStatus.pendingRecoveryRotation =>
      LocalContentKeyStatus.pendingRecoveryRotation,
    rust.BridgeContentKeyStatus.ready => LocalContentKeyStatus.ready,
  };

  @override
  Future<LocalContentKeyInitialization> initialize({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async {
    final result = await rust.initializeContentKey(
      vaultPath: vaultPath,
      accountId: accountId,
      deviceVaultKey: deviceVaultKey,
    );
    return LocalContentKeyInitialization(
      deviceId: result.deviceId,
      keyVersion: result.keyVersion,
      recoveryKey: result.recoveryKey,
      recoverySalt: result.recoverySalt,
      recoveryNonce: result.recoveryNonce,
      recoveryCiphertext: result.recoveryCiphertext,
    );
  }

  @override
  Future<void> acknowledgeRecoveryKeySaved({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) => rust.acknowledgeRecoveryKeySaved(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
  );

  @override
  Future<LocalRecoveryKeyRotation> prepareRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required int expectedRevision,
  }) async {
    final result = await rust.prepareRecoveryKeyRotation(
      vaultPath: vaultPath,
      accountId: accountId,
      deviceVaultKey: deviceVaultKey,
      expectedRevision: BigInt.from(expectedRevision),
    );
    return LocalRecoveryKeyRotation(
      rotationId: result.rotationId,
      expectedRevision: result.expectedRevision.toInt(),
      deviceId: result.deviceId,
      keyVersion: result.keyVersion,
      recoveryKey: result.recoveryKey,
      recoverySalt: result.recoverySalt,
      recoveryNonce: result.recoveryNonce,
      recoveryCiphertext: result.recoveryCiphertext,
    );
  }

  @override
  Future<void> commitRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String rotationId,
  }) => rust.commitRecoveryKeyRotation(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
    rotationId: rotationId,
  );

  @override
  Future<void> discardRecoveryKeyRotation({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String rotationId,
  }) => rust.discardRecoveryKeyRotation(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
    rotationId: rotationId,
  );

  @override
  Future<void> discardPending({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) => rust.discardPendingContentKey(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
  );

  @override
  Future<bool> restore({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required List<int> recoveryKey,
    required int keyVersion,
    required List<int> recoverySalt,
    required List<int> recoveryNonce,
    required List<int> recoveryCiphertext,
  }) => rust.restoreContentKey(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
    recoveryKey: recoveryKey,
    keyVersion: keyVersion,
    recoverySalt: recoverySalt,
    recoveryNonce: recoveryNonce,
    recoveryCiphertext: recoveryCiphertext,
  );

  @override
  Future<String> deviceApprovalVerificationCode({
    required String accountId,
    required String requestId,
    required List<int> requesterPublicKey,
  }) => rust.deviceApprovalVerificationCode(
    accountId: accountId,
    requestId: requestId,
    requesterPublicKey: requesterPublicKey,
  );

  @override
  Future<LocalDeviceApprovalRequestKey> createDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required int expiresAtUnixMs,
  }) async => _requestKey(
    await rust.createDeviceApprovalRequest(
      vaultPath: vaultPath,
      accountId: accountId,
      deviceVaultKey: deviceVaultKey,
      requestId: requestId,
      expiresAtUnixMs: BigInt.from(expiresAtUnixMs),
    ),
  );

  @override
  Future<LocalDeviceApprovalRequestKey?> loadDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async {
    final result = await rust.loadDeviceApprovalRequest(
      vaultPath: vaultPath,
      accountId: accountId,
      deviceVaultKey: deviceVaultKey,
    );
    return result == null ? null : _requestKey(result);
  }

  @override
  Future<void> discardDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
  }) => rust.discardDeviceApprovalRequest(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
    requestId: requestId,
  );

  @override
  Future<LocalDeviceApprovalPackage> approveDeviceRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> requesterPublicKey,
  }) async {
    final result = await rust.approveDeviceRequest(
      vaultPath: vaultPath,
      accountId: accountId,
      deviceVaultKey: deviceVaultKey,
      requestId: requestId,
      requesterPublicKey: requesterPublicKey,
    );
    return LocalDeviceApprovalPackage(
      approverPublicKey: result.approverPublicKey,
      nonce: result.nonce,
      ciphertext: result.ciphertext,
      keyVersion: result.keyVersion,
      verificationCode: result.verificationCode,
    );
  }

  @override
  Future<bool> completeDeviceApproval({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> approverPublicKey,
    required List<int> nonce,
    required List<int> ciphertext,
    required int keyVersion,
    required List<int> recoverySalt,
    required List<int> recoveryNonce,
    required List<int> recoveryCiphertext,
  }) => rust.completeDeviceApproval(
    vaultPath: vaultPath,
    accountId: accountId,
    deviceVaultKey: deviceVaultKey,
    requestId: requestId,
    approverPublicKey: approverPublicKey,
    nonce: nonce,
    ciphertext: ciphertext,
    keyVersion: keyVersion,
    recoverySalt: recoverySalt,
    recoveryNonce: recoveryNonce,
    recoveryCiphertext: recoveryCiphertext,
  );
}

LocalDeviceApprovalRequestKey _requestKey(
  rust.BridgeDeviceApprovalRequestKey result,
) => LocalDeviceApprovalRequestKey(
  requestId: result.requestId,
  publicKey: result.publicKey,
  requestToken: result.requestToken,
  verificationCode: result.verificationCode,
  expiresAtUnixMs: result.expiresAtUnixMs.toInt(),
);
