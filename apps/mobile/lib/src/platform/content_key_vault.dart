import '../rust/api/mobile.dart' as rust;

enum LocalContentKeyStatus { missing, pendingRecoveryConfirmation, ready }

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

class LocalDeviceApprovalRequestKey {
  const LocalDeviceApprovalRequestKey({
    required this.publicKey,
    required this.verificationCode,
  });

  final List<int> publicKey;
  final String verificationCode;
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

  Future<LocalDeviceApprovalPackage> approveDeviceRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> requesterPublicKey,
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
}
