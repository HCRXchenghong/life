import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_session_monitor.dart';
import '../data/device_vault_key_store.dart';
import '../data/device_approval_client.dart';
import '../data/key_envelope_client.dart';
import '../domain/sync/content_encryption_models.dart';
import '../domain/sync/data_sync_models.dart';
import '../platform/content_key_vault.dart';

class ContentEncryptionCoordinator
    implements ContentEncryptionSource, TrustedDeviceApprovalSource {
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
  Future<void>? _activeRestoration;
  Future<void>? _activeDeviceApproval;
  bool _closed = false;

  @override
  Future<ContentEncryptionState> loadContentEncryptionState() async {
    _ensureOpen();
    final local = await _localStatus();
    if (local == LocalContentKeyStatus.ready) {
      return const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.enabled,
      );
    }
    if (local == LocalContentKeyStatus.pendingRecoveryConfirmation) {
      return const ContentEncryptionState(
        status: ContentEncryptionSetupStatus.recoveryPending,
      );
    }
    final envelope = await _authenticated(
      (token) => _client.load(accessToken: token),
    );
    return ContentEncryptionState(
      status: envelope == null
          ? ContentEncryptionSetupStatus.notConfigured
          : ContentEncryptionSetupStatus.locked,
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

String _validatedVaultPath(String value) {
  if (!p.isAbsolute(value) || p.basename(value) != 'vault.db') {
    throw ArgumentError('Invalid vault path');
  }
  return value;
}
