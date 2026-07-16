import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Hosts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get address => text().withLength(min: 1, max: 255)();
  IntColumn get port => integer().withDefault(const Constant(22))();
  TextColumn get username => text().withLength(min: 1, max: 128)();
  TextColumn get groupId => text().nullable()();
  TextColumn get credentialRef => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get terminalMode => text().withDefault(const Constant('direct'))();
  TextColumn get agentState => text().withDefault(const Constant('unknown'))();
  TextColumn get system =>
      text().withLength(max: 80).withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HostGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class KnownHostKeys extends Table {
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get algorithm => text()();
  TextColumn get fingerprintSha256 => text()();
  TextColumn get status => text().withDefault(const Constant('accepted'))();
  DateTimeColumn get acceptedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {hostId};
}

class OperationTags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 64).unique()();
  IntColumn get colorArgb => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HostOperationTags extends Table {
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(OperationTags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {hostId, tagId};
}

class AgentStates extends Table {
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  IntColumn get protocolVersion => integer()();
  TextColumn get agentVersion => text()();
  TextColumn get architecture => text()();
  TextColumn get capabilitiesJson => text()();
  TextColumn get transport => text()();
  TextColumn get health => text()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {hostId};
}

class PortForwardProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get bindAddress =>
      text().withDefault(const Constant('127.0.0.1'))();
  IntColumn get localPort => integer()();
  TextColumn get targetHost => text()();
  IntColumn get targetPort => integer()();
  BoolColumn get autoStart => boolean().withDefault(const Constant(false))();
  TextColumn get state => text().withDefault(const Constant('stopped'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CommandSnippets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get command => text().withLength(min: 1, max: 32768)();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get timeoutSeconds => integer().withDefault(const Constant(60))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CommandBatches extends Table {
  TextColumn get id => text()();
  TextColumn get snippetId => text().nullable().references(
    CommandSnippets,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get commandSnapshot => text()();
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CommandResults extends Table {
  TextColumn get id => text()();
  TextColumn get batchId =>
      text().references(CommandBatches, #id, onDelete: KeyAction.cascade)();
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text()();
  IntColumn get exitCode => integer().nullable()();
  TextColumn get stdoutPreview => text().withDefault(const Constant(''))();
  TextColumn get stderrPreview => text().withDefault(const Constant(''))();
  TextColumn get artifactRef => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TransferJobs extends Table {
  TextColumn get id => text()();
  TextColumn get hostId =>
      text().references(Hosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get direction => text()();
  TextColumn get localPath => text()();
  TextColumn get remotePath => text()();
  IntColumn get totalBytes => integer()();
  IntColumn get confirmedOffset => integer().withDefault(const Constant(0))();
  TextColumn get expectedSha256 => text().nullable()();
  TextColumn get remoteIdentityJson => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('queued'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScheduleEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get startsAtUtc => dateTime()();
  IntColumn get durationMinutes => integer()();
  TextColumn get timezoneId => text()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScheduleReminders extends Table {
  TextColumn get id => text()();
  TextColumn get eventId =>
      text().references(ScheduleEvents, #id, onDelete: KeyAction.cascade)();
  IntColumn get offsetMinutes => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get exactRequested =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NotificationMappings extends Table {
  IntColumn get notificationId => integer()();
  TextColumn get reminderId =>
      text().references(ScheduleReminders, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventId =>
      text().references(ScheduleEvents, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get occurrenceStartsAtUtc => dateTime()();
  DateTimeColumn get scheduledForUtc => dateTime()();
  TextColumn get capability => text()();

  @override
  Set<Column<Object>> get primaryKey => {notificationId};
}

class NotificationPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get defaultLeadMinutes =>
      integer().withDefault(const Constant(10))();
  BoolColumn get soundAndVibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DataSyncPreferences extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get autoSyncEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class EncryptedSyncChanges extends Table {
  IntColumn get cursor => integer()();
  TextColumn get collectionName => text().withLength(min: 2, max: 64)();
  TextColumn get objectId => text().withLength(min: 36, max: 36)();
  TextColumn get operationId => text().withLength(min: 36, max: 36)();
  TextColumn get deviceId => text().withLength(min: 36, max: 36)();
  IntColumn get revision => integer()();
  BoolColumn get deleted => boolean()();
  BlobColumn get ciphertext => blob().nullable()();
  BlobColumn get nonce => blob().nullable()();
  IntColumn get keyVersion => integer().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cursor};
}

class AiProviderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => text()();
  TextColumn get baseUrl => text()();
  TextColumn get textModel => text()();
  TextColumn get imageModel => text().nullable()();
  TextColumn get secretRef => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AiConversations extends Table {
  TextColumn get id => text()();
  TextColumn get providerId =>
      text().references(AiProviderConfigs, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get previousResponseId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AiRuns extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(AiConversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text()();
  TextColumn get model => text()();
  TextColumn get requestDigest => text()();
  TextColumn get responseId => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AiToolCalls extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(AiRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get argumentsJson => text()();
  TextColumn get risk => text()();
  TextColumn get approvalStatus => text()();
  TextColumn get resultJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SharePollRefs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get inviteUrl => text()();
  TextColumn get publicToken => text().nullable()();
  TextColumn get timezoneId => text().withDefault(const Constant('UTC'))();
  TextColumn get manageTokenSecretRef => text()();
  TextColumn get status => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get selectedSlotJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Hosts,
    HostGroups,
    KnownHostKeys,
    OperationTags,
    HostOperationTags,
    AgentStates,
    PortForwardProfiles,
    CommandSnippets,
    CommandBatches,
    CommandResults,
    TransferJobs,
    ScheduleEvents,
    ScheduleReminders,
    NotificationMappings,
    NotificationPreferences,
    AiProviderConfigs,
    AiConversations,
    AiRuns,
    AiToolCalls,
    SharePollRefs,
    DataSyncPreferences,
    EncryptedSyncChanges,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.openForAccount(String accountId) =>
      AppDatabase(_openConnection(accountId));
  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(hosts, hosts.notes);
        await migrator.addColumn(hosts, hosts.terminalMode);
        await migrator.addColumn(hosts, hosts.deletedAt);
        await migrator.addColumn(hostGroups, hostGroups.createdAt);
        await migrator.addColumn(hostGroups, hostGroups.updatedAt);
        await migrator.addColumn(knownHostKeys, knownHostKeys.status);
        await migrator.createTable(operationTags);
        await migrator.createTable(hostOperationTags);
        await migrator.createTable(agentStates);
        await migrator.createTable(portForwardProfiles);
        await migrator.createTable(commandSnippets);
        await migrator.createTable(commandBatches);
        await migrator.createTable(commandResults);
        await migrator.createTable(transferJobs);
      }
      if (from < 3) {
        await migrator.addColumn(sharePollRefs, sharePollRefs.publicToken);
        await migrator.addColumn(sharePollRefs, sharePollRefs.timezoneId);
        await migrator.addColumn(sharePollRefs, sharePollRefs.version);
      }
      if (from < 4) {
        await migrator.addColumn(hosts, hosts.system);
      }
      if (from < 5) {
        await migrator.createTable(notificationPreferences);
      }
      if (from < 6) {
        await migrator.createTable(dataSyncPreferences);
        await migrator.createTable(encryptedSyncChanges);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}

LazyDatabase _openConnection(String accountId) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(accountId)) {
    throw ArgumentError.value(accountId, 'accountId', 'Invalid account ID');
  }
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final dataDirectory = Directory(
      p.join(directory.path, 'daylink', 'accounts', accountId.toLowerCase()),
    );
    await dataDirectory.create(recursive: true);
    return NativeDatabase.createInBackground(
      File(p.join(dataDirectory.path, 'app.db')),
    );
  });
}
