import 'dart:convert';
import 'dart:typed_data';

import 'package:daylink_mobile/src/application/content_encryption_coordinator.dart';
import 'package:daylink_mobile/src/data/device_vault_key_store.dart';
import 'package:daylink_mobile/src/data/device_approval_client.dart';
import 'package:daylink_mobile/src/data/key_envelope_client.dart';
import 'package:daylink_mobile/src/domain/sync/content_encryption_models.dart';
import 'package:daylink_mobile/src/domain/sync/data_sync_models.dart';
import 'package:daylink_mobile/src/platform/content_key_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports truthful local and remote encryption states', () async {
    final vault = _FakeVault();
    final transport = _FakeEnvelopeTransport();
    final coordinator = _coordinator(vault: vault, transport: transport);

    expect(
      (await coordinator.loadContentEncryptionState()).status,
      ContentEncryptionSetupStatus.notConfigured,
    );
    transport.envelope = _envelope();
    expect(
      (await coordinator.loadContentEncryptionState()).status,
      ContentEncryptionSetupStatus.locked,
    );
    vault.localStatus = LocalContentKeyStatus.ready;
    expect(
      await coordinator.loadDataEncryptionStatus(),
      DataEncryptionStatus.unlocked,
    );
    coordinator.close();
  });

  test(
    'creates one local CMK and uploads only its recovery envelope',
    () async {
      final vault = _FakeVault();
      final transport = _FakeEnvelopeTransport();
      final coordinator = _coordinator(vault: vault, transport: transport);

      final first = await coordinator.prepareContentEncryption();
      final second = await coordinator.prepareContentEncryption();

      expect(vault.initializeCalls, 2);
      expect(transport.storeCalls, 1);
      expect(first.encodedKey, second.encodedKey);
      expect(first.toString(), 'RecoveryKeyDraft(<redacted>)');
      expect(transport.envelope!.ciphertext, hasLength(48));
      expect(
        (await coordinator.loadContentEncryptionState()).status,
        ContentEncryptionSetupStatus.recoveryPending,
      );

      await coordinator.acknowledgeRecoveryKeySaved();
      expect(vault.localStatus, LocalContentKeyStatus.ready);
      coordinator.close();
    },
  );

  test(
    'discards a pending local key when another device wins the race',
    () async {
      final vault = _FakeVault();
      final transport = _FakeEnvelopeTransport()
        ..conflictOnStore = true
        ..winnerAfterConflict = _envelope(ciphertextByte: 9);
      final coordinator = _coordinator(vault: vault, transport: transport);

      await expectLater(
        coordinator.prepareContentEncryption(),
        throwsA(
          isA<ContentEncryptionException>().having(
            (error) => error.locked,
            'locked',
            true,
          ),
        ),
      );
      expect(vault.discardCalls, 1);
      expect(vault.localStatus, LocalContentKeyStatus.missing);
      coordinator.close();
    },
  );

  test('refreshes an expired access token once', () async {
    final vault = _FakeVault();
    final transport = _FakeEnvelopeTransport()..rejectNextLoad = true;
    var refreshes = 0;
    final coordinator = _coordinator(
      vault: vault,
      transport: transport,
      refresh: () async {
        refreshes++;
        return true;
      },
    );

    await coordinator.loadContentEncryptionState();
    expect(refreshes, 1);
    expect(transport.loadCalls, 2);
    coordinator.close();
  });

  test('decodes, restores, and zeroes the recovery key locally', () async {
    final vault = _FakeVault();
    final transport = _FakeEnvelopeTransport()..envelope = _envelope();
    final coordinator = _coordinator(vault: vault, transport: transport);
    final encoded = RecoveryKeyDraft.fromBytes(
      List<int>.generate(32, (index) => index),
    ).encodedKey;

    await coordinator.restoreWithRecoveryKey(encoded.toLowerCase());

    expect(vault.restoreCalls, 1);
    expect(vault.localStatus, LocalContentKeyStatus.ready);
    expect(vault.receivedRecoveryKey, everyElement(0));
    expect(transport.storeCalls, 0);
    expect(
      (await coordinator.loadContentEncryptionState()).status,
      ContentEncryptionSetupStatus.enabled,
    );
    coordinator.close();
  });

  test(
    'rejects malformed and incorrect recovery keys without local writes',
    () async {
      final vault = _FakeVault()..restoreResult = false;
      final transport = _FakeEnvelopeTransport()..envelope = _envelope();
      final coordinator = _coordinator(vault: vault, transport: transport);

      await expectLater(
        coordinator.restoreWithRecoveryKey('NOT-A-RECOVERY-KEY'),
        throwsA(
          isA<ContentEncryptionException>().having(
            (error) => error.message,
            'message',
            '恢复密钥格式不正确',
          ),
        ),
      );
      expect(vault.restoreCalls, 0);

      final encoded = RecoveryKeyDraft.fromBytes(
        List<int>.filled(32, 7),
      ).encodedKey;
      await expectLater(
        coordinator.restoreWithRecoveryKey(encoded),
        throwsA(
          isA<ContentEncryptionException>().having(
            (error) => error.message,
            'message',
            '恢复密钥不正确，请重新检查',
          ),
        ),
      );
      expect(vault.restoreCalls, 1);
      expect(vault.localStatus, LocalContentKeyStatus.missing);
      expect(vault.receivedRecoveryKey, everyElement(0));
      coordinator.close();
    },
  );

  test('does not send a recovery key when no remote envelope exists', () async {
    final vault = _FakeVault();
    final transport = _FakeEnvelopeTransport();
    final coordinator = _coordinator(vault: vault, transport: transport);
    final encoded = RecoveryKeyDraft.fromBytes(
      List<int>.filled(32, 9),
    ).encodedKey;

    await expectLater(
      coordinator.restoreWithRecoveryKey(encoded),
      throwsA(
        isA<ContentEncryptionException>().having(
          (error) => error.message,
          'message',
          '该账号没有可恢复的加密内容',
        ),
      ),
    );
    expect(vault.restoreCalls, 0);
    expect(transport.storeCalls, 0);
    coordinator.close();
  });

  test('recovery key codec rejects non-canonical base32 padding', () {
    final encoded = RecoveryKeyDraft.fromBytes(
      List<int>.filled(32, 0),
    ).encodedKey;
    expect(RecoveryKeyCodec.decode(encoded), List<int>.filled(32, 0));
    expect(
      RecoveryKeyCodec.decode('  ${encoded.toLowerCase()}\n'),
      List<int>.filled(32, 0),
    );
    final compact = encoded.replaceAll('-', '');
    expect(
      () => RecoveryKeyCodec.decode('${compact.substring(0, 51)}B'),
      throwsFormatException,
    );
  });

  test('approves only a matching, unexpired device request', () async {
    final vault = _FakeVault()
      ..localStatus = LocalContentKeyStatus.ready
      ..approvalCode = '482 731';
    final approvals = _FakeApprovalTransport()
      ..requests = [
        RemoteDeviceApprovalRequest(
          id: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
          deviceName: 'Daylink iPhone',
          publicKey: Uint8List.fromList(List<int>.filled(32, 7)),
          createdAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        ),
      ];
    final coordinator = _coordinator(
      vault: vault,
      transport: _FakeEnvelopeTransport(),
      approvals: approvals,
    );

    final request = await coordinator.loadPendingDeviceApproval();
    expect(request, isNotNull);
    expect(request!.verificationCode, '482 731');
    expect(request.toString(), contains('requesterPublicKey: <redacted>'));

    await coordinator.approveDevice(request);
    expect(vault.approveCalls, 1);
    expect(approvals.approveCalls, 1);
    expect(approvals.lastDecision!.ciphertext, List<int>.filled(48, 4));

    await coordinator.rejectDevice(request);
    expect(approvals.rejectCalls, 1);
    coordinator.close();
  });

  test(
    'never uploads an approval package when verification codes differ',
    () async {
      final vault = _FakeVault()
        ..localStatus = LocalContentKeyStatus.ready
        ..approvalCode = '111 222'
        ..packageCode = '333 444';
      final approvals = _FakeApprovalTransport();
      final coordinator = _coordinator(
        vault: vault,
        transport: _FakeEnvelopeTransport(),
        approvals: approvals,
      );
      final request = TrustedDeviceApprovalRequest(
        id: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
        deviceName: 'Daylink iPhone',
        requesterPublicKey: Uint8List.fromList(List<int>.filled(32, 7)),
        verificationCode: '111 222',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );

      await expectLater(
        coordinator.approveDevice(request),
        throwsA(
          isA<ContentEncryptionException>().having(
            (error) => error.message,
            'message',
            contains('验证码不一致'),
          ),
        ),
      );
      expect(approvals.approveCalls, 0);
      coordinator.close();
    },
  );

  test('new device restores locally before consuming server trust', () async {
    final vault = _FakeVault();
    final envelopeTransport = _FakeEnvelopeTransport()..envelope = _envelope();
    final approvals = _FakeApprovalTransport();
    final coordinator = _coordinator(
      vault: vault,
      transport: envelopeTransport,
      approvals: approvals,
    );

    final session = await coordinator.startDeviceApproval();
    expect(session.verificationCode, '482 731');
    expect(session.requestToken, everyElement(6));
    expect(session.toString(), contains('requestToken: <redacted>'));
    final request = vault.pendingRequest!;
    approvals.remoteState = RemoteDeviceApprovalState(
      id: request.requestId,
      status: RemoteDeviceApprovalStatus.approved,
      deviceName: 'Daylink iPhone',
      publicKey: Uint8List.fromList(request.publicKey),
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      approverPublicKey: Uint8List.fromList(List<int>.filled(32, 7)),
      nonce: Uint8List.fromList(List<int>.filled(12, 8)),
      ciphertext: Uint8List.fromList(List<int>.filled(48, 9)),
      keyVersion: 1,
    );

    expect(
      await coordinator.checkDeviceApproval(session),
      DeviceApprovalWaitingStatus.completed,
    );
    expect(vault.localStatus, LocalContentKeyStatus.ready);
    expect(approvals.consumeCalls, 1);
    expect(session.requestToken, everyElement(0));
    coordinator.close();
  });
}

