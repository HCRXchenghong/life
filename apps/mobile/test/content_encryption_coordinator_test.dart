import 'dart:convert';
import 'dart:typed_data';

import 'package:daylink_mobile/src/application/content_encryption_coordinator.dart';
import 'package:daylink_mobile/src/data/device_vault_key_store.dart';
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
}

ContentEncryptionCoordinator _coordinator({
  required _FakeVault vault,
  required _FakeEnvelopeTransport transport,
  Future<bool> Function()? refresh,
}) => ContentEncryptionCoordinator(
  accountId: '123e4567-e89b-42d3-a456-426614174000',
  vaultPath: '/tmp/vault.db',
  vault: vault,
  deviceKeyStore: _FakeDeviceKeyStore(),
  client: transport,
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
