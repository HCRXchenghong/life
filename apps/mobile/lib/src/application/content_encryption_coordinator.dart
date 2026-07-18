import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/app_session_monitor.dart';
import '../data/device_vault_key_store.dart';
import '../data/device_approval_client.dart';
import '../data/key_envelope_client.dart';
import '../domain/sync/content_encryption_models.dart';
import '../domain/sync/data_sync_models.dart';
import '../platform/content_key_vault.dart';

class ContentEncryptionCoordinator
    implements
        ContentEncryptionSource,
        TrustedDeviceApprovalSource,
        DeviceApprovalRecoverySource {
  factory ContentEncryptionCoordinator({
    required String accountId,
    required String vaultPath,
    required ContentKeyVault vault,
    required DeviceVaultKeyStore deviceKeyStore,
    required KeyEnvelopeTransport client,
    required DeviceApprovalTransport approvalClient,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
  }) => ContentEncryptionCoordinator._(
    accountId: accountId,
    vaultPath: vaultPath,
    vault: vault,
    deviceKeyStore: deviceKeyStore,
    client: client,
    approvalClient: approvalClient,
    accessToken: accessToken,
    refreshAccessToken: refreshAccessToken,
  );

  ContentEncryptionCoordinator._({
    required String accountId,
    required String vaultPath,
    required this._vault,
    required this._deviceKeyStore,
    required this._client,
    required this._approvalClient,
    required this._accessToken,
    required this._refreshAccessToken,
  }) : _accountId = _canonicalAccountId(accountId),
       _vaultPath = _validatedVaultPath(vaultPath);

  static Future<ContentEncryptionCoordinator> start({
    required String accountId,
    required KeyEnvelopeTransport client,
    required DeviceApprovalTransport approvalClient,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    ContentKeyVault vault = const NativeContentKeyVault(),
    DeviceVaultKeyStore? deviceKeyStore,
    Directory? rootDirectory,
  }) async {
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    final normalized = _canonicalAccountId(accountId);
    return ContentEncryptionCoordinator(
      accountId: normalized,
      vaultPath: p.join(
        root.path,
        'daylink',
        'accounts',
        normalized,
        'vault.db',
      ),
      vault: vault,
      deviceKeyStore: deviceKeyStore ?? PlatformDeviceVaultKeyStore(),
      client: client,
      approvalClient: approvalClient,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
    );
  }

  final String _accountId;
  final String _vaultPath;
  final ContentKeyVault _vault;
  final DeviceVaultKeyStore _deviceKeyStore;
  final KeyEnvelopeTransport _client;
  final DeviceApprovalTransport _approvalClient;
  final AccessTokenProvider _accessToken;
  final SessionRefreshCallback _refreshAccessToken;
  Future<List<int>>? _deviceKeyFuture;
  Future<RecoveryKeyDraft>? _activePreparation;
  Future<RecoveryKeyRotationDraft>? _activeRotationPreparation;
  Future<void>? _activeRotationCommit;
  Future<void>? _activeRestoration;
  Future<void>? _activeDeviceApproval;
  Future<DeviceApprovalWaitingSession>? _activeDeviceRecoveryStart;
  Future<DeviceApprovalWaitingStatus>? _activeDeviceRecoveryCheck;
  bool _closed = false;

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async {
    _ensureOpen();
    final local = await _localStatus();
    if (local == LocalContentKeyStatus.ready ||
        local == LocalContentKeyStatus.pendingRecoveryRotation) {
      return const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.enabled,
        keyVersion: currentContentKeyVersion,
      );
    }
    if (local == LocalContentKeyStatus.pendingRecoveryConfirmation) {
      return const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.recoveryPending,
        keyVersion: currentContentKeyVersion,
      );
    }
    final envelope = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    return ContentEncryptionState(
      status: envelope == null
          ? ContentEncryptionSetupStatus.notConfigured
          : ContentEncryptionSetupStatus.locked,
      keyVersion: envelope?.keyVersion,
    );
  }

  Future<DataEncryptionStatus> loadDataEncryptionStatus() async {
    if (_closed) return DataEncryptionStatus.locked;
    try {
      final status = await loadContentEncryptionState();
      return switch (status.status) {
        ContentEncryptionSetupStatus.enabled ||
        ContentEncryptionSetupStatus.recoveryPending =>
          DataEncryptionStatus.unlocked,
        ContentEncryptionSetupStatus.locked => DataEncryptionStatus.locked,
        ContentEncryptionSetupStatus.notConfigured =>
          DataEncryptionStatus.unavailable,
      };
    } on Object {
      return DataEncryptionStatus.locked;
    }
  }

  @override
  Future<RecoveryKeyDraft> prepareContentEncryption() {
    _ensureOpen();
    final active = _activePreparation;
    if (active != null) return active;
    final operation = _prepare().whenComplete(() => _activePreparation = null);
    _activePreparation = operation;
    return operation;
  }

  Future<RecoveryKeyDraft> _prepare() async {
    final deviceKey = await _deviceKey();
    final local = await _vault.status(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    if (local == LocalContentKeyStatus.ready) {
      throw const ContentEncryptionException('端到端加密已开启');
    }

    final remote = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    if (local == LocalContentKeyStatus.missing && remote != null) {
      throw const ContentEncryptionException(
        '该账号已有加密内容，请使用恢复密钥解锁',
        locked: true,
      );
    }

    final initialization = await _vault.initialize(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    try {
      final candidate = KeyEnvelope(
        keyVersion: initialization.keyVersion,
        algorithm: 'aes-256-gcm',
        kdf: 'hkdf-sha256',
        salt: Uint8List.fromList(initialization.recoverySalt),
        nonce: Uint8List.fromList(initialization.recoveryNonce),
        ciphertext: Uint8List.fromList(initialization.recoveryCiphertext),
        creatorDeviceId: initialization.deviceId,
      );

      if (remote != null && !candidate.sameAs(remote)) {
        await _vault.discardPending(
          vaultPath: _vaultPath,
          accountId: _accountId,
          deviceVaultKey: deviceKey,
        );
        throw const ContentEncryptionException(
          '该账号已有加密内容，请使用恢复密钥解锁',
          locked: true,
        );
      }

      if (remote == null) {
        try {
          await _authenticated(
            (token) => _client.store(accessToken: token, envelope: candidate),
          );
        } on KeyEnvelopeClientException catch (error) {
          if (!error.conflict) rethrow;
          final winner = await _authenticated(
            (token) => _client.load(accessToken: token),
          );
          if (winner == null || !candidate.sameAs(winner)) {
            await _vault.discardPending(
              vaultPath: _vaultPath,
              accountId: _accountId,
              deviceVaultKey: deviceKey,
            );
            throw const ContentEncryptionException(
              '该账号已有加密内容，请使用恢复密钥解锁',
              locked: true,
            );
          }
        }
      }
      return RecoveryKeyDraft.fromBytes(initialization.recoveryKey);
    } finally {
      initialization.recoveryKey.fillRange(
        0,
        initialization.recoveryKey.length,
        0,
      );
    }
  }

  @override
  Future<void> acknowledgeRecoveryKeySaved() async {
    _ensureOpen();
    final deviceKey = await _deviceKey();
    await _vault.acknowledgeRecoveryKeySaved(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
  }

  @override
  Future<RecoveryKeyRotationDraft> prepareRecoveryKeyRotation() {
    _ensureOpen();
    final active = _activeRotationPreparation;
    if (active != null) return active;
    final operation = _prepareRecoveryKeyRotation().whenComplete(
      () => _activeRotationPreparation = null,
    );
    _activeRotationPreparation = operation;
    return operation;
  }

  Future<RecoveryKeyRotationDraft> _prepareRecoveryKeyRotation() async {
    final deviceKey = await _deviceKey();
    final local = await _vault.status(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    if (local != LocalContentKeyStatus.ready &&
        local != LocalContentKeyStatus.pendingRecoveryRotation) {
      throw const ContentEncryptionException('此设备没有可轮换的内容密钥');
    }
    final remote = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    if (remote == null) {
      throw const ContentEncryptionException('该账号没有可更新的恢复密钥信封');
    }
    late LocalRecoveryKeyRotation rotation;
    try {
      rotation = await _vault.prepareRecoveryKeyRotation(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        expectedRevision: remote.envelopeRevision,
      );
    } on Object {
      throw const ContentEncryptionException('无法在此设备安全生成恢复密钥，请重试');
    }
    try {
      final candidate = _rotationEnvelope(rotation);
      if (!remote.sameAs(candidate)) {
        if (remote.envelopeRevision != rotation.expectedRevision) {
          await _discardRotation(deviceKey, rotation.rotationId);
          throw const ContentEncryptionException('恢复密钥已在其他设备更新，请重试');
        }
        try {
          await _authenticated(
            (token) => _client.beginRecoveryKeyRotation(
              accessToken: token,
              rotationId: rotation.rotationId,
              expectedRevision: rotation.expectedRevision,
              envelope: candidate,
            ),
          );
        } on KeyEnvelopeClientException catch (error) {
          if (!error.conflict) throw ContentEncryptionException(error.message);
          final winner = await _authenticated(
            (token) => _client.load(accessToken: token),
          );
          if (winner == null || !winner.sameAs(candidate)) {
            await _discardRotation(deviceKey, rotation.rotationId);
            throw ContentEncryptionException(error.message);
          }
        }
      }
      return RecoveryKeyRotationDraft(
        rotationId: rotation.rotationId,
        recoveryKey: RecoveryKeyDraft.fromBytes(rotation.recoveryKey),
      );
    } finally {
      rotation.recoveryKey.fillRange(0, rotation.recoveryKey.length, 0);
    }
  }

  @override
  Future<void> acknowledgeRecoveryKeyRotationSaved(String rotationId) {
    _ensureOpen();
    final active = _activeRotationCommit;
    if (active != null) return active;
    final operation = _acknowledgeRecoveryKeyRotationSaved(
      rotationId,
    ).whenComplete(() => _activeRotationCommit = null);
    _activeRotationCommit = operation;
    return operation;
  }

  Future<void> _acknowledgeRecoveryKeyRotationSaved(String rotationId) async {
    final deviceKey = await _deviceKey();
    final remote = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    if (remote == null) {
      throw const ContentEncryptionException('该账号没有可更新的恢复密钥信封');
    }
    late LocalRecoveryKeyRotation rotation;
    try {
      rotation = await _vault.prepareRecoveryKeyRotation(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        expectedRevision: remote.envelopeRevision,
      );
    } on Object {
      throw const ContentEncryptionException('恢复密钥的本地安全状态已失效');
    }
    try {
      if (rotation.rotationId != rotationId) {
        throw const ContentEncryptionException('恢复密钥轮换请求不匹配');
      }
      final candidate = _rotationEnvelope(rotation);
      if (!remote.sameAs(candidate)) {
        if (remote.envelopeRevision != rotation.expectedRevision) {
          throw const ContentEncryptionException('恢复密钥已在其他设备更新');
        }
        try {
          await _authenticated(
            (token) => _client.commitRecoveryKeyRotation(
              accessToken: token,
              rotationId: rotation.rotationId,
            ),
          );
        } on KeyEnvelopeClientException catch (error) {
          final winner = await _authenticated(
            (token) => _client.load(accessToken: token),
          );
          if (winner == null || !winner.sameAs(candidate)) {
            throw ContentEncryptionException(error.message);
          }
        }
      }
      try {
        await _vault.commitRecoveryKeyRotation(
          vaultPath: _vaultPath,
          accountId: _accountId,
          deviceVaultKey: deviceKey,
          rotationId: rotation.rotationId,
        );
      } on Object {
        throw const ContentEncryptionException('新恢复密钥已启用，但本地确认尚未完成，请勿删除并重试');
      }
    } finally {
      rotation.recoveryKey.fillRange(0, rotation.recoveryKey.length, 0);
    }
  }

  KeyEnvelope _rotationEnvelope(LocalRecoveryKeyRotation rotation) =>
      KeyEnvelope(
        envelopeRevision: rotation.expectedRevision + 1,
        keyVersion: rotation.keyVersion,
        algorithm: 'aes-256-gcm',
        kdf: 'hkdf-sha256',
        salt: Uint8List.fromList(rotation.recoverySalt),
        nonce: Uint8List.fromList(rotation.recoveryNonce),
        ciphertext: Uint8List.fromList(rotation.recoveryCiphertext),
        creatorDeviceId: rotation.deviceId,
      );

  Future<void> _discardRotation(List<int> deviceKey, String rotationId) =>
      _vault.discardRecoveryKeyRotation(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        rotationId: rotationId,
      );

  @override
  Future<void> restoreWithRecoveryKey(String encodedKey) {
    _ensureOpen();
    final active = _activeRestoration;
    if (active != null) return active;
    final operation = _restore(
      encodedKey,
    ).whenComplete(() => _activeRestoration = null);
    _activeRestoration = operation;
    return operation;
  }

  Future<void> _restore(String encodedKey) async {
    late Uint8List recoveryKey;
    try {
      recoveryKey = RecoveryKeyCodec.decode(encodedKey);
    } on FormatException {
      throw const ContentEncryptionException('恢复密钥格式不正确');
    }
    try {
      final deviceKey = await _deviceKey();
      final local = await _vault.status(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
      );
      if (local == LocalContentKeyStatus.ready) {
        throw const ContentEncryptionException('此设备已恢复加密内容');
      }
      if (local == LocalContentKeyStatus.pendingRecoveryConfirmation) {
        throw const ContentEncryptionException('请先完成当前恢复密钥的保存确认');
      }
      late KeyEnvelope? envelope;
      try {
        envelope = await _authenticated(
          (token) => _client.load(accessToken: token),
        );
      } on KeyEnvelopeClientException catch (error) {
        throw ContentEncryptionException(error.message);
      }
      if (envelope == null) {
        throw const ContentEncryptionException('该账号没有可恢复的加密内容');
      }
      late bool restored;
      try {
        restored = await _vault.restore(
          vaultPath: _vaultPath,
          accountId: _accountId,
          deviceVaultKey: deviceKey,
          recoveryKey: recoveryKey,
          keyVersion: envelope.keyVersion,
          recoverySalt: envelope.salt,
          recoveryNonce: envelope.nonce,
          recoveryCiphertext: envelope.ciphertext,
        );
      } on Object {
        throw const ContentEncryptionException('无法在此设备保存内容密钥，请重试');
      }
      if (!restored) {
        throw const ContentEncryptionException('恢复密钥不正确，请重新检查');
      }
    } finally {
      recoveryKey.fillRange(0, recoveryKey.length, 0);
    }
  }

  @override
  Future<DeviceApprovalWaitingSession> startDeviceApproval() {
    _ensureOpen();
    final active = _activeDeviceRecoveryStart;
    if (active != null) return active;
    final operation = _startDeviceApproval().whenComplete(
      () => _activeDeviceRecoveryStart = null,
    );
    _activeDeviceRecoveryStart = operation;
    return operation;
  }

  Future<DeviceApprovalWaitingSession> _startDeviceApproval() async {
    final deviceKey = await _deviceKey();
    final local = await _vault.status(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    if (local == LocalContentKeyStatus.ready) {
      throw const ContentEncryptionException('此设备已恢复加密内容');
    }
    if (local == LocalContentKeyStatus.pendingRecoveryConfirmation) {
      throw const ContentEncryptionException('请先完成当前恢复密钥的保存确认');
    }
    final envelope = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    if (envelope == null) {
      throw const ContentEncryptionException('该账号没有可恢复的加密内容');
    }
    final now = DateTime.now().toUtc();
    LocalDeviceApprovalRequestKey? request;
    try {
      request = await _vault.loadDeviceApprovalRequest(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
      );
      request ??= await _vault.createDeviceApprovalRequest(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        requestId: const Uuid().v4(),
        expiresAtUnixMs: now
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      );
    } on Object {
      throw const ContentEncryptionException('无法安全创建新设备请求，请重试');
    }
    final activeRequest = request;
    if (activeRequest.requestToken.length != 32 ||
        activeRequest.publicKey.length != 32 ||
        !RegExp(r'^\d{3} \d{3}$').hasMatch(activeRequest.verificationCode)) {
      throw const ContentEncryptionException('新设备请求的本地安全状态无效');
    }
    late DateTime expiresAt;
    try {
      expiresAt = await _authenticatedApproval(
        (token) => _approvalClient.create(
          accessToken: token,
          requestId: activeRequest.requestId,
          requestToken: activeRequest.requestToken,
          publicKey: activeRequest.publicKey,
        ),
      );
    } on DeviceApprovalClientException catch (error) {
      throw ContentEncryptionException(error.message);
    }
    final localExpiresAt = DateTime.fromMillisecondsSinceEpoch(
      activeRequest.expiresAtUnixMs,
      isUtc: true,
    );
    final effectiveExpiresAt = expiresAt.isBefore(localExpiresAt)
        ? expiresAt
        : localExpiresAt;
    return DeviceApprovalWaitingSession(
      id: activeRequest.requestId,
      requestToken: activeRequest.requestToken,
      verificationCode: activeRequest.verificationCode,
      deviceName: _currentDeviceName(),
      createdAt: effectiveExpiresAt.subtract(const Duration(minutes: 10)),
      expiresAt: effectiveExpiresAt,
    );
  }

  @override
  Future<DeviceApprovalWaitingStatus> checkDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) {
    _ensureOpen();
    final active = _activeDeviceRecoveryCheck;
    if (active != null) return active;
    final operation = _checkDeviceApproval(
      session,
    ).whenComplete(() => _activeDeviceRecoveryCheck = null);
    _activeDeviceRecoveryCheck = operation;
    return operation;
  }

  Future<DeviceApprovalWaitingStatus> _checkDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) async {
    if (session.expired) {
      await _discardLocalDeviceRequest(session.id);
      session.requestToken.fillRange(0, session.requestToken.length, 0);
      return DeviceApprovalWaitingStatus.expired;
    }
    final deviceKey = await _deviceKey();
    final local = await _vault.status(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    if (local == LocalContentKeyStatus.ready) {
      await _consumeDeviceApproval(session);
      session.requestToken.fillRange(0, session.requestToken.length, 0);
      return DeviceApprovalWaitingStatus.completed;
    }
    final localRequest = await _vault.loadDeviceApprovalRequest(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
    if (localRequest == null || localRequest.requestId != session.id) {
      throw const ContentEncryptionException('新设备请求的本地安全状态已失效');
    }
    late RemoteDeviceApprovalState remote;
    try {
      remote = await _authenticatedApproval(
        (token) => _approvalClient.loadStatus(
          accessToken: token,
          requestId: session.id,
          requestToken: session.requestToken,
        ),
      );
    } on DeviceApprovalClientException catch (error) {
      if (error.unavailable && session.expired) {
        return DeviceApprovalWaitingStatus.expired;
      }
      throw ContentEncryptionException(error.message);
    }
    if (remote.status == RemoteDeviceApprovalStatus.pending) {
      if (!_constantTimeBytesEqual(remote.publicKey, localRequest.publicKey)) {
        throw const ContentEncryptionException('新设备请求的公钥绑定验证失败');
      }
      return DeviceApprovalWaitingStatus.pending;
    }
    if (!_constantTimeBytesEqual(remote.publicKey, localRequest.publicKey)) {
      throw const ContentEncryptionException('新设备请求的公钥绑定验证失败');
    }
    if (remote.status == RemoteDeviceApprovalStatus.rejected ||
        remote.status == RemoteDeviceApprovalStatus.expired) {
      await _discardLocalDeviceRequest(session.id);
      session.requestToken.fillRange(0, session.requestToken.length, 0);
      return remote.status == RemoteDeviceApprovalStatus.rejected
          ? DeviceApprovalWaitingStatus.rejected
          : DeviceApprovalWaitingStatus.expired;
    }
    final envelope = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    if (envelope == null ||
        remote.approverPublicKey == null ||
        remote.nonce == null ||
        remote.ciphertext == null ||
        remote.keyVersion == null ||
        remote.keyVersion != envelope.keyVersion) {
      throw const ContentEncryptionException('受信设备返回的加密内容无效');
    }
    late bool completed;
    try {
      completed = await _vault.completeDeviceApproval(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        requestId: session.id,
        approverPublicKey: remote.approverPublicKey!,
        nonce: remote.nonce!,
        ciphertext: remote.ciphertext!,
        keyVersion: remote.keyVersion!,
        recoverySalt: envelope.salt,
        recoveryNonce: envelope.nonce,
        recoveryCiphertext: envelope.ciphertext,
      );
    } on Object {
      throw const ContentEncryptionException('受信设备的加密响应验证失败');
    }
    if (!completed) {
      throw const ContentEncryptionException('两台设备的安全响应不一致，已停止恢复');
    }
    await _consumeDeviceApproval(session);
    session.requestToken.fillRange(0, session.requestToken.length, 0);
    return DeviceApprovalWaitingStatus.completed;
  }

  Future<void> _consumeDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) async {
    try {
      await _authenticatedApproval(
        (token) => _approvalClient.consume(
          accessToken: token,
          requestId: session.id,
          requestToken: session.requestToken,
        ),
      );
    } on DeviceApprovalClientException catch (error) {
      throw ContentEncryptionException(error.message);
    }
  }

  @override
  Future<void> cancelDeviceApproval(
    DeviceApprovalWaitingSession session,
  ) async {
    _ensureOpen();
    try {
      await _authenticatedApproval(
        (token) => _approvalClient.cancel(
          accessToken: token,
          requestId: session.id,
          requestToken: session.requestToken,
        ),
      );
    } on DeviceApprovalClientException catch (error) {
      if (!error.unavailable) throw ContentEncryptionException(error.message);
    } finally {
      await _discardLocalDeviceRequest(session.id);
      session.requestToken.fillRange(0, session.requestToken.length, 0);
    }
  }

  Future<void> _discardLocalDeviceRequest(String requestId) async {
    final deviceKey = await _deviceKey();
    await _vault.discardDeviceApprovalRequest(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
      requestId: requestId,
    );
  }

  @override
  Future<TrustedDeviceApprovalRequest?> loadPendingDeviceApproval() async {
    _ensureOpen();
    if (await _localStatus() != LocalContentKeyStatus.ready) return null;
    late List<RemoteDeviceApprovalRequest> requests;
    try {
      requests = await _authenticatedApproval(
        (token) => _approvalClient.listPending(accessToken: token),
      );
    } on DeviceApprovalClientException catch (error) {
      throw ContentEncryptionException(error.message);
    }
    final now = DateTime.now().toUtc();
    for (final request in requests) {
      if (!request.expiresAt.isAfter(now)) continue;
      late String code;
      try {
        code = await _vault.deviceApprovalVerificationCode(
          accountId: _accountId,
          requestId: request.id,
          requesterPublicKey: request.publicKey,
        );
      } on Object {
        continue;
      }
      if (!RegExp(r'^\d{3} \d{3}$').hasMatch(code)) continue;
      return TrustedDeviceApprovalRequest(
        id: request.id,
        deviceName: request.deviceName,
        requesterPublicKey: Uint8List.fromList(request.publicKey),
        verificationCode: code,
        createdAt: request.createdAt,
        expiresAt: request.expiresAt,
      );
    }
    return null;
  }

  @override
  Future<void> approveDevice(TrustedDeviceApprovalRequest request) {
    _ensureOpen();
    final active = _activeDeviceApproval;
    if (active != null) return active;
    final operation = _approveDevice(
      request,
    ).whenComplete(() => _activeDeviceApproval = null);
    _activeDeviceApproval = operation;
    return operation;
  }

  Future<void> _approveDevice(TrustedDeviceApprovalRequest request) async {
    if (request.expired) {
      throw const ContentEncryptionException('设备批准请求已失效');
    }
    if (await _localStatus() != LocalContentKeyStatus.ready) {
      throw const ContentEncryptionException('此设备没有可用于批准的内容密钥');
    }
    final deviceKey = await _deviceKey();
    late LocalDeviceApprovalPackage package;
    try {
      package = await _vault.approveDeviceRequest(
        vaultPath: _vaultPath,
        accountId: _accountId,
        deviceVaultKey: deviceKey,
        requestId: request.id,
        requesterPublicKey: request.requesterPublicKey,
      );
    } on Object {
      throw const ContentEncryptionException('无法在此设备安全批准，请重试');
    }
    if (!_constantTimeTextEqual(
      package.verificationCode,
      request.verificationCode,
    )) {
      throw const ContentEncryptionException('两台设备验证码不一致，已停止批准');
    }
    try {
      await _authenticatedApproval(
        (token) => _approvalClient.approve(
          accessToken: token,
          requestId: request.id,
          decision: RemoteDeviceApprovalDecision(
            approverPublicKey: package.approverPublicKey,
            nonce: package.nonce,
            ciphertext: package.ciphertext,
            keyVersion: package.keyVersion,
          ),
        ),
      );
    } on DeviceApprovalClientException catch (error) {
      throw ContentEncryptionException(error.message);
    }
  }

  @override
  Future<void> rejectDevice(TrustedDeviceApprovalRequest request) async {
    _ensureOpen();
    if (request.expired) {
      throw const ContentEncryptionException('设备批准请求已失效');
    }
    try {
      await _authenticatedApproval(
        (token) =>
            _approvalClient.reject(accessToken: token, requestId: request.id),
      );
    } on DeviceApprovalClientException catch (error) {
      throw ContentEncryptionException(error.message);
    }
  }

  Future<LocalContentKeyStatus> _localStatus() async {
    final deviceKey = await _deviceKey();
    return _vault.status(
      vaultPath: _vaultPath,
      accountId: _accountId,
      deviceVaultKey: deviceKey,
    );
  }

  Future<List<int>> _deviceKey() {
    final active = _deviceKeyFuture;
    if (active != null) return active;
    final operation = _loadOrCreateDeviceKey();
    _deviceKeyFuture = operation;
    return operation;
  }

  Future<List<int>> _loadOrCreateDeviceKey() async {
    final stored = await _deviceKeyStore.read(_accountId);
    if (stored != null) {
      try {
        final decoded = base64Decode(stored);
        if (decoded.length != 32) throw const FormatException();
        return decoded;
      } on FormatException {
        throw const ContentEncryptionException('设备密钥存储已损坏');
      }
    }
    final generated = await _vault.generateDeviceVaultKey();
    if (generated.length != 32) {
      throw const ContentEncryptionException('无法生成设备密钥');
    }
    await _deviceKeyStore.write(_accountId, base64Encode(generated));
    return generated;
  }

  Future<T> _authenticated<T>(
    Future<T> Function(String token) operation,
  ) async {
    var refreshed = false;
    while (true) {
      final token = await _accessToken();
      if (token == null) {
        throw const KeyEnvelopeClientException(
          '登录已失效，请重新登录',
          sessionRejected: true,
        );
      }
      try {
        return await operation(token);
      } on KeyEnvelopeClientException catch (error) {
        if (!error.sessionRejected || refreshed) rethrow;
        refreshed = true;
        if (!await _refreshAccessToken()) rethrow;
      }
    }
  }

  Future<T> _authenticatedApproval<T>(
    Future<T> Function(String token) operation,
  ) async {
    var refreshed = false;
    while (true) {
      final token = await _accessToken();
      if (token == null) {
        throw const DeviceApprovalClientException(
          '登录已失效，请重新登录',
          sessionRejected: true,
        );
      }
      try {
        return await operation(token);
      } on DeviceApprovalClientException catch (error) {
        if (!error.sessionRejected || refreshed) rethrow;
        refreshed = true;
        if (!await _refreshAccessToken()) rethrow;
      }
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
    _approvalClient.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Content encryption is closed');
  }
}

bool _constantTimeTextEqual(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  var difference = leftBytes.length ^ rightBytes.length;
  final length = leftBytes.length > rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < length; index++) {
    final leftValue = index < leftBytes.length ? leftBytes[index] : 0;
    final rightValue = index < rightBytes.length ? rightBytes[index] : 0;
    difference |= leftValue ^ rightValue;
  }
  return difference == 0;
}

String _canonicalAccountId(String value) {
  final normalized = value.toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError('Invalid account ID');
  }
  return normalized;
}

bool _constantTimeBytesEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    difference |=
        (index < left.length ? left[index] : 0) ^
        (index < right.length ? right[index] : 0);
  }
  return difference == 0;
}

String _currentDeviceName() {
  if (Platform.isIOS) return 'Daylink iPhone';
  if (Platform.isAndroid) return 'Daylink Android';
  return 'Daylink 设备';
}

String _validatedVaultPath(String value) {
  if (!p.isAbsolute(value) || p.basename(value) != 'vault.db') {
    throw ArgumentError('Invalid vault path');
  }
  return value;
}