ContentEncryptionCoordinator _coordinator({
  required _FakeVault vault,
  required _FakeEnvelopeTransport transport,
  Future<bool> Function()? refresh,
  _FakeApprovalTransport? approvals,
}) => ContentEncryptionCoordinator(
  accountId: '123e4567-e89b-42d3-a456-426614174000',
  vaultPath: '/tmp/vault.db',
  vault: vault,
  deviceKeyStore: _FakeDeviceKeyStore(),
  client: transport,
  approvalClient: approvals ?? _FakeApprovalTransport(),
  accessToken: () async => 'dlka_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  refreshAccessToken: refresh ?? () async => false,
);

KeyEnvelope _envelope({int ciphertextByte = 3}) => KeyEnvelope(
  keyVersion: 1,
  algorithm: 'aes-256-gcm',
  kdf: 'hkdf-sha256',
  salt: Uint8List.fromList(List<int>.filled(32, 1)),
  nonce: Uint8List.fromList(List<int>.filled(12, 2)),
  ciphertext: Uint8List.fromList(List<int>.filled(48, ciphertextByte)),
  creatorDeviceId: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
);

class _FakeVault implements ContentKeyVault {
  LocalContentKeyStatus localStatus = LocalContentKeyStatus.missing;
  var initializeCalls = 0;
  var discardCalls = 0;
  var restoreCalls = 0;
  var restoreResult = true;
  List<int>? receivedRecoveryKey;
  var approvalCode = '482 731';
  var packageCode = '482 731';
  var approveCalls = 0;
  LocalDeviceApprovalRequestKey? pendingRequest;

