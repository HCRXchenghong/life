import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/operations/operations_models.dart';
import 'app_database.dart';

class OperationsRepository {
  OperationsRepository(this._db);

  final AppDatabase _db;

  Future<void> saveGroup(HostGroupModel group) async {
    _requireText(group.name, 'group name');
    await _db
        .into(_db.hostGroups)
        .insertOnConflictUpdate(
          HostGroupsCompanion.insert(
            id: group.id,
            name: group.name.trim(),
            sortOrder: Value(group.sortOrder),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> saveHost(HostProfileModel host) async {
    _requireText(host.name, 'host name');
    _requireText(host.address, 'host address');
    _requireText(host.username, 'username');
    _requirePort(host.port, 'SSH port');
    await _db
        .into(_db.hosts)
        .insertOnConflictUpdate(
          HostsCompanion.insert(
            id: host.id,
            name: host.name.trim(),
            address: host.address.trim(),
            port: Value(host.port),
            username: host.username.trim(),
            groupId: Value(host.groupId),
            credentialRef: Value(host.credentialRef),
            notes: Value(host.notes),
            favorite: Value(host.favorite),
            terminalMode: Value(host.terminalMode.name),
            agentState: Value(host.agentState),
            updatedAt: Value(DateTime.now().toUtc()),
            deletedAt: const Value(null),
          ),
        );
  }

  Future<void> softDeleteHost(String hostId) async {
    await (_db.update(_db.hosts)..where((row) => row.id.equals(hostId))).write(
      HostsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> saveTag(OperationTagModel tag) async {
    _requireText(tag.name, 'tag name');
    await _db
        .into(_db.operationTags)
        .insertOnConflictUpdate(
          OperationTagsCompanion.insert(
            id: tag.id,
            name: tag.name.trim(),
            colorArgb: Value(tag.colorArgb),
          ),
        );
  }

  Future<void> setHostTags(String hostId, Iterable<String> tagIds) async {
    final uniqueIds = tagIds.toSet();
    await _db.transaction(() async {
      await (_db.delete(
        _db.hostOperationTags,
      )..where((row) => row.hostId.equals(hostId))).go();
      if (uniqueIds.isEmpty) return;
      await _db.batch((batch) {
        batch.insertAll(
          _db.hostOperationTags,
          uniqueIds
              .map(
                (tagId) => HostOperationTagsCompanion.insert(
                  hostId: hostId,
                  tagId: tagId,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<List<HostSearchResult>> searchHosts({
    String query = '',
    String? groupId,
    String? tagId,
    bool favoritesOnly = false,
  }) async {
    final normalized = query.trim().toLowerCase();
    final hostRows =
        await (_db.select(_db.hosts)
              ..where((row) {
                var expression = row.deletedAt.isNull();
                if (groupId != null) expression &= row.groupId.equals(groupId);
                if (favoritesOnly) expression &= row.favorite.equals(true);
                if (normalized.isNotEmpty) {
                  final pattern = '%${_escapeLike(normalized)}%';
                  expression &=
                      row.name.lower().like(pattern, escapeChar: r'\') |
                      row.address.lower().like(pattern, escapeChar: r'\') |
                      row.username.lower().like(pattern, escapeChar: r'\');
                }
                return expression;
              })
              ..orderBy([
                (row) => OrderingTerm.desc(row.favorite),
                (row) => OrderingTerm.asc(row.name),
              ]))
            .get();

    final results = <HostSearchResult>[];
    for (final row in hostRows) {
      final tags = await _tagsForHost(row.id);
      if (tagId != null && !tags.any((tag) => tag.id == tagId)) continue;
      results.add(HostSearchResult(host: _hostFromRow(row), tags: tags));
    }
    return results;
  }

  Future<HostKeyCheck> checkHostKey({
    required String hostId,
    required String algorithm,
    required String fingerprintSha256,
  }) async {
    final existing = await (_db.select(
      _db.knownHostKeys,
    )..where((row) => row.hostId.equals(hostId))).getSingleOrNull();
    if (existing == null) {
      return HostKeyCheck(
        observation: HostKeyObservation.firstSeen,
        algorithm: algorithm,
        receivedFingerprintSha256: fingerprintSha256,
      );
    }
    if (existing.algorithm == algorithm &&
        existing.fingerprintSha256 == fingerprintSha256 &&
        existing.status == 'accepted') {
      await (_db.update(
        _db.knownHostKeys,
      )..where((row) => row.hostId.equals(hostId))).write(
        KnownHostKeysCompanion(lastSeenAt: Value(DateTime.now().toUtc())),
      );
      return HostKeyCheck(
        observation: HostKeyObservation.trusted,
        algorithm: algorithm,
        receivedFingerprintSha256: fingerprintSha256,
        acceptedFingerprintSha256: existing.fingerprintSha256,
      );
    }
    return HostKeyCheck(
      observation: HostKeyObservation.changed,
      algorithm: algorithm,
      receivedFingerprintSha256: fingerprintSha256,
      acceptedFingerprintSha256: existing.fingerprintSha256,
    );
  }

  Future<void> acceptHostKey({
    required String hostId,
    required String algorithm,
    required String fingerprintSha256,
    String? expectedPreviousFingerprintSha256,
  }) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.knownHostKeys,
      )..where((row) => row.hostId.equals(hostId))).getSingleOrNull();
      if (existing?.fingerprintSha256 != expectedPreviousFingerprintSha256) {
        throw StateError('known-host value changed while approval was pending');
      }
      final now = DateTime.now().toUtc();
      await _db
          .into(_db.knownHostKeys)
          .insertOnConflictUpdate(
            KnownHostKeysCompanion.insert(
              hostId: hostId,
              algorithm: algorithm,
              fingerprintSha256: fingerprintSha256,
              status: const Value('accepted'),
              acceptedAt: now,
              lastSeenAt: now,
            ),
          );
    });
  }

  Future<void> saveAgentState(AgentStateModel state) => _db
      .into(_db.agentStates)
      .insertOnConflictUpdate(
        AgentStatesCompanion.insert(
          hostId: state.hostId,
          protocolVersion: state.protocolVersion,
          agentVersion: state.agentVersion,
          architecture: state.architecture,
          capabilitiesJson: state.capabilitiesJson,
          transport: state.transport,
          health: state.health,
          lastSeenAt: state.lastSeenAt.toUtc(),
        ),
      );

  Future<void> savePortForward(PortForwardProfileModel profile) async {
    _requireText(profile.name, 'forward name');
    _requireText(profile.targetHost, 'target host');
    _requirePort(profile.localPort, 'local port');
    _requirePort(profile.targetPort, 'target port');
    if (profile.bindAddress != '127.0.0.1' &&
        profile.bindAddress != '::1' &&
        profile.bindAddress != 'localhost') {
      throw ArgumentError.value(
        profile.bindAddress,
        'bindAddress',
        'LAN exposure requires a separate explicit approval flow',
      );
    }
    await _db
        .into(_db.portForwardProfiles)
        .insertOnConflictUpdate(
          PortForwardProfilesCompanion.insert(
            id: profile.id,
            hostId: profile.hostId,
            name: profile.name.trim(),
            bindAddress: Value(profile.bindAddress),
            localPort: profile.localPort,
            targetHost: profile.targetHost.trim(),
            targetPort: profile.targetPort,
            autoStart: Value(profile.autoStart),
            state: Value(profile.state.name),
            lastError: Value(profile.lastError),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> markForwardState(
    String id,
    ForwardState state, {
    String? lastError,
  }) => (_db.update(_db.portForwardProfiles)..where((row) => row.id.equals(id)))
      .write(
        PortForwardProfilesCompanion(
          state: Value(state.name),
          lastError: Value(lastError),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> saveSnippet(CommandSnippetModel snippet) async {
    _requireText(snippet.name, 'snippet name');
    _requireText(snippet.command, 'command');
    if (snippet.timeoutSeconds < 1 || snippet.timeoutSeconds > 86400) {
      throw ArgumentError.value(snippet.timeoutSeconds, 'timeoutSeconds');
    }
    await _db
        .into(_db.commandSnippets)
        .insertOnConflictUpdate(
          CommandSnippetsCompanion.insert(
            id: snippet.id,
            name: snippet.name.trim(),
            command: snippet.command,
            tagsJson: Value(jsonEncode(snippet.tags.toSet().toList()..sort())),
            timeoutSeconds: Value(snippet.timeoutSeconds),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> createCommandBatch({
    required String id,
    required String commandSnapshot,
    required Iterable<String> hostIds,
    String? snippetId,
  }) async {
    _requireText(commandSnapshot, 'command');
    final uniqueHosts = hostIds.toSet();
    if (uniqueHosts.isEmpty) {
      throw ArgumentError('at least one host is required');
    }
    await _db.transaction(() async {
      await _db
          .into(_db.commandBatches)
          .insert(
            CommandBatchesCompanion.insert(
              id: id,
              snippetId: Value(snippetId),
              commandSnapshot: commandSnapshot,
              status: CommandBatchStatus.queued.name,
              startedAt: DateTime.now().toUtc(),
            ),
          );
      await _db.batch((batch) {
        batch.insertAll(
          _db.commandResults,
          uniqueHosts
              .map(
                (hostId) => CommandResultsCompanion.insert(
                  id: '$id:$hostId',
                  batchId: id,
                  hostId: hostId,
                  status: CommandResultStatus.queued.name,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<void> saveTransfer(TransferJobModel job) async {
    if (job.totalBytes < 0 ||
        job.confirmedOffset < 0 ||
        job.confirmedOffset > job.totalBytes) {
      throw ArgumentError('invalid transfer size or confirmed offset');
    }
    await _db
        .into(_db.transferJobs)
        .insertOnConflictUpdate(
          TransferJobsCompanion.insert(
            id: job.id,
            hostId: job.hostId,
            direction: job.direction.name,
            localPath: job.localPath,
            remotePath: job.remotePath,
            totalBytes: job.totalBytes,
            confirmedOffset: Value(job.confirmedOffset),
            expectedSha256: Value(job.expectedSha256),
            remoteIdentityJson: Value(job.remoteIdentityJson),
            state: Value(job.state.name),
            lastError: Value(job.lastError),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> confirmTransferOffset({
    required String id,
    required int confirmedOffset,
    String? remoteIdentityJson,
  }) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.transferJobs,
      )..where((row) => row.id.equals(id))).getSingle();
      if (confirmedOffset < current.confirmedOffset ||
          confirmedOffset > current.totalBytes) {
        throw StateError('transfer confirmation is non-monotonic or too large');
      }
      if (current.remoteIdentityJson != null &&
          remoteIdentityJson != null &&
          current.remoteIdentityJson != remoteIdentityJson) {
        throw StateError('remote file identity changed; resume is unsafe');
      }
      await (_db.update(
        _db.transferJobs,
      )..where((row) => row.id.equals(id))).write(
        TransferJobsCompanion(
          confirmedOffset: Value(confirmedOffset),
          remoteIdentityJson: Value(
            remoteIdentityJson ?? current.remoteIdentityJson,
          ),
          state: Value(
            confirmedOffset == current.totalBytes
                ? TransferState.completed.name
                : TransferState.running.name,
          ),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  Future<List<OperationTagModel>> _tagsForHost(String hostId) async {
    final query = _db.select(_db.operationTags).join([
      innerJoin(
        _db.hostOperationTags,
        _db.hostOperationTags.tagId.equalsExp(_db.operationTags.id),
      ),
    ])..where(_db.hostOperationTags.hostId.equals(hostId));
    final rows = await query.get();
    return rows
        .map((row) => row.readTable(_db.operationTags))
        .map(
          (row) => OperationTagModel(
            id: row.id,
            name: row.name,
            colorArgb: row.colorArgb,
          ),
        )
        .toList(growable: false);
  }

  HostProfileModel _hostFromRow(Host row) => HostProfileModel(
    id: row.id,
    name: row.name,
    address: row.address,
    port: row.port,
    username: row.username,
    groupId: row.groupId,
    credentialRef: row.credentialRef,
    notes: row.notes,
    favorite: row.favorite,
    terminalMode: TerminalMode.values.byName(row.terminalMode),
    agentState: row.agentState,
  );

  void _requirePort(int port, String name) {
    if (port < 1 || port > 65535) throw ArgumentError.value(port, name);
  }

  void _requireText(String value, String name) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  }

  String _escapeLike(String input) => input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
