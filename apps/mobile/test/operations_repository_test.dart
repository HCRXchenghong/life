import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/operations_repository.dart';
import 'package:daylink_mobile/src/domain/operations/operations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OperationsRepository repository;

  setUp(() {
    database = AppDatabase.inMemory();
    repository = OperationsRepository(database);
  });

  tearDown(() => database.close());

  Future<void> seedHost() async {
    await repository.saveGroup(
      const HostGroupModel(id: 'group-1', name: 'Production'),
    );
    await repository.saveHost(
      const HostProfileModel(
        id: 'host-1',
        name: 'API node',
        address: '10.0.0.7',
        port: 22,
        username: 'deploy',
        groupId: 'group-1',
        favorite: true,
        terminalMode: TerminalMode.persistent,
      ),
    );
  }

  test('searches hosts by text, group, favorite, and tag', () async {
    await seedHost();
    await repository.saveTag(
      const OperationTagModel(id: 'tag-1', name: 'critical'),
    );
    await repository.setHostTags('host-1', ['tag-1', 'tag-1']);

    final results = await repository.searchHosts(
      query: 'api',
      groupId: 'group-1',
      tagId: 'tag-1',
      favoritesOnly: true,
    );

    expect(results, hasLength(1));
    expect(results.single.host.terminalMode, TerminalMode.persistent);
    expect(results.single.tags.single.name, 'critical');

    await repository.softDeleteHost('host-1');
    expect(await repository.searchHosts(), isEmpty);
  });

  test('known-host changes are blocked until explicitly approved', () async {
    await seedHost();
    final first = await repository.checkHostKey(
      hostId: 'host-1',
      algorithm: 'ssh-ed25519',
      fingerprintSha256: 'SHA256:first',
    );
    expect(first.observation, HostKeyObservation.firstSeen);

    await repository.acceptHostKey(
      hostId: 'host-1',
      algorithm: 'ssh-ed25519',
      fingerprintSha256: 'SHA256:first',
    );
    final trusted = await repository.checkHostKey(
      hostId: 'host-1',
      algorithm: 'ssh-ed25519',
      fingerprintSha256: 'SHA256:first',
    );
    expect(trusted.observation, HostKeyObservation.trusted);

    final changed = await repository.checkHostKey(
      hostId: 'host-1',
      algorithm: 'ssh-ed25519',
      fingerprintSha256: 'SHA256:second',
    );
    expect(changed.observation, HostKeyObservation.changed);
    expect(
      () => repository.acceptHostKey(
        hostId: 'host-1',
        algorithm: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:second',
      ),
      throwsStateError,
    );
    await repository.acceptHostKey(
      hostId: 'host-1',
      algorithm: 'ssh-ed25519',
      fingerprintSha256: 'SHA256:second',
      expectedPreviousFingerprintSha256: 'SHA256:first',
    );
  });

  test('transfer resume offset is monotonic and identity-bound', () async {
    await seedHost();
    await repository.saveTransfer(
      const TransferJobModel(
        id: 'transfer-1',
        hostId: 'host-1',
        direction: TransferDirection.download,
        localPath: '/local/archive.tar',
        remotePath: '/srv/archive.tar',
        totalBytes: 100,
        remoteIdentityJson: '{"size":100,"mtime":1}',
      ),
    );

    await repository.confirmTransferOffset(
      id: 'transfer-1',
      confirmedOffset: 64,
      remoteIdentityJson: '{"size":100,"mtime":1}',
    );
    expect(
      () => repository.confirmTransferOffset(
        id: 'transfer-1',
        confirmedOffset: 32,
      ),
      throwsStateError,
    );
    expect(
      () => repository.confirmTransferOffset(
        id: 'transfer-1',
        confirmedOffset: 80,
        remoteIdentityJson: '{"size":100,"mtime":2}',
      ),
      throwsStateError,
    );
  });

  test('port forwards default to loopback and reject LAN exposure', () async {
    await seedHost();
    await repository.savePortForward(
      const PortForwardProfileModel(
        id: 'forward-1',
        hostId: 'host-1',
        name: 'Database',
        bindAddress: '127.0.0.1',
        localPort: 15432,
        targetHost: '127.0.0.1',
        targetPort: 5432,
      ),
    );
    expect(
      () => repository.savePortForward(
        const PortForwardProfileModel(
          id: 'forward-2',
          hostId: 'host-1',
          name: 'Unsafe database',
          bindAddress: '0.0.0.0',
          localPort: 15433,
          targetHost: '127.0.0.1',
          targetPort: 5432,
        ),
      ),
      throwsArgumentError,
    );
  });
}