  @override
  Future<void> acknowledgeRecoveryKeySaved({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async {
    localStatus = LocalContentKeyStatus.ready;
  }

  @override
  Future<void> discardPending({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async {
    discardCalls++;
    localStatus = LocalContentKeyStatus.missing;
  }

  @override
  Future<List<int>> generateDeviceVaultKey() async => List<int>.filled(32, 8);

  @override
  Future<LocalContentKeyInitialization> initialize({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async {
    initializeCalls++;
    localStatus = LocalContentKeyStatus.pendingRecoveryConfirmation;
    return LocalContentKeyInitialization(
      deviceId: '9b276a3e-b141-4d91-8dbf-0f217b62b071',
      keyVersion: 1,
      recoveryKey: List<int>.generate(32, (index) => index),
      recoverySalt: List<int>.filled(32, 1),
      recoveryNonce: List<int>.filled(12, 2),
      recoveryCiphertext: List<int>.filled(48, 3),
    );
  }

  @override
  Future<LocalContentKeyStatus> status({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async => localStatus;

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
  }) async {
    restoreCalls++;
    receivedRecoveryKey = recoveryKey;
    if (restoreResult) localStatus = LocalContentKeyStatus.ready;
    return restoreResult;
  }

  @override
  Future<LocalDeviceApprovalPackage> approveDeviceRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required List<int> requesterPublicKey,
  }) async {
    approveCalls++;
    return LocalDeviceApprovalPackage(
      approverPublicKey: List<int>.filled(32, 2),
      nonce: List<int>.filled(12, 3),
      ciphertext: List<int>.filled(48, 4),
      keyVersion: 1,
      verificationCode: packageCode,
    );
  }

  @override
  Future<String> deviceApprovalVerificationCode({
    required String accountId,
    required String requestId,
    required List<int> requesterPublicKey,
  }) async => approvalCode;

  @override
  Future<LocalDeviceApprovalRequestKey> createDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
    required int expiresAtUnixMs,
  }) async => pendingRequest ??= LocalDeviceApprovalRequestKey(
    requestId: requestId,
    publicKey: List<int>.filled(32, 5),
    requestToken: List<int>.filled(32, 6),
    verificationCode: approvalCode,
    expiresAtUnixMs: expiresAtUnixMs,
  );

  @override
  Future<LocalDeviceApprovalRequestKey?> loadDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
  }) async => pendingRequest;

  @override
  Future<void> discardDeviceApprovalRequest({
    required String vaultPath,
    required String accountId,
    required List<int> deviceVaultKey,
    required String requestId,
  }) async {
    if (pendingRequest?.requestId == requestId) pendingRequest = null;
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
  }) async {
    pendingRequest = null;
    localStatus = LocalContentKeyStatus.ready;
    return true;
  }
}

class _FakeEnvelopeTransport implements KeyEnvelopeTransport {
  KeyEnvelope? envelope;
  KeyEnvelope? winnerAfterConflict;
  var storeCalls = 0;
  var loadCalls = 0;
  var conflictOnStore = false;
  var rejectNextLoad = false;

  @override
  void close() {}

  @override
  Future<KeyEnvelope?> load({required String accessToken}) async {
    loadCalls++;
    if (rejectNextLoad) {
      rejectNextLoad = false;
      throw const KeyEnvelopeClientException('expired', sessionRejected: true);
    }
    return envelope;
  }

  @override
  Future<void> store({
    required String accessToken,
    required KeyEnvelope envelope,
  }) async {
    storeCalls++;
    if (conflictOnStore) {
      this.envelope = winnerAfterConflict;
      throw const KeyEnvelopeClientException('conflict', conflict: true);
    }
    this.envelope = envelope;
  }
}

class _FakeDeviceKeyStore implements DeviceVaultKeyStore {
  String? value = base64Encode(List<int>.filled(32, 8));

  @override
  Future<void> delete(String accountId) async => value = null;

  @override
  Future<String?> read(String accountId) async => value;

  @override
  Future<void> write(String accountId, String encodedKey) async {
    value = encodedKey;
  }
}

class _FakeApprovalTransport implements DeviceApprovalTransport {
  List<RemoteDeviceApprovalRequest> requests = const [];
  var approveCalls = 0;
  var rejectCalls = 0;
  RemoteDeviceApprovalDecision? lastDecision;
  RemoteDeviceApprovalState? remoteState;
  var consumeCalls = 0;
  var cancelCalls = 0;

  @override
  Future<void> approve({
    required String accessToken,
    required String requestId,
    required RemoteDeviceApprovalDecision decision,
  }) async {
    approveCalls++;
    lastDecision = decision;
  }

  @override
  void close() {}

  @override
  Future<List<RemoteDeviceApprovalRequest>> listPending({
    required String accessToken,
  }) async => requests;

  @override
  Future<void> reject({
    required String accessToken,
    required String requestId,
  }) async {
    rejectCalls++;
  }

  @override
  Future<DateTime> create({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
    required List<int> publicKey,
  }) async => DateTime.now().toUtc().add(const Duration(minutes: 10));

  @override
  Future<RemoteDeviceApprovalState> loadStatus({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async => remoteState!;

  @override
  Future<void> consume({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async {
    consumeCalls++;
  }

  @override
  Future<void> cancel({
    required String accessToken,
    required String requestId,
    required List<int> requestToken,
  }) async {
    cancelCalls++;
  }
}
