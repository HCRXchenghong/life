// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HostsTable extends Hosts with TableInfo<$HostsTable, Host> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(22),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _terminalModeMeta = const VerificationMeta(
    'terminalMode',
  );
  @override
  late final GeneratedColumn<String> terminalMode = GeneratedColumn<String>(
    'terminal_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('direct'),
  );
  static const VerificationMeta _agentStateMeta = const VerificationMeta(
    'agentState',
  );
  @override
  late final GeneratedColumn<String> agentState = GeneratedColumn<String>(
    'agent_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    address,
    port,
    username,
    groupId,
    credentialRef,
    notes,
    favorite,
    terminalMode,
    agentState,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hosts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Host> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('terminal_mode')) {
      context.handle(
        _terminalModeMeta,
        terminalMode.isAcceptableOrUnknown(
          data['terminal_mode']!,
          _terminalModeMeta,
        ),
      );
    }
    if (data.containsKey('agent_state')) {
      context.handle(
        _agentStateMeta,
        agentState.isAcceptableOrUnknown(data['agent_state']!, _agentStateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Host map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Host(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      terminalMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terminal_mode'],
      )!,
      agentState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HostsTable createAlias(String alias) {
    return $HostsTable(attachedDatabase, alias);
  }
}

class Host extends DataClass implements Insertable<Host> {
  final String id;
  final String name;
  final String address;
  final int port;
  final String username;
  final String? groupId;
  final String? credentialRef;
  final String notes;
  final bool favorite;
  final String terminalMode;
  final String agentState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Host({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.username,
    this.groupId,
    this.credentialRef,
    required this.notes,
    required this.favorite,
    required this.terminalMode,
    required this.agentState,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['port'] = Variable<int>(port);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    map['notes'] = Variable<String>(notes);
    map['favorite'] = Variable<bool>(favorite);
    map['terminal_mode'] = Variable<String>(terminalMode);
    map['agent_state'] = Variable<String>(agentState);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  HostsCompanion toCompanion(bool nullToAbsent) {
    return HostsCompanion(
      id: Value(id),
      name: Value(name),
      address: Value(address),
      port: Value(port),
      username: Value(username),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      notes: Value(notes),
      favorite: Value(favorite),
      terminalMode: Value(terminalMode),
      agentState: Value(agentState),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Host.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Host(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      port: serializer.fromJson<int>(json['port']),
      username: serializer.fromJson<String>(json['username']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      notes: serializer.fromJson<String>(json['notes']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      terminalMode: serializer.fromJson<String>(json['terminalMode']),
      agentState: serializer.fromJson<String>(json['agentState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'port': serializer.toJson<int>(port),
      'username': serializer.toJson<String>(username),
      'groupId': serializer.toJson<String?>(groupId),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'notes': serializer.toJson<String>(notes),
      'favorite': serializer.toJson<bool>(favorite),
      'terminalMode': serializer.toJson<String>(terminalMode),
      'agentState': serializer.toJson<String>(agentState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Host copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    String? username,
    Value<String?> groupId = const Value.absent(),
    Value<String?> credentialRef = const Value.absent(),
    String? notes,
    bool? favorite,
    String? terminalMode,
    String? agentState,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Host(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    port: port ?? this.port,
    username: username ?? this.username,
    groupId: groupId.present ? groupId.value : this.groupId,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    notes: notes ?? this.notes,
    favorite: favorite ?? this.favorite,
    terminalMode: terminalMode ?? this.terminalMode,
    agentState: agentState ?? this.agentState,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Host copyWithCompanion(HostsCompanion data) {
    return Host(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      port: data.port.present ? data.port.value : this.port,
      username: data.username.present ? data.username.value : this.username,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      notes: data.notes.present ? data.notes.value : this.notes,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      terminalMode: data.terminalMode.present
          ? data.terminalMode.value
          : this.terminalMode,
      agentState: data.agentState.present
          ? data.agentState.value
          : this.agentState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Host(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('groupId: $groupId, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('notes: $notes, ')
          ..write('favorite: $favorite, ')
          ..write('terminalMode: $terminalMode, ')
          ..write('agentState: $agentState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    address,
    port,
    username,
    groupId,
    credentialRef,
    notes,
    favorite,
    terminalMode,
    agentState,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Host &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.port == this.port &&
          other.username == this.username &&
          other.groupId == this.groupId &&
          other.credentialRef == this.credentialRef &&
          other.notes == this.notes &&
          other.favorite == this.favorite &&
          other.terminalMode == this.terminalMode &&
          other.agentState == this.agentState &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class HostsCompanion extends UpdateCompanion<Host> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> address;
  final Value<int> port;
  final Value<String> username;
  final Value<String?> groupId;
  final Value<String?> credentialRef;
  final Value<String> notes;
  final Value<bool> favorite;
  final Value<String> terminalMode;
  final Value<String> agentState;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const HostsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.groupId = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.notes = const Value.absent(),
    this.favorite = const Value.absent(),
    this.terminalMode = const Value.absent(),
    this.agentState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HostsCompanion.insert({
    required String id,
    required String name,
    required String address,
    this.port = const Value.absent(),
    required String username,
    this.groupId = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.notes = const Value.absent(),
    this.favorite = const Value.absent(),
    this.terminalMode = const Value.absent(),
    this.agentState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       address = Value(address),
       username = Value(username);
  static Insertable<Host> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<int>? port,
    Expression<String>? username,
    Expression<String>? groupId,
    Expression<String>? credentialRef,
    Expression<String>? notes,
    Expression<bool>? favorite,
    Expression<String>? terminalMode,
    Expression<String>? agentState,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (groupId != null) 'group_id': groupId,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (notes != null) 'notes': notes,
      if (favorite != null) 'favorite': favorite,
      if (terminalMode != null) 'terminal_mode': terminalMode,
      if (agentState != null) 'agent_state': agentState,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HostsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? address,
    Value<int>? port,
    Value<String>? username,
    Value<String?>? groupId,
    Value<String?>? credentialRef,
    Value<String>? notes,
    Value<bool>? favorite,
    Value<String>? terminalMode,
    Value<String>? agentState,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HostsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      username: username ?? this.username,
      groupId: groupId ?? this.groupId,
      credentialRef: credentialRef ?? this.credentialRef,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      terminalMode: terminalMode ?? this.terminalMode,
      agentState: agentState ?? this.agentState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (terminalMode.present) {
      map['terminal_mode'] = Variable<String>(terminalMode.value);
    }
    if (agentState.present) {
      map['agent_state'] = Variable<String>(agentState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HostsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('groupId: $groupId, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('notes: $notes, ')
          ..write('favorite: $favorite, ')
          ..write('terminalMode: $terminalMode, ')
          ..write('agentState: $agentState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HostGroupsTable extends HostGroups
    with TableInfo<$HostGroupsTable, HostGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HostGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'host_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<HostGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HostGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HostGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HostGroupsTable createAlias(String alias) {
    return $HostGroupsTable(attachedDatabase, alias);
  }
}

class HostGroup extends DataClass implements Insertable<HostGroup> {
  final String id;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const HostGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HostGroupsCompanion toCompanion(bool nullToAbsent) {
    return HostGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory HostGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HostGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HostGroup copyWith({
    String? id,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => HostGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HostGroup copyWithCompanion(HostGroupsCompanion data) {
    return HostGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HostGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HostGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class HostGroupsCompanion extends UpdateCompanion<HostGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HostGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HostGroupsCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<HostGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HostGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return HostGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HostGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnownHostKeysTable extends KnownHostKeys
    with TableInfo<$KnownHostKeysTable, KnownHostKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownHostKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _algorithmMeta = const VerificationMeta(
    'algorithm',
  );
  @override
  late final GeneratedColumn<String> algorithm = GeneratedColumn<String>(
    'algorithm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintSha256Meta = const VerificationMeta(
    'fingerprintSha256',
  );
  @override
  late final GeneratedColumn<String> fingerprintSha256 =
      GeneratedColumn<String>(
        'fingerprint_sha256',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('accepted'),
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
    'accepted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hostId,
    algorithm,
    fingerprintSha256,
    status,
    acceptedAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_host_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnownHostKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('algorithm')) {
      context.handle(
        _algorithmMeta,
        algorithm.isAcceptableOrUnknown(data['algorithm']!, _algorithmMeta),
      );
    } else if (isInserting) {
      context.missing(_algorithmMeta);
    }
    if (data.containsKey('fingerprint_sha256')) {
      context.handle(
        _fingerprintSha256Meta,
        fingerprintSha256.isAcceptableOrUnknown(
          data['fingerprint_sha256']!,
          _fingerprintSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintSha256Meta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acceptedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId};
  @override
  KnownHostKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownHostKey(
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      algorithm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm'],
      )!,
      fingerprintSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint_sha256'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accepted_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $KnownHostKeysTable createAlias(String alias) {
    return $KnownHostKeysTable(attachedDatabase, alias);
  }
}

class KnownHostKey extends DataClass implements Insertable<KnownHostKey> {
  final String hostId;
  final String algorithm;
  final String fingerprintSha256;
  final String status;
  final DateTime acceptedAt;
  final DateTime lastSeenAt;
  const KnownHostKey({
    required this.hostId,
    required this.algorithm,
    required this.fingerprintSha256,
    required this.status,
    required this.acceptedAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host_id'] = Variable<String>(hostId);
    map['algorithm'] = Variable<String>(algorithm);
    map['fingerprint_sha256'] = Variable<String>(fingerprintSha256);
    map['status'] = Variable<String>(status);
    map['accepted_at'] = Variable<DateTime>(acceptedAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  KnownHostKeysCompanion toCompanion(bool nullToAbsent) {
    return KnownHostKeysCompanion(
      hostId: Value(hostId),
      algorithm: Value(algorithm),
      fingerprintSha256: Value(fingerprintSha256),
      status: Value(status),
      acceptedAt: Value(acceptedAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory KnownHostKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownHostKey(
      hostId: serializer.fromJson<String>(json['hostId']),
      algorithm: serializer.fromJson<String>(json['algorithm']),
      fingerprintSha256: serializer.fromJson<String>(json['fingerprintSha256']),
      status: serializer.fromJson<String>(json['status']),
      acceptedAt: serializer.fromJson<DateTime>(json['acceptedAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hostId': serializer.toJson<String>(hostId),
      'algorithm': serializer.toJson<String>(algorithm),
      'fingerprintSha256': serializer.toJson<String>(fingerprintSha256),
      'status': serializer.toJson<String>(status),
      'acceptedAt': serializer.toJson<DateTime>(acceptedAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  KnownHostKey copyWith({
    String? hostId,
    String? algorithm,
    String? fingerprintSha256,
    String? status,
    DateTime? acceptedAt,
    DateTime? lastSeenAt,
  }) => KnownHostKey(
    hostId: hostId ?? this.hostId,
    algorithm: algorithm ?? this.algorithm,
    fingerprintSha256: fingerprintSha256 ?? this.fingerprintSha256,
    status: status ?? this.status,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  KnownHostKey copyWithCompanion(KnownHostKeysCompanion data) {
    return KnownHostKey(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      algorithm: data.algorithm.present ? data.algorithm.value : this.algorithm,
      fingerprintSha256: data.fingerprintSha256.present
          ? data.fingerprintSha256.value
          : this.fingerprintSha256,
      status: data.status.present ? data.status.value : this.status,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownHostKey(')
          ..write('hostId: $hostId, ')
          ..write('algorithm: $algorithm, ')
          ..write('fingerprintSha256: $fingerprintSha256, ')
          ..write('status: $status, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hostId,
    algorithm,
    fingerprintSha256,
    status,
    acceptedAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownHostKey &&
          other.hostId == this.hostId &&
          other.algorithm == this.algorithm &&
          other.fingerprintSha256 == this.fingerprintSha256 &&
          other.status == this.status &&
          other.acceptedAt == this.acceptedAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class KnownHostKeysCompanion extends UpdateCompanion<KnownHostKey> {
  final Value<String> hostId;
  final Value<String> algorithm;
  final Value<String> fingerprintSha256;
  final Value<String> status;
  final Value<DateTime> acceptedAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const KnownHostKeysCompanion({
    this.hostId = const Value.absent(),
    this.algorithm = const Value.absent(),
    this.fingerprintSha256 = const Value.absent(),
    this.status = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnownHostKeysCompanion.insert({
    required String hostId,
    required String algorithm,
    required String fingerprintSha256,
    this.status = const Value.absent(),
    required DateTime acceptedAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : hostId = Value(hostId),
       algorithm = Value(algorithm),
       fingerprintSha256 = Value(fingerprintSha256),
       acceptedAt = Value(acceptedAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<KnownHostKey> custom({
    Expression<String>? hostId,
    Expression<String>? algorithm,
    Expression<String>? fingerprintSha256,
    Expression<String>? status,
    Expression<DateTime>? acceptedAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hostId != null) 'host_id': hostId,
      if (algorithm != null) 'algorithm': algorithm,
      if (fingerprintSha256 != null) 'fingerprint_sha256': fingerprintSha256,
      if (status != null) 'status': status,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnownHostKeysCompanion copyWith({
    Value<String>? hostId,
    Value<String>? algorithm,
    Value<String>? fingerprintSha256,
    Value<String>? status,
    Value<DateTime>? acceptedAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return KnownHostKeysCompanion(
      hostId: hostId ?? this.hostId,
      algorithm: algorithm ?? this.algorithm,
      fingerprintSha256: fingerprintSha256 ?? this.fingerprintSha256,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (algorithm.present) {
      map['algorithm'] = Variable<String>(algorithm.value);
    }
    if (fingerprintSha256.present) {
      map['fingerprint_sha256'] = Variable<String>(fingerprintSha256.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownHostKeysCompanion(')
          ..write('hostId: $hostId, ')
          ..write('algorithm: $algorithm, ')
          ..write('fingerprintSha256: $fingerprintSha256, ')
          ..write('status: $status, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationTagsTable extends OperationTags
    with TableInfo<$OperationTagsTable, OperationTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorArgb];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      ),
    );
  }

  @override
  $OperationTagsTable createAlias(String alias) {
    return $OperationTagsTable(attachedDatabase, alias);
  }
}

class OperationTag extends DataClass implements Insertable<OperationTag> {
  final String id;
  final String name;
  final int? colorArgb;
  const OperationTag({required this.id, required this.name, this.colorArgb});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || colorArgb != null) {
      map['color_argb'] = Variable<int>(colorArgb);
    }
    return map;
  }

  OperationTagsCompanion toCompanion(bool nullToAbsent) {
    return OperationTagsCompanion(
      id: Value(id),
      name: Value(name),
      colorArgb: colorArgb == null && nullToAbsent
          ? const Value.absent()
          : Value(colorArgb),
    );
  }

  factory OperationTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationTag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorArgb: serializer.fromJson<int?>(json['colorArgb']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorArgb': serializer.toJson<int?>(colorArgb),
    };
  }

  OperationTag copyWith({
    String? id,
    String? name,
    Value<int?> colorArgb = const Value.absent(),
  }) => OperationTag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb.present ? colorArgb.value : this.colorArgb,
  );
  OperationTag copyWithCompanion(OperationTagsCompanion data) {
    return OperationTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationTag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorArgb);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationTag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorArgb == this.colorArgb);
}

class OperationTagsCompanion extends UpdateCompanion<OperationTag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> colorArgb;
  final Value<int> rowid;
  const OperationTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationTagsCompanion.insert({
    required String id,
    required String name,
    this.colorArgb = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<OperationTag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorArgb,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? colorArgb,
    Value<int>? rowid,
  }) {
    return OperationTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HostOperationTagsTable extends HostOperationTags
    with TableInfo<$HostOperationTagsTable, HostOperationTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HostOperationTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES operation_tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [hostId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'host_operation_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<HostOperationTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId, tagId};
  @override
  HostOperationTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HostOperationTag(
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $HostOperationTagsTable createAlias(String alias) {
    return $HostOperationTagsTable(attachedDatabase, alias);
  }
}

class HostOperationTag extends DataClass
    implements Insertable<HostOperationTag> {
  final String hostId;
  final String tagId;
  const HostOperationTag({required this.hostId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host_id'] = Variable<String>(hostId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  HostOperationTagsCompanion toCompanion(bool nullToAbsent) {
    return HostOperationTagsCompanion(
      hostId: Value(hostId),
      tagId: Value(tagId),
    );
  }

  factory HostOperationTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HostOperationTag(
      hostId: serializer.fromJson<String>(json['hostId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hostId': serializer.toJson<String>(hostId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  HostOperationTag copyWith({String? hostId, String? tagId}) =>
      HostOperationTag(
        hostId: hostId ?? this.hostId,
        tagId: tagId ?? this.tagId,
      );
  HostOperationTag copyWithCompanion(HostOperationTagsCompanion data) {
    return HostOperationTag(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HostOperationTag(')
          ..write('hostId: $hostId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hostId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HostOperationTag &&
          other.hostId == this.hostId &&
          other.tagId == this.tagId);
}

class HostOperationTagsCompanion extends UpdateCompanion<HostOperationTag> {
  final Value<String> hostId;
  final Value<String> tagId;
  final Value<int> rowid;
  const HostOperationTagsCompanion({
    this.hostId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HostOperationTagsCompanion.insert({
    required String hostId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : hostId = Value(hostId),
       tagId = Value(tagId);
  static Insertable<HostOperationTag> custom({
    Expression<String>? hostId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hostId != null) 'host_id': hostId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HostOperationTagsCompanion copyWith({
    Value<String>? hostId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return HostOperationTagsCompanion(
      hostId: hostId ?? this.hostId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HostOperationTagsCompanion(')
          ..write('hostId: $hostId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentStatesTable extends AgentStates
    with TableInfo<$AgentStatesTable, AgentState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
    'protocol_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentVersionMeta = const VerificationMeta(
    'agentVersion',
  );
  @override
  late final GeneratedColumn<String> agentVersion = GeneratedColumn<String>(
    'agent_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _architectureMeta = const VerificationMeta(
    'architecture',
  );
  @override
  late final GeneratedColumn<String> architecture = GeneratedColumn<String>(
    'architecture',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportMeta = const VerificationMeta(
    'transport',
  );
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
    'transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _healthMeta = const VerificationMeta('health');
  @override
  late final GeneratedColumn<String> health = GeneratedColumn<String>(
    'health',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hostId,
    protocolVersion,
    agentVersion,
    architecture,
    capabilitiesJson,
    transport,
    health,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_protocolVersionMeta);
    }
    if (data.containsKey('agent_version')) {
      context.handle(
        _agentVersionMeta,
        agentVersion.isAcceptableOrUnknown(
          data['agent_version']!,
          _agentVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_agentVersionMeta);
    }
    if (data.containsKey('architecture')) {
      context.handle(
        _architectureMeta,
        architecture.isAcceptableOrUnknown(
          data['architecture']!,
          _architectureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_architectureMeta);
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesJsonMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(
        _transportMeta,
        transport.isAcceptableOrUnknown(data['transport']!, _transportMeta),
      );
    } else if (isInserting) {
      context.missing(_transportMeta);
    }
    if (data.containsKey('health')) {
      context.handle(
        _healthMeta,
        health.isAcceptableOrUnknown(data['health']!, _healthMeta),
      );
    } else if (isInserting) {
      context.missing(_healthMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hostId};
  @override
  AgentState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentState(
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol_version'],
      )!,
      agentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_version'],
      )!,
      architecture: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}architecture'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      transport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport'],
      )!,
      health: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $AgentStatesTable createAlias(String alias) {
    return $AgentStatesTable(attachedDatabase, alias);
  }
}

class AgentState extends DataClass implements Insertable<AgentState> {
  final String hostId;
  final int protocolVersion;
  final String agentVersion;
  final String architecture;
  final String capabilitiesJson;
  final String transport;
  final String health;
  final DateTime lastSeenAt;
  const AgentState({
    required this.hostId,
    required this.protocolVersion,
    required this.agentVersion,
    required this.architecture,
    required this.capabilitiesJson,
    required this.transport,
    required this.health,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['host_id'] = Variable<String>(hostId);
    map['protocol_version'] = Variable<int>(protocolVersion);
    map['agent_version'] = Variable<String>(agentVersion);
    map['architecture'] = Variable<String>(architecture);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['transport'] = Variable<String>(transport);
    map['health'] = Variable<String>(health);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  AgentStatesCompanion toCompanion(bool nullToAbsent) {
    return AgentStatesCompanion(
      hostId: Value(hostId),
      protocolVersion: Value(protocolVersion),
      agentVersion: Value(agentVersion),
      architecture: Value(architecture),
      capabilitiesJson: Value(capabilitiesJson),
      transport: Value(transport),
      health: Value(health),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory AgentState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentState(
      hostId: serializer.fromJson<String>(json['hostId']),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      agentVersion: serializer.fromJson<String>(json['agentVersion']),
      architecture: serializer.fromJson<String>(json['architecture']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      transport: serializer.fromJson<String>(json['transport']),
      health: serializer.fromJson<String>(json['health']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hostId': serializer.toJson<String>(hostId),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'agentVersion': serializer.toJson<String>(agentVersion),
      'architecture': serializer.toJson<String>(architecture),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'transport': serializer.toJson<String>(transport),
      'health': serializer.toJson<String>(health),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  AgentState copyWith({
    String? hostId,
    int? protocolVersion,
    String? agentVersion,
    String? architecture,
    String? capabilitiesJson,
    String? transport,
    String? health,
    DateTime? lastSeenAt,
  }) => AgentState(
    hostId: hostId ?? this.hostId,
    protocolVersion: protocolVersion ?? this.protocolVersion,
    agentVersion: agentVersion ?? this.agentVersion,
    architecture: architecture ?? this.architecture,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    transport: transport ?? this.transport,
    health: health ?? this.health,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  AgentState copyWithCompanion(AgentStatesCompanion data) {
    return AgentState(
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      agentVersion: data.agentVersion.present
          ? data.agentVersion.value
          : this.agentVersion,
      architecture: data.architecture.present
          ? data.architecture.value
          : this.architecture,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      transport: data.transport.present ? data.transport.value : this.transport,
      health: data.health.present ? data.health.value : this.health,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentState(')
          ..write('hostId: $hostId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('agentVersion: $agentVersion, ')
          ..write('architecture: $architecture, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('transport: $transport, ')
          ..write('health: $health, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hostId,
    protocolVersion,
    agentVersion,
    architecture,
    capabilitiesJson,
    transport,
    health,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentState &&
          other.hostId == this.hostId &&
          other.protocolVersion == this.protocolVersion &&
          other.agentVersion == this.agentVersion &&
          other.architecture == this.architecture &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.transport == this.transport &&
          other.health == this.health &&
          other.lastSeenAt == this.lastSeenAt);
}

class AgentStatesCompanion extends UpdateCompanion<AgentState> {
  final Value<String> hostId;
  final Value<int> protocolVersion;
  final Value<String> agentVersion;
  final Value<String> architecture;
  final Value<String> capabilitiesJson;
  final Value<String> transport;
  final Value<String> health;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const AgentStatesCompanion({
    this.hostId = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.agentVersion = const Value.absent(),
    this.architecture = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.transport = const Value.absent(),
    this.health = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentStatesCompanion.insert({
    required String hostId,
    required int protocolVersion,
    required String agentVersion,
    required String architecture,
    required String capabilitiesJson,
    required String transport,
    required String health,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : hostId = Value(hostId),
       protocolVersion = Value(protocolVersion),
       agentVersion = Value(agentVersion),
       architecture = Value(architecture),
       capabilitiesJson = Value(capabilitiesJson),
       transport = Value(transport),
       health = Value(health),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<AgentState> custom({
    Expression<String>? hostId,
    Expression<int>? protocolVersion,
    Expression<String>? agentVersion,
    Expression<String>? architecture,
    Expression<String>? capabilitiesJson,
    Expression<String>? transport,
    Expression<String>? health,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hostId != null) 'host_id': hostId,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (agentVersion != null) 'agent_version': agentVersion,
      if (architecture != null) 'architecture': architecture,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (transport != null) 'transport': transport,
      if (health != null) 'health': health,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentStatesCompanion copyWith({
    Value<String>? hostId,
    Value<int>? protocolVersion,
    Value<String>? agentVersion,
    Value<String>? architecture,
    Value<String>? capabilitiesJson,
    Value<String>? transport,
    Value<String>? health,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return AgentStatesCompanion(
      hostId: hostId ?? this.hostId,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      agentVersion: agentVersion ?? this.agentVersion,
      architecture: architecture ?? this.architecture,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      transport: transport ?? this.transport,
      health: health ?? this.health,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (agentVersion.present) {
      map['agent_version'] = Variable<String>(agentVersion.value);
    }
    if (architecture.present) {
      map['architecture'] = Variable<String>(architecture.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (health.present) {
      map['health'] = Variable<String>(health.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentStatesCompanion(')
          ..write('hostId: $hostId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('agentVersion: $agentVersion, ')
          ..write('architecture: $architecture, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('transport: $transport, ')
          ..write('health: $health, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PortForwardProfilesTable extends PortForwardProfiles
    with TableInfo<$PortForwardProfilesTable, PortForwardProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortForwardProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bindAddressMeta = const VerificationMeta(
    'bindAddress',
  );
  @override
  late final GeneratedColumn<String> bindAddress = GeneratedColumn<String>(
    'bind_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('127.0.0.1'),
  );
  static const VerificationMeta _localPortMeta = const VerificationMeta(
    'localPort',
  );
  @override
  late final GeneratedColumn<int> localPort = GeneratedColumn<int>(
    'local_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetHostMeta = const VerificationMeta(
    'targetHost',
  );
  @override
  late final GeneratedColumn<String> targetHost = GeneratedColumn<String>(
    'target_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPortMeta = const VerificationMeta(
    'targetPort',
  );
  @override
  late final GeneratedColumn<int> targetPort = GeneratedColumn<int>(
    'target_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoStartMeta = const VerificationMeta(
    'autoStart',
  );
  @override
  late final GeneratedColumn<bool> autoStart = GeneratedColumn<bool>(
    'auto_start',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_start" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('stopped'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hostId,
    name,
    bindAddress,
    localPort,
    targetHost,
    targetPort,
    autoStart,
    state,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'port_forward_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortForwardProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bind_address')) {
      context.handle(
        _bindAddressMeta,
        bindAddress.isAcceptableOrUnknown(
          data['bind_address']!,
          _bindAddressMeta,
        ),
      );
    }
    if (data.containsKey('local_port')) {
      context.handle(
        _localPortMeta,
        localPort.isAcceptableOrUnknown(data['local_port']!, _localPortMeta),
      );
    } else if (isInserting) {
      context.missing(_localPortMeta);
    }
    if (data.containsKey('target_host')) {
      context.handle(
        _targetHostMeta,
        targetHost.isAcceptableOrUnknown(data['target_host']!, _targetHostMeta),
      );
    } else if (isInserting) {
      context.missing(_targetHostMeta);
    }
    if (data.containsKey('target_port')) {
      context.handle(
        _targetPortMeta,
        targetPort.isAcceptableOrUnknown(data['target_port']!, _targetPortMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPortMeta);
    }
    if (data.containsKey('auto_start')) {
      context.handle(
        _autoStartMeta,
        autoStart.isAcceptableOrUnknown(data['auto_start']!, _autoStartMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortForwardProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortForwardProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bindAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bind_address'],
      )!,
      localPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_port'],
      )!,
      targetHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_host'],
      )!,
      targetPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_port'],
      )!,
      autoStart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_start'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PortForwardProfilesTable createAlias(String alias) {
    return $PortForwardProfilesTable(attachedDatabase, alias);
  }
}

class PortForwardProfile extends DataClass
    implements Insertable<PortForwardProfile> {
  final String id;
  final String hostId;
  final String name;
  final String bindAddress;
  final int localPort;
  final String targetHost;
  final int targetPort;
  final bool autoStart;
  final String state;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PortForwardProfile({
    required this.id,
    required this.hostId,
    required this.name,
    required this.bindAddress,
    required this.localPort,
    required this.targetHost,
    required this.targetPort,
    required this.autoStart,
    required this.state,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['host_id'] = Variable<String>(hostId);
    map['name'] = Variable<String>(name);
    map['bind_address'] = Variable<String>(bindAddress);
    map['local_port'] = Variable<int>(localPort);
    map['target_host'] = Variable<String>(targetHost);
    map['target_port'] = Variable<int>(targetPort);
    map['auto_start'] = Variable<bool>(autoStart);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PortForwardProfilesCompanion toCompanion(bool nullToAbsent) {
    return PortForwardProfilesCompanion(
      id: Value(id),
      hostId: Value(hostId),
      name: Value(name),
      bindAddress: Value(bindAddress),
      localPort: Value(localPort),
      targetHost: Value(targetHost),
      targetPort: Value(targetPort),
      autoStart: Value(autoStart),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PortForwardProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortForwardProfile(
      id: serializer.fromJson<String>(json['id']),
      hostId: serializer.fromJson<String>(json['hostId']),
      name: serializer.fromJson<String>(json['name']),
      bindAddress: serializer.fromJson<String>(json['bindAddress']),
      localPort: serializer.fromJson<int>(json['localPort']),
      targetHost: serializer.fromJson<String>(json['targetHost']),
      targetPort: serializer.fromJson<int>(json['targetPort']),
      autoStart: serializer.fromJson<bool>(json['autoStart']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hostId': serializer.toJson<String>(hostId),
      'name': serializer.toJson<String>(name),
      'bindAddress': serializer.toJson<String>(bindAddress),
      'localPort': serializer.toJson<int>(localPort),
      'targetHost': serializer.toJson<String>(targetHost),
      'targetPort': serializer.toJson<int>(targetPort),
      'autoStart': serializer.toJson<bool>(autoStart),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PortForwardProfile copyWith({
    String? id,
    String? hostId,
    String? name,
    String? bindAddress,
    int? localPort,
    String? targetHost,
    int? targetPort,
    bool? autoStart,
    String? state,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PortForwardProfile(
    id: id ?? this.id,
    hostId: hostId ?? this.hostId,
    name: name ?? this.name,
    bindAddress: bindAddress ?? this.bindAddress,
    localPort: localPort ?? this.localPort,
    targetHost: targetHost ?? this.targetHost,
    targetPort: targetPort ?? this.targetPort,
    autoStart: autoStart ?? this.autoStart,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PortForwardProfile copyWithCompanion(PortForwardProfilesCompanion data) {
    return PortForwardProfile(
      id: data.id.present ? data.id.value : this.id,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      name: data.name.present ? data.name.value : this.name,
      bindAddress: data.bindAddress.present
          ? data.bindAddress.value
          : this.bindAddress,
      localPort: data.localPort.present ? data.localPort.value : this.localPort,
      targetHost: data.targetHost.present
          ? data.targetHost.value
          : this.targetHost,
      targetPort: data.targetPort.present
          ? data.targetPort.value
          : this.targetPort,
      autoStart: data.autoStart.present ? data.autoStart.value : this.autoStart,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardProfile(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('name: $name, ')
          ..write('bindAddress: $bindAddress, ')
          ..write('localPort: $localPort, ')
          ..write('targetHost: $targetHost, ')
          ..write('targetPort: $targetPort, ')
          ..write('autoStart: $autoStart, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hostId,
    name,
    bindAddress,
    localPort,
    targetHost,
    targetPort,
    autoStart,
    state,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortForwardProfile &&
          other.id == this.id &&
          other.hostId == this.hostId &&
          other.name == this.name &&
          other.bindAddress == this.bindAddress &&
          other.localPort == this.localPort &&
          other.targetHost == this.targetHost &&
          other.targetPort == this.targetPort &&
          other.autoStart == this.autoStart &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PortForwardProfilesCompanion extends UpdateCompanion<PortForwardProfile> {
  final Value<String> id;
  final Value<String> hostId;
  final Value<String> name;
  final Value<String> bindAddress;
  final Value<int> localPort;
  final Value<String> targetHost;
  final Value<int> targetPort;
  final Value<bool> autoStart;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PortForwardProfilesCompanion({
    this.id = const Value.absent(),
    this.hostId = const Value.absent(),
    this.name = const Value.absent(),
    this.bindAddress = const Value.absent(),
    this.localPort = const Value.absent(),
    this.targetHost = const Value.absent(),
    this.targetPort = const Value.absent(),
    this.autoStart = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PortForwardProfilesCompanion.insert({
    required String id,
    required String hostId,
    required String name,
    this.bindAddress = const Value.absent(),
    required int localPort,
    required String targetHost,
    required int targetPort,
    this.autoStart = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hostId = Value(hostId),
       name = Value(name),
       localPort = Value(localPort),
       targetHost = Value(targetHost),
       targetPort = Value(targetPort);
  static Insertable<PortForwardProfile> custom({
    Expression<String>? id,
    Expression<String>? hostId,
    Expression<String>? name,
    Expression<String>? bindAddress,
    Expression<int>? localPort,
    Expression<String>? targetHost,
    Expression<int>? targetPort,
    Expression<bool>? autoStart,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hostId != null) 'host_id': hostId,
      if (name != null) 'name': name,
      if (bindAddress != null) 'bind_address': bindAddress,
      if (localPort != null) 'local_port': localPort,
      if (targetHost != null) 'target_host': targetHost,
      if (targetPort != null) 'target_port': targetPort,
      if (autoStart != null) 'auto_start': autoStart,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PortForwardProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? hostId,
    Value<String>? name,
    Value<String>? bindAddress,
    Value<int>? localPort,
    Value<String>? targetHost,
    Value<int>? targetPort,
    Value<bool>? autoStart,
    Value<String>? state,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PortForwardProfilesCompanion(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      name: name ?? this.name,
      bindAddress: bindAddress ?? this.bindAddress,
      localPort: localPort ?? this.localPort,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      autoStart: autoStart ?? this.autoStart,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bindAddress.present) {
      map['bind_address'] = Variable<String>(bindAddress.value);
    }
    if (localPort.present) {
      map['local_port'] = Variable<int>(localPort.value);
    }
    if (targetHost.present) {
      map['target_host'] = Variable<String>(targetHost.value);
    }
    if (targetPort.present) {
      map['target_port'] = Variable<int>(targetPort.value);
    }
    if (autoStart.present) {
      map['auto_start'] = Variable<bool>(autoStart.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardProfilesCompanion(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('name: $name, ')
          ..write('bindAddress: $bindAddress, ')
          ..write('localPort: $localPort, ')
          ..write('targetHost: $targetHost, ')
          ..write('targetPort: $targetPort, ')
          ..write('autoStart: $autoStart, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommandSnippetsTable extends CommandSnippets
    with TableInfo<$CommandSnippetsTable, CommandSnippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommandSnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32768,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _timeoutSecondsMeta = const VerificationMeta(
    'timeoutSeconds',
  );
  @override
  late final GeneratedColumn<int> timeoutSeconds = GeneratedColumn<int>(
    'timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    command,
    tagsJson,
    timeoutSeconds,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'command_snippets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CommandSnippet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('timeout_seconds')) {
      context.handle(
        _timeoutSecondsMeta,
        timeoutSeconds.isAcceptableOrUnknown(
          data['timeout_seconds']!,
          _timeoutSecondsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommandSnippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommandSnippet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      timeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_seconds'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CommandSnippetsTable createAlias(String alias) {
    return $CommandSnippetsTable(attachedDatabase, alias);
  }
}

class CommandSnippet extends DataClass implements Insertable<CommandSnippet> {
  final String id;
  final String name;
  final String command;
  final String tagsJson;
  final int timeoutSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CommandSnippet({
    required this.id,
    required this.name,
    required this.command,
    required this.tagsJson,
    required this.timeoutSeconds,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['command'] = Variable<String>(command);
    map['tags_json'] = Variable<String>(tagsJson);
    map['timeout_seconds'] = Variable<int>(timeoutSeconds);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CommandSnippetsCompanion toCompanion(bool nullToAbsent) {
    return CommandSnippetsCompanion(
      id: Value(id),
      name: Value(name),
      command: Value(command),
      tagsJson: Value(tagsJson),
      timeoutSeconds: Value(timeoutSeconds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CommandSnippet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommandSnippet(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      command: serializer.fromJson<String>(json['command']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      timeoutSeconds: serializer.fromJson<int>(json['timeoutSeconds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'command': serializer.toJson<String>(command),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'timeoutSeconds': serializer.toJson<int>(timeoutSeconds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CommandSnippet copyWith({
    String? id,
    String? name,
    String? command,
    String? tagsJson,
    int? timeoutSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CommandSnippet(
    id: id ?? this.id,
    name: name ?? this.name,
    command: command ?? this.command,
    tagsJson: tagsJson ?? this.tagsJson,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CommandSnippet copyWithCompanion(CommandSnippetsCompanion data) {
    return CommandSnippet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      command: data.command.present ? data.command.value : this.command,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      timeoutSeconds: data.timeoutSeconds.present
          ? data.timeoutSeconds.value
          : this.timeoutSeconds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommandSnippet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('command: $command, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    command,
    tagsJson,
    timeoutSeconds,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandSnippet &&
          other.id == this.id &&
          other.name == this.name &&
          other.command == this.command &&
          other.tagsJson == this.tagsJson &&
          other.timeoutSeconds == this.timeoutSeconds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CommandSnippetsCompanion extends UpdateCompanion<CommandSnippet> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> command;
  final Value<String> tagsJson;
  final Value<int> timeoutSeconds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CommandSnippetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.command = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommandSnippetsCompanion.insert({
    required String id,
    required String name,
    required String command,
    this.tagsJson = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       command = Value(command);
  static Insertable<CommandSnippet> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? command,
    Expression<String>? tagsJson,
    Expression<int>? timeoutSeconds,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (command != null) 'command': command,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommandSnippetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? command,
    Value<String>? tagsJson,
    Value<int>? timeoutSeconds,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CommandSnippetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      tagsJson: tagsJson ?? this.tagsJson,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (timeoutSeconds.present) {
      map['timeout_seconds'] = Variable<int>(timeoutSeconds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommandSnippetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('command: $command, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommandBatchesTable extends CommandBatches
    with TableInfo<$CommandBatchesTable, CommandBatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommandBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snippetIdMeta = const VerificationMeta(
    'snippetId',
  );
  @override
  late final GeneratedColumn<String> snippetId = GeneratedColumn<String>(
    'snippet_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES command_snippets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _commandSnapshotMeta = const VerificationMeta(
    'commandSnapshot',
  );
  @override
  late final GeneratedColumn<String> commandSnapshot = GeneratedColumn<String>(
    'command_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snippetId,
    commandSnapshot,
    status,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'command_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CommandBatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snippet_id')) {
      context.handle(
        _snippetIdMeta,
        snippetId.isAcceptableOrUnknown(data['snippet_id']!, _snippetIdMeta),
      );
    }
    if (data.containsKey('command_snapshot')) {
      context.handle(
        _commandSnapshotMeta,
        commandSnapshot.isAcceptableOrUnknown(
          data['command_snapshot']!,
          _commandSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandSnapshotMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommandBatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommandBatche(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snippetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet_id'],
      ),
      commandSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_snapshot'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $CommandBatchesTable createAlias(String alias) {
    return $CommandBatchesTable(attachedDatabase, alias);
  }
}

class CommandBatche extends DataClass implements Insertable<CommandBatche> {
  final String id;
  final String? snippetId;
  final String commandSnapshot;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  const CommandBatche({
    required this.id,
    this.snippetId,
    required this.commandSnapshot,
    required this.status,
    required this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || snippetId != null) {
      map['snippet_id'] = Variable<String>(snippetId);
    }
    map['command_snapshot'] = Variable<String>(commandSnapshot);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  CommandBatchesCompanion toCompanion(bool nullToAbsent) {
    return CommandBatchesCompanion(
      id: Value(id),
      snippetId: snippetId == null && nullToAbsent
          ? const Value.absent()
          : Value(snippetId),
      commandSnapshot: Value(commandSnapshot),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory CommandBatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommandBatche(
      id: serializer.fromJson<String>(json['id']),
      snippetId: serializer.fromJson<String?>(json['snippetId']),
      commandSnapshot: serializer.fromJson<String>(json['commandSnapshot']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'snippetId': serializer.toJson<String?>(snippetId),
      'commandSnapshot': serializer.toJson<String>(commandSnapshot),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  CommandBatche copyWith({
    String? id,
    Value<String?> snippetId = const Value.absent(),
    String? commandSnapshot,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => CommandBatche(
    id: id ?? this.id,
    snippetId: snippetId.present ? snippetId.value : this.snippetId,
    commandSnapshot: commandSnapshot ?? this.commandSnapshot,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  CommandBatche copyWithCompanion(CommandBatchesCompanion data) {
    return CommandBatche(
      id: data.id.present ? data.id.value : this.id,
      snippetId: data.snippetId.present ? data.snippetId.value : this.snippetId,
      commandSnapshot: data.commandSnapshot.present
          ? data.commandSnapshot.value
          : this.commandSnapshot,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommandBatche(')
          ..write('id: $id, ')
          ..write('snippetId: $snippetId, ')
          ..write('commandSnapshot: $commandSnapshot, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snippetId,
    commandSnapshot,
    status,
    startedAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandBatche &&
          other.id == this.id &&
          other.snippetId == this.snippetId &&
          other.commandSnapshot == this.commandSnapshot &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class CommandBatchesCompanion extends UpdateCompanion<CommandBatche> {
  final Value<String> id;
  final Value<String?> snippetId;
  final Value<String> commandSnapshot;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const CommandBatchesCompanion({
    this.id = const Value.absent(),
    this.snippetId = const Value.absent(),
    this.commandSnapshot = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommandBatchesCompanion.insert({
    required String id,
    this.snippetId = const Value.absent(),
    required String commandSnapshot,
    required String status,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       commandSnapshot = Value(commandSnapshot),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<CommandBatche> custom({
    Expression<String>? id,
    Expression<String>? snippetId,
    Expression<String>? commandSnapshot,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snippetId != null) 'snippet_id': snippetId,
      if (commandSnapshot != null) 'command_snapshot': commandSnapshot,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommandBatchesCompanion copyWith({
    Value<String>? id,
    Value<String?>? snippetId,
    Value<String>? commandSnapshot,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return CommandBatchesCompanion(
      id: id ?? this.id,
      snippetId: snippetId ?? this.snippetId,
      commandSnapshot: commandSnapshot ?? this.commandSnapshot,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snippetId.present) {
      map['snippet_id'] = Variable<String>(snippetId.value);
    }
    if (commandSnapshot.present) {
      map['command_snapshot'] = Variable<String>(commandSnapshot.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommandBatchesCompanion(')
          ..write('id: $id, ')
          ..write('snippetId: $snippetId, ')
          ..write('commandSnapshot: $commandSnapshot, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommandResultsTable extends CommandResults
    with TableInfo<$CommandResultsTable, CommandResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommandResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES command_batches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stdoutPreviewMeta = const VerificationMeta(
    'stdoutPreview',
  );
  @override
  late final GeneratedColumn<String> stdoutPreview = GeneratedColumn<String>(
    'stdout_preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _stderrPreviewMeta = const VerificationMeta(
    'stderrPreview',
  );
  @override
  late final GeneratedColumn<String> stderrPreview = GeneratedColumn<String>(
    'stderr_preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _artifactRefMeta = const VerificationMeta(
    'artifactRef',
  );
  @override
  late final GeneratedColumn<String> artifactRef = GeneratedColumn<String>(
    'artifact_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    batchId,
    hostId,
    status,
    exitCode,
    stdoutPreview,
    stderrPreview,
    artifactRef,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'command_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<CommandResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('stdout_preview')) {
      context.handle(
        _stdoutPreviewMeta,
        stdoutPreview.isAcceptableOrUnknown(
          data['stdout_preview']!,
          _stdoutPreviewMeta,
        ),
      );
    }
    if (data.containsKey('stderr_preview')) {
      context.handle(
        _stderrPreviewMeta,
        stderrPreview.isAcceptableOrUnknown(
          data['stderr_preview']!,
          _stderrPreviewMeta,
        ),
      );
    }
    if (data.containsKey('artifact_ref')) {
      context.handle(
        _artifactRefMeta,
        artifactRef.isAcceptableOrUnknown(
          data['artifact_ref']!,
          _artifactRefMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommandResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommandResult(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      stdoutPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stdout_preview'],
      )!,
      stderrPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stderr_preview'],
      )!,
      artifactRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifact_ref'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $CommandResultsTable createAlias(String alias) {
    return $CommandResultsTable(attachedDatabase, alias);
  }
}

class CommandResult extends DataClass implements Insertable<CommandResult> {
  final String id;
  final String batchId;
  final String hostId;
  final String status;
  final int? exitCode;
  final String stdoutPreview;
  final String stderrPreview;
  final String? artifactRef;
  final DateTime? completedAt;
  const CommandResult({
    required this.id,
    required this.batchId,
    required this.hostId,
    required this.status,
    this.exitCode,
    required this.stdoutPreview,
    required this.stderrPreview,
    this.artifactRef,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['batch_id'] = Variable<String>(batchId);
    map['host_id'] = Variable<String>(hostId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    map['stdout_preview'] = Variable<String>(stdoutPreview);
    map['stderr_preview'] = Variable<String>(stderrPreview);
    if (!nullToAbsent || artifactRef != null) {
      map['artifact_ref'] = Variable<String>(artifactRef);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  CommandResultsCompanion toCompanion(bool nullToAbsent) {
    return CommandResultsCompanion(
      id: Value(id),
      batchId: Value(batchId),
      hostId: Value(hostId),
      status: Value(status),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      stdoutPreview: Value(stdoutPreview),
      stderrPreview: Value(stderrPreview),
      artifactRef: artifactRef == null && nullToAbsent
          ? const Value.absent()
          : Value(artifactRef),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory CommandResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommandResult(
      id: serializer.fromJson<String>(json['id']),
      batchId: serializer.fromJson<String>(json['batchId']),
      hostId: serializer.fromJson<String>(json['hostId']),
      status: serializer.fromJson<String>(json['status']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      stdoutPreview: serializer.fromJson<String>(json['stdoutPreview']),
      stderrPreview: serializer.fromJson<String>(json['stderrPreview']),
      artifactRef: serializer.fromJson<String?>(json['artifactRef']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'batchId': serializer.toJson<String>(batchId),
      'hostId': serializer.toJson<String>(hostId),
      'status': serializer.toJson<String>(status),
      'exitCode': serializer.toJson<int?>(exitCode),
      'stdoutPreview': serializer.toJson<String>(stdoutPreview),
      'stderrPreview': serializer.toJson<String>(stderrPreview),
      'artifactRef': serializer.toJson<String?>(artifactRef),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  CommandResult copyWith({
    String? id,
    String? batchId,
    String? hostId,
    String? status,
    Value<int?> exitCode = const Value.absent(),
    String? stdoutPreview,
    String? stderrPreview,
    Value<String?> artifactRef = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => CommandResult(
    id: id ?? this.id,
    batchId: batchId ?? this.batchId,
    hostId: hostId ?? this.hostId,
    status: status ?? this.status,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    stdoutPreview: stdoutPreview ?? this.stdoutPreview,
    stderrPreview: stderrPreview ?? this.stderrPreview,
    artifactRef: artifactRef.present ? artifactRef.value : this.artifactRef,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  CommandResult copyWithCompanion(CommandResultsCompanion data) {
    return CommandResult(
      id: data.id.present ? data.id.value : this.id,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      status: data.status.present ? data.status.value : this.status,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      stdoutPreview: data.stdoutPreview.present
          ? data.stdoutPreview.value
          : this.stdoutPreview,
      stderrPreview: data.stderrPreview.present
          ? data.stderrPreview.value
          : this.stderrPreview,
      artifactRef: data.artifactRef.present
          ? data.artifactRef.value
          : this.artifactRef,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommandResult(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('hostId: $hostId, ')
          ..write('status: $status, ')
          ..write('exitCode: $exitCode, ')
          ..write('stdoutPreview: $stdoutPreview, ')
          ..write('stderrPreview: $stderrPreview, ')
          ..write('artifactRef: $artifactRef, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    batchId,
    hostId,
    status,
    exitCode,
    stdoutPreview,
    stderrPreview,
    artifactRef,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandResult &&
          other.id == this.id &&
          other.batchId == this.batchId &&
          other.hostId == this.hostId &&
          other.status == this.status &&
          other.exitCode == this.exitCode &&
          other.stdoutPreview == this.stdoutPreview &&
          other.stderrPreview == this.stderrPreview &&
          other.artifactRef == this.artifactRef &&
          other.completedAt == this.completedAt);
}

class CommandResultsCompanion extends UpdateCompanion<CommandResult> {
  final Value<String> id;
  final Value<String> batchId;
  final Value<String> hostId;
  final Value<String> status;
  final Value<int?> exitCode;
  final Value<String> stdoutPreview;
  final Value<String> stderrPreview;
  final Value<String?> artifactRef;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const CommandResultsCompanion({
    this.id = const Value.absent(),
    this.batchId = const Value.absent(),
    this.hostId = const Value.absent(),
    this.status = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.stdoutPreview = const Value.absent(),
    this.stderrPreview = const Value.absent(),
    this.artifactRef = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommandResultsCompanion.insert({
    required String id,
    required String batchId,
    required String hostId,
    required String status,
    this.exitCode = const Value.absent(),
    this.stdoutPreview = const Value.absent(),
    this.stderrPreview = const Value.absent(),
    this.artifactRef = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       batchId = Value(batchId),
       hostId = Value(hostId),
       status = Value(status);
  static Insertable<CommandResult> custom({
    Expression<String>? id,
    Expression<String>? batchId,
    Expression<String>? hostId,
    Expression<String>? status,
    Expression<int>? exitCode,
    Expression<String>? stdoutPreview,
    Expression<String>? stderrPreview,
    Expression<String>? artifactRef,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchId != null) 'batch_id': batchId,
      if (hostId != null) 'host_id': hostId,
      if (status != null) 'status': status,
      if (exitCode != null) 'exit_code': exitCode,
      if (stdoutPreview != null) 'stdout_preview': stdoutPreview,
      if (stderrPreview != null) 'stderr_preview': stderrPreview,
      if (artifactRef != null) 'artifact_ref': artifactRef,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommandResultsCompanion copyWith({
    Value<String>? id,
    Value<String>? batchId,
    Value<String>? hostId,
    Value<String>? status,
    Value<int?>? exitCode,
    Value<String>? stdoutPreview,
    Value<String>? stderrPreview,
    Value<String?>? artifactRef,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return CommandResultsCompanion(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      exitCode: exitCode ?? this.exitCode,
      stdoutPreview: stdoutPreview ?? this.stdoutPreview,
      stderrPreview: stderrPreview ?? this.stderrPreview,
      artifactRef: artifactRef ?? this.artifactRef,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (stdoutPreview.present) {
      map['stdout_preview'] = Variable<String>(stdoutPreview.value);
    }
    if (stderrPreview.present) {
      map['stderr_preview'] = Variable<String>(stderrPreview.value);
    }
    if (artifactRef.present) {
      map['artifact_ref'] = Variable<String>(artifactRef.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommandResultsCompanion(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('hostId: $hostId, ')
          ..write('status: $status, ')
          ..write('exitCode: $exitCode, ')
          ..write('stdoutPreview: $stdoutPreview, ')
          ..write('stderrPreview: $stderrPreview, ')
          ..write('artifactRef: $artifactRef, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransferJobsTable extends TransferJobs
    with TableInfo<$TransferJobsTable, TransferJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransferJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostIdMeta = const VerificationMeta('hostId');
  @override
  late final GeneratedColumn<String> hostId = GeneratedColumn<String>(
    'host_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hosts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remotePathMeta = const VerificationMeta(
    'remotePath',
  );
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
    'remote_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedOffsetMeta = const VerificationMeta(
    'confirmedOffset',
  );
  @override
  late final GeneratedColumn<int> confirmedOffset = GeneratedColumn<int>(
    'confirmed_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expectedSha256Meta = const VerificationMeta(
    'expectedSha256',
  );
  @override
  late final GeneratedColumn<String> expectedSha256 = GeneratedColumn<String>(
    'expected_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteIdentityJsonMeta =
      const VerificationMeta('remoteIdentityJson');
  @override
  late final GeneratedColumn<String> remoteIdentityJson =
      GeneratedColumn<String>(
        'remote_identity_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hostId,
    direction,
    localPath,
    remotePath,
    totalBytes,
    confirmedOffset,
    expectedSha256,
    remoteIdentityJson,
    state,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfer_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransferJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('host_id')) {
      context.handle(
        _hostIdMeta,
        hostId.isAcceptableOrUnknown(data['host_id']!, _hostIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hostIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('remote_path')) {
      context.handle(
        _remotePathMeta,
        remotePath.isAcceptableOrUnknown(data['remote_path']!, _remotePathMeta),
      );
    } else if (isInserting) {
      context.missing(_remotePathMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalBytesMeta);
    }
    if (data.containsKey('confirmed_offset')) {
      context.handle(
        _confirmedOffsetMeta,
        confirmedOffset.isAcceptableOrUnknown(
          data['confirmed_offset']!,
          _confirmedOffsetMeta,
        ),
      );
    }
    if (data.containsKey('expected_sha256')) {
      context.handle(
        _expectedSha256Meta,
        expectedSha256.isAcceptableOrUnknown(
          data['expected_sha256']!,
          _expectedSha256Meta,
        ),
      );
    }
    if (data.containsKey('remote_identity_json')) {
      context.handle(
        _remoteIdentityJsonMeta,
        remoteIdentityJson.isAcceptableOrUnknown(
          data['remote_identity_json']!,
          _remoteIdentityJsonMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransferJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransferJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      hostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      remotePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_path'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      confirmedOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed_offset'],
      )!,
      expectedSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_sha256'],
      ),
      remoteIdentityJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_identity_json'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransferJobsTable createAlias(String alias) {
    return $TransferJobsTable(attachedDatabase, alias);
  }
}

class TransferJob extends DataClass implements Insertable<TransferJob> {
  final String id;
  final String hostId;
  final String direction;
  final String localPath;
  final String remotePath;
  final int totalBytes;
  final int confirmedOffset;
  final String? expectedSha256;
  final String? remoteIdentityJson;
  final String state;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransferJob({
    required this.id,
    required this.hostId,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    required this.totalBytes,
    required this.confirmedOffset,
    this.expectedSha256,
    this.remoteIdentityJson,
    required this.state,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['host_id'] = Variable<String>(hostId);
    map['direction'] = Variable<String>(direction);
    map['local_path'] = Variable<String>(localPath);
    map['remote_path'] = Variable<String>(remotePath);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['confirmed_offset'] = Variable<int>(confirmedOffset);
    if (!nullToAbsent || expectedSha256 != null) {
      map['expected_sha256'] = Variable<String>(expectedSha256);
    }
    if (!nullToAbsent || remoteIdentityJson != null) {
      map['remote_identity_json'] = Variable<String>(remoteIdentityJson);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransferJobsCompanion toCompanion(bool nullToAbsent) {
    return TransferJobsCompanion(
      id: Value(id),
      hostId: Value(hostId),
      direction: Value(direction),
      localPath: Value(localPath),
      remotePath: Value(remotePath),
      totalBytes: Value(totalBytes),
      confirmedOffset: Value(confirmedOffset),
      expectedSha256: expectedSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedSha256),
      remoteIdentityJson: remoteIdentityJson == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteIdentityJson),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransferJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransferJob(
      id: serializer.fromJson<String>(json['id']),
      hostId: serializer.fromJson<String>(json['hostId']),
      direction: serializer.fromJson<String>(json['direction']),
      localPath: serializer.fromJson<String>(json['localPath']),
      remotePath: serializer.fromJson<String>(json['remotePath']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      confirmedOffset: serializer.fromJson<int>(json['confirmedOffset']),
      expectedSha256: serializer.fromJson<String?>(json['expectedSha256']),
      remoteIdentityJson: serializer.fromJson<String?>(
        json['remoteIdentityJson'],
      ),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hostId': serializer.toJson<String>(hostId),
      'direction': serializer.toJson<String>(direction),
      'localPath': serializer.toJson<String>(localPath),
      'remotePath': serializer.toJson<String>(remotePath),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'confirmedOffset': serializer.toJson<int>(confirmedOffset),
      'expectedSha256': serializer.toJson<String?>(expectedSha256),
      'remoteIdentityJson': serializer.toJson<String?>(remoteIdentityJson),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransferJob copyWith({
    String? id,
    String? hostId,
    String? direction,
    String? localPath,
    String? remotePath,
    int? totalBytes,
    int? confirmedOffset,
    Value<String?> expectedSha256 = const Value.absent(),
    Value<String?> remoteIdentityJson = const Value.absent(),
    String? state,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransferJob(
    id: id ?? this.id,
    hostId: hostId ?? this.hostId,
    direction: direction ?? this.direction,
    localPath: localPath ?? this.localPath,
    remotePath: remotePath ?? this.remotePath,
    totalBytes: totalBytes ?? this.totalBytes,
    confirmedOffset: confirmedOffset ?? this.confirmedOffset,
    expectedSha256: expectedSha256.present
        ? expectedSha256.value
        : this.expectedSha256,
    remoteIdentityJson: remoteIdentityJson.present
        ? remoteIdentityJson.value
        : this.remoteIdentityJson,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransferJob copyWithCompanion(TransferJobsCompanion data) {
    return TransferJob(
      id: data.id.present ? data.id.value : this.id,
      hostId: data.hostId.present ? data.hostId.value : this.hostId,
      direction: data.direction.present ? data.direction.value : this.direction,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remotePath: data.remotePath.present
          ? data.remotePath.value
          : this.remotePath,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      confirmedOffset: data.confirmedOffset.present
          ? data.confirmedOffset.value
          : this.confirmedOffset,
      expectedSha256: data.expectedSha256.present
          ? data.expectedSha256.value
          : this.expectedSha256,
      remoteIdentityJson: data.remoteIdentityJson.present
          ? data.remoteIdentityJson.value
          : this.remoteIdentityJson,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransferJob(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('direction: $direction, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('confirmedOffset: $confirmedOffset, ')
          ..write('expectedSha256: $expectedSha256, ')
          ..write('remoteIdentityJson: $remoteIdentityJson, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hostId,
    direction,
    localPath,
    remotePath,
    totalBytes,
    confirmedOffset,
    expectedSha256,
    remoteIdentityJson,
    state,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransferJob &&
          other.id == this.id &&
          other.hostId == this.hostId &&
          other.direction == this.direction &&
          other.localPath == this.localPath &&
          other.remotePath == this.remotePath &&
          other.totalBytes == this.totalBytes &&
          other.confirmedOffset == this.confirmedOffset &&
          other.expectedSha256 == this.expectedSha256 &&
          other.remoteIdentityJson == this.remoteIdentityJson &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransferJobsCompanion extends UpdateCompanion<TransferJob> {
  final Value<String> id;
  final Value<String> hostId;
  final Value<String> direction;
  final Value<String> localPath;
  final Value<String> remotePath;
  final Value<int> totalBytes;
  final Value<int> confirmedOffset;
  final Value<String?> expectedSha256;
  final Value<String?> remoteIdentityJson;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransferJobsCompanion({
    this.id = const Value.absent(),
    this.hostId = const Value.absent(),
    this.direction = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.confirmedOffset = const Value.absent(),
    this.expectedSha256 = const Value.absent(),
    this.remoteIdentityJson = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransferJobsCompanion.insert({
    required String id,
    required String hostId,
    required String direction,
    required String localPath,
    required String remotePath,
    required int totalBytes,
    this.confirmedOffset = const Value.absent(),
    this.expectedSha256 = const Value.absent(),
    this.remoteIdentityJson = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hostId = Value(hostId),
       direction = Value(direction),
       localPath = Value(localPath),
       remotePath = Value(remotePath),
       totalBytes = Value(totalBytes);
  static Insertable<TransferJob> custom({
    Expression<String>? id,
    Expression<String>? hostId,
    Expression<String>? direction,
    Expression<String>? localPath,
    Expression<String>? remotePath,
    Expression<int>? totalBytes,
    Expression<int>? confirmedOffset,
    Expression<String>? expectedSha256,
    Expression<String>? remoteIdentityJson,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hostId != null) 'host_id': hostId,
      if (direction != null) 'direction': direction,
      if (localPath != null) 'local_path': localPath,
      if (remotePath != null) 'remote_path': remotePath,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (confirmedOffset != null) 'confirmed_offset': confirmedOffset,
      if (expectedSha256 != null) 'expected_sha256': expectedSha256,
      if (remoteIdentityJson != null)
        'remote_identity_json': remoteIdentityJson,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransferJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? hostId,
    Value<String>? direction,
    Value<String>? localPath,
    Value<String>? remotePath,
    Value<int>? totalBytes,
    Value<int>? confirmedOffset,
    Value<String?>? expectedSha256,
    Value<String?>? remoteIdentityJson,
    Value<String>? state,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransferJobsCompanion(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      direction: direction ?? this.direction,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      totalBytes: totalBytes ?? this.totalBytes,
      confirmedOffset: confirmedOffset ?? this.confirmedOffset,
      expectedSha256: expectedSha256 ?? this.expectedSha256,
      remoteIdentityJson: remoteIdentityJson ?? this.remoteIdentityJson,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hostId.present) {
      map['host_id'] = Variable<String>(hostId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (confirmedOffset.present) {
      map['confirmed_offset'] = Variable<int>(confirmedOffset.value);
    }
    if (expectedSha256.present) {
      map['expected_sha256'] = Variable<String>(expectedSha256.value);
    }
    if (remoteIdentityJson.present) {
      map['remote_identity_json'] = Variable<String>(remoteIdentityJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransferJobsCompanion(')
          ..write('id: $id, ')
          ..write('hostId: $hostId, ')
          ..write('direction: $direction, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('confirmedOffset: $confirmedOffset, ')
          ..write('expectedSha256: $expectedSha256, ')
          ..write('remoteIdentityJson: $remoteIdentityJson, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleEventsTable extends ScheduleEvents
    with TableInfo<$ScheduleEventsTable, ScheduleEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startsAtUtcMeta = const VerificationMeta(
    'startsAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startsAtUtc = GeneratedColumn<DateTime>(
    'starts_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneIdMeta = const VerificationMeta(
    'timezoneId',
  );
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
    'timezone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recurrenceJsonMeta = const VerificationMeta(
    'recurrenceJson',
  );
  @override
  late final GeneratedColumn<String> recurrenceJson = GeneratedColumn<String>(
    'recurrence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    startsAtUtc,
    durationMinutes,
    timezoneId,
    allDay,
    recurrenceJson,
    status,
    source,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('starts_at_utc')) {
      context.handle(
        _startsAtUtcMeta,
        startsAtUtc.isAcceptableOrUnknown(
          data['starts_at_utc']!,
          _startsAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startsAtUtcMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinutesMeta);
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('recurrence_json')) {
      context.handle(
        _recurrenceJsonMeta,
        recurrenceJson.isAcceptableOrUnknown(
          data['recurrence_json']!,
          _recurrenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      startsAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_at_utc'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      )!,
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      recurrenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScheduleEventsTable createAlias(String alias) {
    return $ScheduleEventsTable(attachedDatabase, alias);
  }
}

class ScheduleEvent extends DataClass implements Insertable<ScheduleEvent> {
  final String id;
  final String title;
  final String notes;
  final DateTime startsAtUtc;
  final int durationMinutes;
  final String timezoneId;
  final bool allDay;
  final String? recurrenceJson;
  final String status;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.startsAtUtc,
    required this.durationMinutes,
    required this.timezoneId,
    required this.allDay,
    this.recurrenceJson,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['starts_at_utc'] = Variable<DateTime>(startsAtUtc);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['timezone_id'] = Variable<String>(timezoneId);
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || recurrenceJson != null) {
      map['recurrence_json'] = Variable<String>(recurrenceJson);
    }
    map['status'] = Variable<String>(status);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScheduleEventsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleEventsCompanion(
      id: Value(id),
      title: Value(title),
      notes: Value(notes),
      startsAtUtc: Value(startsAtUtc),
      durationMinutes: Value(durationMinutes),
      timezoneId: Value(timezoneId),
      allDay: Value(allDay),
      recurrenceJson: recurrenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceJson),
      status: Value(status),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScheduleEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleEvent(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      startsAtUtc: serializer.fromJson<DateTime>(json['startsAtUtc']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      recurrenceJson: serializer.fromJson<String?>(json['recurrenceJson']),
      status: serializer.fromJson<String>(json['status']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'startsAtUtc': serializer.toJson<DateTime>(startsAtUtc),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'allDay': serializer.toJson<bool>(allDay),
      'recurrenceJson': serializer.toJson<String?>(recurrenceJson),
      'status': serializer.toJson<String>(status),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScheduleEvent copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? startsAtUtc,
    int? durationMinutes,
    String? timezoneId,
    bool? allDay,
    Value<String?> recurrenceJson = const Value.absent(),
    String? status,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScheduleEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    startsAtUtc: startsAtUtc ?? this.startsAtUtc,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    timezoneId: timezoneId ?? this.timezoneId,
    allDay: allDay ?? this.allDay,
    recurrenceJson: recurrenceJson.present
        ? recurrenceJson.value
        : this.recurrenceJson,
    status: status ?? this.status,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScheduleEvent copyWithCompanion(ScheduleEventsCompanion data) {
    return ScheduleEvent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      startsAtUtc: data.startsAtUtc.present
          ? data.startsAtUtc.value
          : this.startsAtUtc,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      recurrenceJson: data.recurrenceJson.present
          ? data.recurrenceJson.value
          : this.recurrenceJson,
      status: data.status.present ? data.status.value : this.status,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleEvent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startsAtUtc: $startsAtUtc, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('allDay: $allDay, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    startsAtUtc,
    durationMinutes,
    timezoneId,
    allDay,
    recurrenceJson,
    status,
    source,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleEvent &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.startsAtUtc == this.startsAtUtc &&
          other.durationMinutes == this.durationMinutes &&
          other.timezoneId == this.timezoneId &&
          other.allDay == this.allDay &&
          other.recurrenceJson == this.recurrenceJson &&
          other.status == this.status &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduleEventsCompanion extends UpdateCompanion<ScheduleEvent> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> notes;
  final Value<DateTime> startsAtUtc;
  final Value<int> durationMinutes;
  final Value<String> timezoneId;
  final Value<bool> allDay;
  final Value<String?> recurrenceJson;
  final Value<String> status;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScheduleEventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.startsAtUtc = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.allDay = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleEventsCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    required DateTime startsAtUtc,
    required int durationMinutes,
    required String timezoneId,
    this.allDay = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startsAtUtc = Value(startsAtUtc),
       durationMinutes = Value(durationMinutes),
       timezoneId = Value(timezoneId);
  static Insertable<ScheduleEvent> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? startsAtUtc,
    Expression<int>? durationMinutes,
    Expression<String>? timezoneId,
    Expression<bool>? allDay,
    Expression<String>? recurrenceJson,
    Expression<String>? status,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (startsAtUtc != null) 'starts_at_utc': startsAtUtc,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (allDay != null) 'all_day': allDay,
      if (recurrenceJson != null) 'recurrence_json': recurrenceJson,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? notes,
    Value<DateTime>? startsAtUtc,
    Value<int>? durationMinutes,
    Value<String>? timezoneId,
    Value<bool>? allDay,
    Value<String?>? recurrenceJson,
    Value<String>? status,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScheduleEventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startsAtUtc: startsAtUtc ?? this.startsAtUtc,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timezoneId: timezoneId ?? this.timezoneId,
      allDay: allDay ?? this.allDay,
      recurrenceJson: recurrenceJson ?? this.recurrenceJson,
      status: status ?? this.status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startsAtUtc.present) {
      map['starts_at_utc'] = Variable<DateTime>(startsAtUtc.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (recurrenceJson.present) {
      map['recurrence_json'] = Variable<String>(recurrenceJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleEventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startsAtUtc: $startsAtUtc, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('allDay: $allDay, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleRemindersTable extends ScheduleReminders
    with TableInfo<$ScheduleRemindersTable, ScheduleReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES schedule_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _offsetMinutesMeta = const VerificationMeta(
    'offsetMinutes',
  );
  @override
  late final GeneratedColumn<int> offsetMinutes = GeneratedColumn<int>(
    'offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _exactRequestedMeta = const VerificationMeta(
    'exactRequested',
  );
  @override
  late final GeneratedColumn<bool> exactRequested = GeneratedColumn<bool>(
    'exact_requested',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exact_requested" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    offsetMinutes,
    enabled,
    exactRequested,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('offset_minutes')) {
      context.handle(
        _offsetMinutesMeta,
        offsetMinutes.isAcceptableOrUnknown(
          data['offset_minutes']!,
          _offsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_offsetMinutesMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('exact_requested')) {
      context.handle(
        _exactRequestedMeta,
        exactRequested.isAcceptableOrUnknown(
          data['exact_requested']!,
          _exactRequestedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      offsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_minutes'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      exactRequested: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exact_requested'],
      )!,
    );
  }

  @override
  $ScheduleRemindersTable createAlias(String alias) {
    return $ScheduleRemindersTable(attachedDatabase, alias);
  }
}

class ScheduleReminder extends DataClass
    implements Insertable<ScheduleReminder> {
  final String id;
  final String eventId;
  final int offsetMinutes;
  final bool enabled;
  final bool exactRequested;
  const ScheduleReminder({
    required this.id,
    required this.eventId,
    required this.offsetMinutes,
    required this.enabled,
    required this.exactRequested,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['offset_minutes'] = Variable<int>(offsetMinutes);
    map['enabled'] = Variable<bool>(enabled);
    map['exact_requested'] = Variable<bool>(exactRequested);
    return map;
  }

  ScheduleRemindersCompanion toCompanion(bool nullToAbsent) {
    return ScheduleRemindersCompanion(
      id: Value(id),
      eventId: Value(eventId),
      offsetMinutes: Value(offsetMinutes),
      enabled: Value(enabled),
      exactRequested: Value(exactRequested),
    );
  }

  factory ScheduleReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleReminder(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      offsetMinutes: serializer.fromJson<int>(json['offsetMinutes']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      exactRequested: serializer.fromJson<bool>(json['exactRequested']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'offsetMinutes': serializer.toJson<int>(offsetMinutes),
      'enabled': serializer.toJson<bool>(enabled),
      'exactRequested': serializer.toJson<bool>(exactRequested),
    };
  }

  ScheduleReminder copyWith({
    String? id,
    String? eventId,
    int? offsetMinutes,
    bool? enabled,
    bool? exactRequested,
  }) => ScheduleReminder(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    offsetMinutes: offsetMinutes ?? this.offsetMinutes,
    enabled: enabled ?? this.enabled,
    exactRequested: exactRequested ?? this.exactRequested,
  );
  ScheduleReminder copyWithCompanion(ScheduleRemindersCompanion data) {
    return ScheduleReminder(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      offsetMinutes: data.offsetMinutes.present
          ? data.offsetMinutes.value
          : this.offsetMinutes,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      exactRequested: data.exactRequested.present
          ? data.exactRequested.value
          : this.exactRequested,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleReminder(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('enabled: $enabled, ')
          ..write('exactRequested: $exactRequested')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventId, offsetMinutes, enabled, exactRequested);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleReminder &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.offsetMinutes == this.offsetMinutes &&
          other.enabled == this.enabled &&
          other.exactRequested == this.exactRequested);
}

class ScheduleRemindersCompanion extends UpdateCompanion<ScheduleReminder> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<int> offsetMinutes;
  final Value<bool> enabled;
  final Value<bool> exactRequested;
  final Value<int> rowid;
  const ScheduleRemindersCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.enabled = const Value.absent(),
    this.exactRequested = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleRemindersCompanion.insert({
    required String id,
    required String eventId,
    required int offsetMinutes,
    this.enabled = const Value.absent(),
    this.exactRequested = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       offsetMinutes = Value(offsetMinutes);
  static Insertable<ScheduleReminder> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<int>? offsetMinutes,
    Expression<bool>? enabled,
    Expression<bool>? exactRequested,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (offsetMinutes != null) 'offset_minutes': offsetMinutes,
      if (enabled != null) 'enabled': enabled,
      if (exactRequested != null) 'exact_requested': exactRequested,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleRemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<int>? offsetMinutes,
    Value<bool>? enabled,
    Value<bool>? exactRequested,
    Value<int>? rowid,
  }) {
    return ScheduleRemindersCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      enabled: enabled ?? this.enabled,
      exactRequested: exactRequested ?? this.exactRequested,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (offsetMinutes.present) {
      map['offset_minutes'] = Variable<int>(offsetMinutes.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (exactRequested.present) {
      map['exact_requested'] = Variable<bool>(exactRequested.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleRemindersCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('enabled: $enabled, ')
          ..write('exactRequested: $exactRequested, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationMappingsTable extends NotificationMappings
    with TableInfo<$NotificationMappingsTable, NotificationMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES schedule_reminders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES schedule_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _occurrenceStartsAtUtcMeta =
      const VerificationMeta('occurrenceStartsAtUtc');
  @override
  late final GeneratedColumn<DateTime> occurrenceStartsAtUtc =
      GeneratedColumn<DateTime>(
        'occurrence_starts_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scheduledForUtcMeta = const VerificationMeta(
    'scheduledForUtc',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledForUtc =
      GeneratedColumn<DateTime>(
        'scheduled_for_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _capabilityMeta = const VerificationMeta(
    'capability',
  );
  @override
  late final GeneratedColumn<String> capability = GeneratedColumn<String>(
    'capability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    notificationId,
    reminderId,
    eventId,
    occurrenceStartsAtUtc,
    scheduledForUtc,
    capability,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('occurrence_starts_at_utc')) {
      context.handle(
        _occurrenceStartsAtUtcMeta,
        occurrenceStartsAtUtc.isAcceptableOrUnknown(
          data['occurrence_starts_at_utc']!,
          _occurrenceStartsAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceStartsAtUtcMeta);
    }
    if (data.containsKey('scheduled_for_utc')) {
      context.handle(
        _scheduledForUtcMeta,
        scheduledForUtc.isAcceptableOrUnknown(
          data['scheduled_for_utc']!,
          _scheduledForUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForUtcMeta);
    }
    if (data.containsKey('capability')) {
      context.handle(
        _capabilityMeta,
        capability.isAcceptableOrUnknown(data['capability']!, _capabilityMeta),
      );
    } else if (isInserting) {
      context.missing(_capabilityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {notificationId};
  @override
  NotificationMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationMapping(
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      occurrenceStartsAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurrence_starts_at_utc'],
      )!,
      scheduledForUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_for_utc'],
      )!,
      capability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability'],
      )!,
    );
  }

  @override
  $NotificationMappingsTable createAlias(String alias) {
    return $NotificationMappingsTable(attachedDatabase, alias);
  }
}

class NotificationMapping extends DataClass
    implements Insertable<NotificationMapping> {
  final int notificationId;
  final String reminderId;
  final String eventId;
  final DateTime occurrenceStartsAtUtc;
  final DateTime scheduledForUtc;
  final String capability;
  const NotificationMapping({
    required this.notificationId,
    required this.reminderId,
    required this.eventId,
    required this.occurrenceStartsAtUtc,
    required this.scheduledForUtc,
    required this.capability,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['notification_id'] = Variable<int>(notificationId);
    map['reminder_id'] = Variable<String>(reminderId);
    map['event_id'] = Variable<String>(eventId);
    map['occurrence_starts_at_utc'] = Variable<DateTime>(occurrenceStartsAtUtc);
    map['scheduled_for_utc'] = Variable<DateTime>(scheduledForUtc);
    map['capability'] = Variable<String>(capability);
    return map;
  }

  NotificationMappingsCompanion toCompanion(bool nullToAbsent) {
    return NotificationMappingsCompanion(
      notificationId: Value(notificationId),
      reminderId: Value(reminderId),
      eventId: Value(eventId),
      occurrenceStartsAtUtc: Value(occurrenceStartsAtUtc),
      scheduledForUtc: Value(scheduledForUtc),
      capability: Value(capability),
    );
  }

  factory NotificationMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationMapping(
      notificationId: serializer.fromJson<int>(json['notificationId']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      occurrenceStartsAtUtc: serializer.fromJson<DateTime>(
        json['occurrenceStartsAtUtc'],
      ),
      scheduledForUtc: serializer.fromJson<DateTime>(json['scheduledForUtc']),
      capability: serializer.fromJson<String>(json['capability']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'notificationId': serializer.toJson<int>(notificationId),
      'reminderId': serializer.toJson<String>(reminderId),
      'eventId': serializer.toJson<String>(eventId),
      'occurrenceStartsAtUtc': serializer.toJson<DateTime>(
        occurrenceStartsAtUtc,
      ),
      'scheduledForUtc': serializer.toJson<DateTime>(scheduledForUtc),
      'capability': serializer.toJson<String>(capability),
    };
  }

  NotificationMapping copyWith({
    int? notificationId,
    String? reminderId,
    String? eventId,
    DateTime? occurrenceStartsAtUtc,
    DateTime? scheduledForUtc,
    String? capability,
  }) => NotificationMapping(
    notificationId: notificationId ?? this.notificationId,
    reminderId: reminderId ?? this.reminderId,
    eventId: eventId ?? this.eventId,
    occurrenceStartsAtUtc: occurrenceStartsAtUtc ?? this.occurrenceStartsAtUtc,
    scheduledForUtc: scheduledForUtc ?? this.scheduledForUtc,
    capability: capability ?? this.capability,
  );
  NotificationMapping copyWithCompanion(NotificationMappingsCompanion data) {
    return NotificationMapping(
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      occurrenceStartsAtUtc: data.occurrenceStartsAtUtc.present
          ? data.occurrenceStartsAtUtc.value
          : this.occurrenceStartsAtUtc,
      scheduledForUtc: data.scheduledForUtc.present
          ? data.scheduledForUtc.value
          : this.scheduledForUtc,
      capability: data.capability.present
          ? data.capability.value
          : this.capability,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationMapping(')
          ..write('notificationId: $notificationId, ')
          ..write('reminderId: $reminderId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceStartsAtUtc: $occurrenceStartsAtUtc, ')
          ..write('scheduledForUtc: $scheduledForUtc, ')
          ..write('capability: $capability')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    notificationId,
    reminderId,
    eventId,
    occurrenceStartsAtUtc,
    scheduledForUtc,
    capability,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationMapping &&
          other.notificationId == this.notificationId &&
          other.reminderId == this.reminderId &&
          other.eventId == this.eventId &&
          other.occurrenceStartsAtUtc == this.occurrenceStartsAtUtc &&
          other.scheduledForUtc == this.scheduledForUtc &&
          other.capability == this.capability);
}

class NotificationMappingsCompanion
    extends UpdateCompanion<NotificationMapping> {
  final Value<int> notificationId;
  final Value<String> reminderId;
  final Value<String> eventId;
  final Value<DateTime> occurrenceStartsAtUtc;
  final Value<DateTime> scheduledForUtc;
  final Value<String> capability;
  const NotificationMappingsCompanion({
    this.notificationId = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.occurrenceStartsAtUtc = const Value.absent(),
    this.scheduledForUtc = const Value.absent(),
    this.capability = const Value.absent(),
  });
  NotificationMappingsCompanion.insert({
    this.notificationId = const Value.absent(),
    required String reminderId,
    required String eventId,
    required DateTime occurrenceStartsAtUtc,
    required DateTime scheduledForUtc,
    required String capability,
  }) : reminderId = Value(reminderId),
       eventId = Value(eventId),
       occurrenceStartsAtUtc = Value(occurrenceStartsAtUtc),
       scheduledForUtc = Value(scheduledForUtc),
       capability = Value(capability);
  static Insertable<NotificationMapping> custom({
    Expression<int>? notificationId,
    Expression<String>? reminderId,
    Expression<String>? eventId,
    Expression<DateTime>? occurrenceStartsAtUtc,
    Expression<DateTime>? scheduledForUtc,
    Expression<String>? capability,
  }) {
    return RawValuesInsertable({
      if (notificationId != null) 'notification_id': notificationId,
      if (reminderId != null) 'reminder_id': reminderId,
      if (eventId != null) 'event_id': eventId,
      if (occurrenceStartsAtUtc != null)
        'occurrence_starts_at_utc': occurrenceStartsAtUtc,
      if (scheduledForUtc != null) 'scheduled_for_utc': scheduledForUtc,
      if (capability != null) 'capability': capability,
    });
  }

  NotificationMappingsCompanion copyWith({
    Value<int>? notificationId,
    Value<String>? reminderId,
    Value<String>? eventId,
    Value<DateTime>? occurrenceStartsAtUtc,
    Value<DateTime>? scheduledForUtc,
    Value<String>? capability,
  }) {
    return NotificationMappingsCompanion(
      notificationId: notificationId ?? this.notificationId,
      reminderId: reminderId ?? this.reminderId,
      eventId: eventId ?? this.eventId,
      occurrenceStartsAtUtc:
          occurrenceStartsAtUtc ?? this.occurrenceStartsAtUtc,
      scheduledForUtc: scheduledForUtc ?? this.scheduledForUtc,
      capability: capability ?? this.capability,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (occurrenceStartsAtUtc.present) {
      map['occurrence_starts_at_utc'] = Variable<DateTime>(
        occurrenceStartsAtUtc.value,
      );
    }
    if (scheduledForUtc.present) {
      map['scheduled_for_utc'] = Variable<DateTime>(scheduledForUtc.value);
    }
    if (capability.present) {
      map['capability'] = Variable<String>(capability.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationMappingsCompanion(')
          ..write('notificationId: $notificationId, ')
          ..write('reminderId: $reminderId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceStartsAtUtc: $occurrenceStartsAtUtc, ')
          ..write('scheduledForUtc: $scheduledForUtc, ')
          ..write('capability: $capability')
          ..write(')'))
        .toString();
  }
}

class $AiProviderConfigsTable extends AiProviderConfigs
    with TableInfo<$AiProviderConfigsTable, AiProviderConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiProviderConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textModelMeta = const VerificationMeta(
    'textModel',
  );
  @override
  late final GeneratedColumn<String> textModel = GeneratedColumn<String>(
    'text_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageModelMeta = const VerificationMeta(
    'imageModel',
  );
  @override
  late final GeneratedColumn<String> imageModel = GeneratedColumn<String>(
    'image_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secretRefMeta = const VerificationMeta(
    'secretRef',
  );
  @override
  late final GeneratedColumn<String> secretRef = GeneratedColumn<String>(
    'secret_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    baseUrl,
    textModel,
    imageModel,
    secretRef,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_provider_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiProviderConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('text_model')) {
      context.handle(
        _textModelMeta,
        textModel.isAcceptableOrUnknown(data['text_model']!, _textModelMeta),
      );
    } else if (isInserting) {
      context.missing(_textModelMeta);
    }
    if (data.containsKey('image_model')) {
      context.handle(
        _imageModelMeta,
        imageModel.isAcceptableOrUnknown(data['image_model']!, _imageModelMeta),
      );
    }
    if (data.containsKey('secret_ref')) {
      context.handle(
        _secretRefMeta,
        secretRef.isAcceptableOrUnknown(data['secret_ref']!, _secretRefMeta),
      );
    } else if (isInserting) {
      context.missing(_secretRefMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiProviderConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiProviderConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      textModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_model'],
      )!,
      imageModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_model'],
      ),
      secretRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_ref'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiProviderConfigsTable createAlias(String alias) {
    return $AiProviderConfigsTable(attachedDatabase, alias);
  }
}

class AiProviderConfig extends DataClass
    implements Insertable<AiProviderConfig> {
  final String id;
  final String name;
  final String kind;
  final String baseUrl;
  final String textModel;
  final String? imageModel;
  final String secretRef;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    required this.textModel,
    this.imageModel,
    required this.secretRef,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['base_url'] = Variable<String>(baseUrl);
    map['text_model'] = Variable<String>(textModel);
    if (!nullToAbsent || imageModel != null) {
      map['image_model'] = Variable<String>(imageModel);
    }
    map['secret_ref'] = Variable<String>(secretRef);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiProviderConfigsCompanion toCompanion(bool nullToAbsent) {
    return AiProviderConfigsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      baseUrl: Value(baseUrl),
      textModel: Value(textModel),
      imageModel: imageModel == null && nullToAbsent
          ? const Value.absent()
          : Value(imageModel),
      secretRef: Value(secretRef),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiProviderConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiProviderConfig(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      textModel: serializer.fromJson<String>(json['textModel']),
      imageModel: serializer.fromJson<String?>(json['imageModel']),
      secretRef: serializer.fromJson<String>(json['secretRef']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'textModel': serializer.toJson<String>(textModel),
      'imageModel': serializer.toJson<String?>(imageModel),
      'secretRef': serializer.toJson<String>(secretRef),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiProviderConfig copyWith({
    String? id,
    String? name,
    String? kind,
    String? baseUrl,
    String? textModel,
    Value<String?> imageModel = const Value.absent(),
    String? secretRef,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiProviderConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    baseUrl: baseUrl ?? this.baseUrl,
    textModel: textModel ?? this.textModel,
    imageModel: imageModel.present ? imageModel.value : this.imageModel,
    secretRef: secretRef ?? this.secretRef,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiProviderConfig copyWithCompanion(AiProviderConfigsCompanion data) {
    return AiProviderConfig(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      textModel: data.textModel.present ? data.textModel.value : this.textModel,
      imageModel: data.imageModel.present
          ? data.imageModel.value
          : this.imageModel,
      secretRef: data.secretRef.present ? data.secretRef.value : this.secretRef,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiProviderConfig(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('textModel: $textModel, ')
          ..write('imageModel: $imageModel, ')
          ..write('secretRef: $secretRef, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    baseUrl,
    textModel,
    imageModel,
    secretRef,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiProviderConfig &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.baseUrl == this.baseUrl &&
          other.textModel == this.textModel &&
          other.imageModel == this.imageModel &&
          other.secretRef == this.secretRef &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiProviderConfigsCompanion extends UpdateCompanion<AiProviderConfig> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> baseUrl;
  final Value<String> textModel;
  final Value<String?> imageModel;
  final Value<String> secretRef;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiProviderConfigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.textModel = const Value.absent(),
    this.imageModel = const Value.absent(),
    this.secretRef = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiProviderConfigsCompanion.insert({
    required String id,
    required String name,
    required String kind,
    required String baseUrl,
    required String textModel,
    this.imageModel = const Value.absent(),
    required String secretRef,
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       baseUrl = Value(baseUrl),
       textModel = Value(textModel),
       secretRef = Value(secretRef);
  static Insertable<AiProviderConfig> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? baseUrl,
    Expression<String>? textModel,
    Expression<String>? imageModel,
    Expression<String>? secretRef,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (baseUrl != null) 'base_url': baseUrl,
      if (textModel != null) 'text_model': textModel,
      if (imageModel != null) 'image_model': imageModel,
      if (secretRef != null) 'secret_ref': secretRef,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiProviderConfigsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? baseUrl,
    Value<String>? textModel,
    Value<String?>? imageModel,
    Value<String>? secretRef,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiProviderConfigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      textModel: textModel ?? this.textModel,
      imageModel: imageModel ?? this.imageModel,
      secretRef: secretRef ?? this.secretRef,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (textModel.present) {
      map['text_model'] = Variable<String>(textModel.value);
    }
    if (imageModel.present) {
      map['image_model'] = Variable<String>(imageModel.value);
    }
    if (secretRef.present) {
      map['secret_ref'] = Variable<String>(secretRef.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiProviderConfigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('textModel: $textModel, ')
          ..write('imageModel: $imageModel, ')
          ..write('secretRef: $secretRef, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiConversationsTable extends AiConversations
    with TableInfo<$AiConversationsTable, AiConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ai_provider_configs (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _previousResponseIdMeta =
      const VerificationMeta('previousResponseId');
  @override
  late final GeneratedColumn<String> previousResponseId =
      GeneratedColumn<String>(
        'previous_response_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerId,
    title,
    previousResponseId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('previous_response_id')) {
      context.handle(
        _previousResponseIdMeta,
        previousResponseId.isAcceptableOrUnknown(
          data['previous_response_id']!,
          _previousResponseIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      previousResponseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_response_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiConversationsTable createAlias(String alias) {
    return $AiConversationsTable(attachedDatabase, alias);
  }
}

class AiConversation extends DataClass implements Insertable<AiConversation> {
  final String id;
  final String providerId;
  final String title;
  final String? previousResponseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiConversation({
    required this.id,
    required this.providerId,
    required this.title,
    this.previousResponseId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || previousResponseId != null) {
      map['previous_response_id'] = Variable<String>(previousResponseId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiConversationsCompanion toCompanion(bool nullToAbsent) {
    return AiConversationsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      title: Value(title),
      previousResponseId: previousResponseId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousResponseId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConversation(
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      title: serializer.fromJson<String>(json['title']),
      previousResponseId: serializer.fromJson<String?>(
        json['previousResponseId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'title': serializer.toJson<String>(title),
      'previousResponseId': serializer.toJson<String?>(previousResponseId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiConversation copyWith({
    String? id,
    String? providerId,
    String? title,
    Value<String?> previousResponseId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiConversation(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    title: title ?? this.title,
    previousResponseId: previousResponseId.present
        ? previousResponseId.value
        : this.previousResponseId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiConversation copyWithCompanion(AiConversationsCompanion data) {
    return AiConversation(
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      title: data.title.present ? data.title.value : this.title,
      previousResponseId: data.previousResponseId.present
          ? data.previousResponseId.value
          : this.previousResponseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConversation(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('title: $title, ')
          ..write('previousResponseId: $previousResponseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    title,
    previousResponseId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversation &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.title == this.title &&
          other.previousResponseId == this.previousResponseId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiConversationsCompanion extends UpdateCompanion<AiConversation> {
  final Value<String> id;
  final Value<String> providerId;
  final Value<String> title;
  final Value<String?> previousResponseId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AiConversationsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.title = const Value.absent(),
    this.previousResponseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConversationsCompanion.insert({
    required String id,
    required String providerId,
    this.title = const Value.absent(),
    this.previousResponseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       providerId = Value(providerId);
  static Insertable<AiConversation> custom({
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? title,
    Expression<String>? previousResponseId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (title != null) 'title': title,
      if (previousResponseId != null)
        'previous_response_id': previousResponseId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? providerId,
    Value<String>? title,
    Value<String?>? previousResponseId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiConversationsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      previousResponseId: previousResponseId ?? this.previousResponseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (previousResponseId.present) {
      map['previous_response_id'] = Variable<String>(previousResponseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('title: $title, ')
          ..write('previousResponseId: $previousResponseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiRunsTable extends AiRuns with TableInfo<$AiRunsTable, AiRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ai_conversations (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestDigestMeta = const VerificationMeta(
    'requestDigest',
  );
  @override
  late final GeneratedColumn<String> requestDigest = GeneratedColumn<String>(
    'request_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseIdMeta = const VerificationMeta(
    'responseId',
  );
  @override
  late final GeneratedColumn<String> responseId = GeneratedColumn<String>(
    'response_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    status,
    model,
    requestDigest,
    responseId,
    errorCode,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('request_digest')) {
      context.handle(
        _requestDigestMeta,
        requestDigest.isAcceptableOrUnknown(
          data['request_digest']!,
          _requestDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestDigestMeta);
    }
    if (data.containsKey('response_id')) {
      context.handle(
        _responseIdMeta,
        responseId.isAcceptableOrUnknown(data['response_id']!, _responseIdMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      requestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_digest'],
      )!,
      responseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_id'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $AiRunsTable createAlias(String alias) {
    return $AiRunsTable(attachedDatabase, alias);
  }
}

class AiRun extends DataClass implements Insertable<AiRun> {
  final String id;
  final String conversationId;
  final String status;
  final String model;
  final String requestDigest;
  final String? responseId;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? completedAt;
  const AiRun({
    required this.id,
    required this.conversationId,
    required this.status,
    required this.model,
    required this.requestDigest,
    this.responseId,
    this.errorCode,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['status'] = Variable<String>(status);
    map['model'] = Variable<String>(model);
    map['request_digest'] = Variable<String>(requestDigest);
    if (!nullToAbsent || responseId != null) {
      map['response_id'] = Variable<String>(responseId);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  AiRunsCompanion toCompanion(bool nullToAbsent) {
    return AiRunsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      status: Value(status),
      model: Value(model),
      requestDigest: Value(requestDigest),
      responseId: responseId == null && nullToAbsent
          ? const Value.absent()
          : Value(responseId),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory AiRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiRun(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      status: serializer.fromJson<String>(json['status']),
      model: serializer.fromJson<String>(json['model']),
      requestDigest: serializer.fromJson<String>(json['requestDigest']),
      responseId: serializer.fromJson<String?>(json['responseId']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'status': serializer.toJson<String>(status),
      'model': serializer.toJson<String>(model),
      'requestDigest': serializer.toJson<String>(requestDigest),
      'responseId': serializer.toJson<String?>(responseId),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  AiRun copyWith({
    String? id,
    String? conversationId,
    String? status,
    String? model,
    String? requestDigest,
    Value<String?> responseId = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => AiRun(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    status: status ?? this.status,
    model: model ?? this.model,
    requestDigest: requestDigest ?? this.requestDigest,
    responseId: responseId.present ? responseId.value : this.responseId,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  AiRun copyWithCompanion(AiRunsCompanion data) {
    return AiRun(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      status: data.status.present ? data.status.value : this.status,
      model: data.model.present ? data.model.value : this.model,
      requestDigest: data.requestDigest.present
          ? data.requestDigest.value
          : this.requestDigest,
      responseId: data.responseId.present
          ? data.responseId.value
          : this.responseId,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiRun(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('requestDigest: $requestDigest, ')
          ..write('responseId: $responseId, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    status,
    model,
    requestDigest,
    responseId,
    errorCode,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiRun &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.status == this.status &&
          other.model == this.model &&
          other.requestDigest == this.requestDigest &&
          other.responseId == this.responseId &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class AiRunsCompanion extends UpdateCompanion<AiRun> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> status;
  final Value<String> model;
  final Value<String> requestDigest;
  final Value<String?> responseId;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const AiRunsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.status = const Value.absent(),
    this.model = const Value.absent(),
    this.requestDigest = const Value.absent(),
    this.responseId = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiRunsCompanion.insert({
    required String id,
    required String conversationId,
    required String status,
    required String model,
    required String requestDigest,
    this.responseId = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       status = Value(status),
       model = Value(model),
       requestDigest = Value(requestDigest);
  static Insertable<AiRun> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? status,
    Expression<String>? model,
    Expression<String>? requestDigest,
    Expression<String>? responseId,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (status != null) 'status': status,
      if (model != null) 'model': model,
      if (requestDigest != null) 'request_digest': requestDigest,
      if (responseId != null) 'response_id': responseId,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? status,
    Value<String>? model,
    Value<String>? requestDigest,
    Value<String?>? responseId,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return AiRunsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      status: status ?? this.status,
      model: model ?? this.model,
      requestDigest: requestDigest ?? this.requestDigest,
      responseId: responseId ?? this.responseId,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (requestDigest.present) {
      map['request_digest'] = Variable<String>(requestDigest.value);
    }
    if (responseId.present) {
      map['response_id'] = Variable<String>(responseId.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiRunsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('requestDigest: $requestDigest, ')
          ..write('responseId: $responseId, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiToolCallsTable extends AiToolCalls
    with TableInfo<$AiToolCallsTable, AiToolCall> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiToolCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ai_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _argumentsJsonMeta = const VerificationMeta(
    'argumentsJson',
  );
  @override
  late final GeneratedColumn<String> argumentsJson = GeneratedColumn<String>(
    'arguments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskMeta = const VerificationMeta('risk');
  @override
  late final GeneratedColumn<String> risk = GeneratedColumn<String>(
    'risk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvalStatusMeta = const VerificationMeta(
    'approvalStatus',
  );
  @override
  late final GeneratedColumn<String> approvalStatus = GeneratedColumn<String>(
    'approval_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    name,
    argumentsJson,
    risk,
    approvalStatus,
    resultJson,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_tool_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiToolCall> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('arguments_json')) {
      context.handle(
        _argumentsJsonMeta,
        argumentsJson.isAcceptableOrUnknown(
          data['arguments_json']!,
          _argumentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_argumentsJsonMeta);
    }
    if (data.containsKey('risk')) {
      context.handle(
        _riskMeta,
        risk.isAcceptableOrUnknown(data['risk']!, _riskMeta),
      );
    } else if (isInserting) {
      context.missing(_riskMeta);
    }
    if (data.containsKey('approval_status')) {
      context.handle(
        _approvalStatusMeta,
        approvalStatus.isAcceptableOrUnknown(
          data['approval_status']!,
          _approvalStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_approvalStatusMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiToolCall map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiToolCall(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      argumentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arguments_json'],
      )!,
      risk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk'],
      )!,
      approvalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_status'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $AiToolCallsTable createAlias(String alias) {
    return $AiToolCallsTable(attachedDatabase, alias);
  }
}

class AiToolCall extends DataClass implements Insertable<AiToolCall> {
  final String id;
  final String runId;
  final String name;
  final String argumentsJson;
  final String risk;
  final String approvalStatus;
  final String? resultJson;
  final DateTime createdAt;
  final DateTime? completedAt;
  const AiToolCall({
    required this.id,
    required this.runId,
    required this.name,
    required this.argumentsJson,
    required this.risk,
    required this.approvalStatus,
    this.resultJson,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['name'] = Variable<String>(name);
    map['arguments_json'] = Variable<String>(argumentsJson);
    map['risk'] = Variable<String>(risk);
    map['approval_status'] = Variable<String>(approvalStatus);
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  AiToolCallsCompanion toCompanion(bool nullToAbsent) {
    return AiToolCallsCompanion(
      id: Value(id),
      runId: Value(runId),
      name: Value(name),
      argumentsJson: Value(argumentsJson),
      risk: Value(risk),
      approvalStatus: Value(approvalStatus),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory AiToolCall.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiToolCall(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      name: serializer.fromJson<String>(json['name']),
      argumentsJson: serializer.fromJson<String>(json['argumentsJson']),
      risk: serializer.fromJson<String>(json['risk']),
      approvalStatus: serializer.fromJson<String>(json['approvalStatus']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'name': serializer.toJson<String>(name),
      'argumentsJson': serializer.toJson<String>(argumentsJson),
      'risk': serializer.toJson<String>(risk),
      'approvalStatus': serializer.toJson<String>(approvalStatus),
      'resultJson': serializer.toJson<String?>(resultJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  AiToolCall copyWith({
    String? id,
    String? runId,
    String? name,
    String? argumentsJson,
    String? risk,
    String? approvalStatus,
    Value<String?> resultJson = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => AiToolCall(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    name: name ?? this.name,
    argumentsJson: argumentsJson ?? this.argumentsJson,
    risk: risk ?? this.risk,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  AiToolCall copyWithCompanion(AiToolCallsCompanion data) {
    return AiToolCall(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      name: data.name.present ? data.name.value : this.name,
      argumentsJson: data.argumentsJson.present
          ? data.argumentsJson.value
          : this.argumentsJson,
      risk: data.risk.present ? data.risk.value : this.risk,
      approvalStatus: data.approvalStatus.present
          ? data.approvalStatus.value
          : this.approvalStatus,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiToolCall(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('name: $name, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('risk: $risk, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    name,
    argumentsJson,
    risk,
    approvalStatus,
    resultJson,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiToolCall &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.name == this.name &&
          other.argumentsJson == this.argumentsJson &&
          other.risk == this.risk &&
          other.approvalStatus == this.approvalStatus &&
          other.resultJson == this.resultJson &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class AiToolCallsCompanion extends UpdateCompanion<AiToolCall> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> name;
  final Value<String> argumentsJson;
  final Value<String> risk;
  final Value<String> approvalStatus;
  final Value<String?> resultJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const AiToolCallsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.name = const Value.absent(),
    this.argumentsJson = const Value.absent(),
    this.risk = const Value.absent(),
    this.approvalStatus = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiToolCallsCompanion.insert({
    required String id,
    required String runId,
    required String name,
    required String argumentsJson,
    required String risk,
    required String approvalStatus,
    this.resultJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       name = Value(name),
       argumentsJson = Value(argumentsJson),
       risk = Value(risk),
       approvalStatus = Value(approvalStatus);
  static Insertable<AiToolCall> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? name,
    Expression<String>? argumentsJson,
    Expression<String>? risk,
    Expression<String>? approvalStatus,
    Expression<String>? resultJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (name != null) 'name': name,
      if (argumentsJson != null) 'arguments_json': argumentsJson,
      if (risk != null) 'risk': risk,
      if (approvalStatus != null) 'approval_status': approvalStatus,
      if (resultJson != null) 'result_json': resultJson,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiToolCallsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? name,
    Value<String>? argumentsJson,
    Value<String>? risk,
    Value<String>? approvalStatus,
    Value<String?>? resultJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return AiToolCallsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      name: name ?? this.name,
      argumentsJson: argumentsJson ?? this.argumentsJson,
      risk: risk ?? this.risk,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      resultJson: resultJson ?? this.resultJson,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (argumentsJson.present) {
      map['arguments_json'] = Variable<String>(argumentsJson.value);
    }
    if (risk.present) {
      map['risk'] = Variable<String>(risk.value);
    }
    if (approvalStatus.present) {
      map['approval_status'] = Variable<String>(approvalStatus.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiToolCallsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('name: $name, ')
          ..write('argumentsJson: $argumentsJson, ')
          ..write('risk: $risk, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharePollRefsTable extends SharePollRefs
    with TableInfo<$SharePollRefsTable, SharePollRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharePollRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inviteUrlMeta = const VerificationMeta(
    'inviteUrl',
  );
  @override
  late final GeneratedColumn<String> inviteUrl = GeneratedColumn<String>(
    'invite_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicTokenMeta = const VerificationMeta(
    'publicToken',
  );
  @override
  late final GeneratedColumn<String> publicToken = GeneratedColumn<String>(
    'public_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timezoneIdMeta = const VerificationMeta(
    'timezoneId',
  );
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
    'timezone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UTC'),
  );
  static const VerificationMeta _manageTokenSecretRefMeta =
      const VerificationMeta('manageTokenSecretRef');
  @override
  late final GeneratedColumn<String> manageTokenSecretRef =
      GeneratedColumn<String>(
        'manage_token_secret_ref',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _selectedSlotJsonMeta = const VerificationMeta(
    'selectedSlotJson',
  );
  @override
  late final GeneratedColumn<String> selectedSlotJson = GeneratedColumn<String>(
    'selected_slot_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    inviteUrl,
    publicToken,
    timezoneId,
    manageTokenSecretRef,
    status,
    version,
    selectedSlotJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'share_poll_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharePollRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('invite_url')) {
      context.handle(
        _inviteUrlMeta,
        inviteUrl.isAcceptableOrUnknown(data['invite_url']!, _inviteUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_inviteUrlMeta);
    }
    if (data.containsKey('public_token')) {
      context.handle(
        _publicTokenMeta,
        publicToken.isAcceptableOrUnknown(
          data['public_token']!,
          _publicTokenMeta,
        ),
      );
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    }
    if (data.containsKey('manage_token_secret_ref')) {
      context.handle(
        _manageTokenSecretRefMeta,
        manageTokenSecretRef.isAcceptableOrUnknown(
          data['manage_token_secret_ref']!,
          _manageTokenSecretRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manageTokenSecretRefMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('selected_slot_json')) {
      context.handle(
        _selectedSlotJsonMeta,
        selectedSlotJson.isAcceptableOrUnknown(
          data['selected_slot_json']!,
          _selectedSlotJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SharePollRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharePollRef(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      inviteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invite_url'],
      )!,
      publicToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_token'],
      ),
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      )!,
      manageTokenSecretRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manage_token_secret_ref'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      selectedSlotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_slot_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharePollRefsTable createAlias(String alias) {
    return $SharePollRefsTable(attachedDatabase, alias);
  }
}

class SharePollRef extends DataClass implements Insertable<SharePollRef> {
  final String id;
  final String title;
  final String inviteUrl;
  final String? publicToken;
  final String timezoneId;
  final String manageTokenSecretRef;
  final String status;
  final int version;
  final String? selectedSlotJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SharePollRef({
    required this.id,
    required this.title,
    required this.inviteUrl,
    this.publicToken,
    required this.timezoneId,
    required this.manageTokenSecretRef,
    required this.status,
    required this.version,
    this.selectedSlotJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['invite_url'] = Variable<String>(inviteUrl);
    if (!nullToAbsent || publicToken != null) {
      map['public_token'] = Variable<String>(publicToken);
    }
    map['timezone_id'] = Variable<String>(timezoneId);
    map['manage_token_secret_ref'] = Variable<String>(manageTokenSecretRef);
    map['status'] = Variable<String>(status);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || selectedSlotJson != null) {
      map['selected_slot_json'] = Variable<String>(selectedSlotJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharePollRefsCompanion toCompanion(bool nullToAbsent) {
    return SharePollRefsCompanion(
      id: Value(id),
      title: Value(title),
      inviteUrl: Value(inviteUrl),
      publicToken: publicToken == null && nullToAbsent
          ? const Value.absent()
          : Value(publicToken),
      timezoneId: Value(timezoneId),
      manageTokenSecretRef: Value(manageTokenSecretRef),
      status: Value(status),
      version: Value(version),
      selectedSlotJson: selectedSlotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedSlotJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharePollRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharePollRef(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      inviteUrl: serializer.fromJson<String>(json['inviteUrl']),
      publicToken: serializer.fromJson<String?>(json['publicToken']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      manageTokenSecretRef: serializer.fromJson<String>(
        json['manageTokenSecretRef'],
      ),
      status: serializer.fromJson<String>(json['status']),
      version: serializer.fromJson<int>(json['version']),
      selectedSlotJson: serializer.fromJson<String?>(json['selectedSlotJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'inviteUrl': serializer.toJson<String>(inviteUrl),
      'publicToken': serializer.toJson<String?>(publicToken),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'manageTokenSecretRef': serializer.toJson<String>(manageTokenSecretRef),
      'status': serializer.toJson<String>(status),
      'version': serializer.toJson<int>(version),
      'selectedSlotJson': serializer.toJson<String?>(selectedSlotJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SharePollRef copyWith({
    String? id,
    String? title,
    String? inviteUrl,
    Value<String?> publicToken = const Value.absent(),
    String? timezoneId,
    String? manageTokenSecretRef,
    String? status,
    int? version,
    Value<String?> selectedSlotJson = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SharePollRef(
    id: id ?? this.id,
    title: title ?? this.title,
    inviteUrl: inviteUrl ?? this.inviteUrl,
    publicToken: publicToken.present ? publicToken.value : this.publicToken,
    timezoneId: timezoneId ?? this.timezoneId,
    manageTokenSecretRef: manageTokenSecretRef ?? this.manageTokenSecretRef,
    status: status ?? this.status,
    version: version ?? this.version,
    selectedSlotJson: selectedSlotJson.present
        ? selectedSlotJson.value
        : this.selectedSlotJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharePollRef copyWithCompanion(SharePollRefsCompanion data) {
    return SharePollRef(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      inviteUrl: data.inviteUrl.present ? data.inviteUrl.value : this.inviteUrl,
      publicToken: data.publicToken.present
          ? data.publicToken.value
          : this.publicToken,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      manageTokenSecretRef: data.manageTokenSecretRef.present
          ? data.manageTokenSecretRef.value
          : this.manageTokenSecretRef,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      selectedSlotJson: data.selectedSlotJson.present
          ? data.selectedSlotJson.value
          : this.selectedSlotJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharePollRef(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('inviteUrl: $inviteUrl, ')
          ..write('publicToken: $publicToken, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('manageTokenSecretRef: $manageTokenSecretRef, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('selectedSlotJson: $selectedSlotJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    inviteUrl,
    publicToken,
    timezoneId,
    manageTokenSecretRef,
    status,
    version,
    selectedSlotJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharePollRef &&
          other.id == this.id &&
          other.title == this.title &&
          other.inviteUrl == this.inviteUrl &&
          other.publicToken == this.publicToken &&
          other.timezoneId == this.timezoneId &&
          other.manageTokenSecretRef == this.manageTokenSecretRef &&
          other.status == this.status &&
          other.version == this.version &&
          other.selectedSlotJson == this.selectedSlotJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SharePollRefsCompanion extends UpdateCompanion<SharePollRef> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> inviteUrl;
  final Value<String?> publicToken;
  final Value<String> timezoneId;
  final Value<String> manageTokenSecretRef;
  final Value<String> status;
  final Value<int> version;
  final Value<String?> selectedSlotJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharePollRefsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.inviteUrl = const Value.absent(),
    this.publicToken = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.manageTokenSecretRef = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.selectedSlotJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharePollRefsCompanion.insert({
    required String id,
    required String title,
    required String inviteUrl,
    this.publicToken = const Value.absent(),
    this.timezoneId = const Value.absent(),
    required String manageTokenSecretRef,
    required String status,
    this.version = const Value.absent(),
    this.selectedSlotJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       inviteUrl = Value(inviteUrl),
       manageTokenSecretRef = Value(manageTokenSecretRef),
       status = Value(status);
  static Insertable<SharePollRef> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? inviteUrl,
    Expression<String>? publicToken,
    Expression<String>? timezoneId,
    Expression<String>? manageTokenSecretRef,
    Expression<String>? status,
    Expression<int>? version,
    Expression<String>? selectedSlotJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (inviteUrl != null) 'invite_url': inviteUrl,
      if (publicToken != null) 'public_token': publicToken,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (manageTokenSecretRef != null)
        'manage_token_secret_ref': manageTokenSecretRef,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (selectedSlotJson != null) 'selected_slot_json': selectedSlotJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharePollRefsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? inviteUrl,
    Value<String?>? publicToken,
    Value<String>? timezoneId,
    Value<String>? manageTokenSecretRef,
    Value<String>? status,
    Value<int>? version,
    Value<String?>? selectedSlotJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharePollRefsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      inviteUrl: inviteUrl ?? this.inviteUrl,
      publicToken: publicToken ?? this.publicToken,
      timezoneId: timezoneId ?? this.timezoneId,
      manageTokenSecretRef: manageTokenSecretRef ?? this.manageTokenSecretRef,
      status: status ?? this.status,
      version: version ?? this.version,
      selectedSlotJson: selectedSlotJson ?? this.selectedSlotJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (inviteUrl.present) {
      map['invite_url'] = Variable<String>(inviteUrl.value);
    }
    if (publicToken.present) {
      map['public_token'] = Variable<String>(publicToken.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (manageTokenSecretRef.present) {
      map['manage_token_secret_ref'] = Variable<String>(
        manageTokenSecretRef.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (selectedSlotJson.present) {
      map['selected_slot_json'] = Variable<String>(selectedSlotJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharePollRefsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('inviteUrl: $inviteUrl, ')
          ..write('publicToken: $publicToken, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('manageTokenSecretRef: $manageTokenSecretRef, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('selectedSlotJson: $selectedSlotJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HostsTable hosts = $HostsTable(this);
  late final $HostGroupsTable hostGroups = $HostGroupsTable(this);
  late final $KnownHostKeysTable knownHostKeys = $KnownHostKeysTable(this);
  late final $OperationTagsTable operationTags = $OperationTagsTable(this);
  late final $HostOperationTagsTable hostOperationTags =
      $HostOperationTagsTable(this);
  late final $AgentStatesTable agentStates = $AgentStatesTable(this);
  late final $PortForwardProfilesTable portForwardProfiles =
      $PortForwardProfilesTable(this);
  late final $CommandSnippetsTable commandSnippets = $CommandSnippetsTable(
    this,
  );
  late final $CommandBatchesTable commandBatches = $CommandBatchesTable(this);
  late final $CommandResultsTable commandResults = $CommandResultsTable(this);
  late final $TransferJobsTable transferJobs = $TransferJobsTable(this);
  late final $ScheduleEventsTable scheduleEvents = $ScheduleEventsTable(this);
  late final $ScheduleRemindersTable scheduleReminders =
      $ScheduleRemindersTable(this);
  late final $NotificationMappingsTable notificationMappings =
      $NotificationMappingsTable(this);
  late final $AiProviderConfigsTable aiProviderConfigs =
      $AiProviderConfigsTable(this);
  late final $AiConversationsTable aiConversations = $AiConversationsTable(
    this,
  );
  late final $AiRunsTable aiRuns = $AiRunsTable(this);
  late final $AiToolCallsTable aiToolCalls = $AiToolCallsTable(this);
  late final $SharePollRefsTable sharePollRefs = $SharePollRefsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    hosts,
    hostGroups,
    knownHostKeys,
    operationTags,
    hostOperationTags,
    agentStates,
    portForwardProfiles,
    commandSnippets,
    commandBatches,
    commandResults,
    transferJobs,
    scheduleEvents,
    scheduleReminders,
    notificationMappings,
    aiProviderConfigs,
    aiConversations,
    aiRuns,
    aiToolCalls,
    sharePollRefs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('known_host_keys', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('host_operation_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'operation_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('host_operation_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('agent_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('port_forward_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'command_snippets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('command_batches', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'command_batches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('command_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('command_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hosts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transfer_jobs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'schedule_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'schedule_reminders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notification_mappings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'schedule_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notification_mappings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ai_conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ai_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ai_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ai_tool_calls', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$HostsTableCreateCompanionBuilder =
    HostsCompanion Function({
      required String id,
      required String name,
      required String address,
      Value<int> port,
      required String username,
      Value<String?> groupId,
      Value<String?> credentialRef,
      Value<String> notes,
      Value<bool> favorite,
      Value<String> terminalMode,
      Value<String> agentState,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$HostsTableUpdateCompanionBuilder =
    HostsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> address,
      Value<int> port,
      Value<String> username,
      Value<String?> groupId,
      Value<String?> credentialRef,
      Value<String> notes,
      Value<bool> favorite,
      Value<String> terminalMode,
      Value<String> agentState,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$HostsTableReferences
    extends BaseReferences<_$AppDatabase, $HostsTable, Host> {
  $$HostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$KnownHostKeysTable, List<KnownHostKey>>
  _knownHostKeysRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.knownHostKeys,
    aliasName: 'hosts__id__known_host_keys__host_id',
  );

  $$KnownHostKeysTableProcessedTableManager get knownHostKeysRefs {
    final manager = $$KnownHostKeysTableTableManager(
      $_db,
      $_db.knownHostKeys,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_knownHostKeysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HostOperationTagsTable, List<HostOperationTag>>
  _hostOperationTagsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.hostOperationTags,
        aliasName: 'hosts__id__host_operation_tags__host_id',
      );

  $$HostOperationTagsTableProcessedTableManager get hostOperationTagsRefs {
    final manager = $$HostOperationTagsTableTableManager(
      $_db,
      $_db.hostOperationTags,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _hostOperationTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AgentStatesTable, List<AgentState>>
  _agentStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.agentStates,
    aliasName: 'hosts__id__agent_states__host_id',
  );

  $$AgentStatesTableProcessedTableManager get agentStatesRefs {
    final manager = $$AgentStatesTableTableManager(
      $_db,
      $_db.agentStates,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_agentStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PortForwardProfilesTable,
    List<PortForwardProfile>
  >
  _portForwardProfilesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.portForwardProfiles,
        aliasName: 'hosts__id__port_forward_profiles__host_id',
      );

  $$PortForwardProfilesTableProcessedTableManager get portForwardProfilesRefs {
    final manager = $$PortForwardProfilesTableTableManager(
      $_db,
      $_db.portForwardProfiles,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _portForwardProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CommandResultsTable, List<CommandResult>>
  _commandResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.commandResults,
    aliasName: 'hosts__id__command_results__host_id',
  );

  $$CommandResultsTableProcessedTableManager get commandResultsRefs {
    final manager = $$CommandResultsTableTableManager(
      $_db,
      $_db.commandResults,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_commandResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransferJobsTable, List<TransferJob>>
  _transferJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transferJobs,
    aliasName: 'hosts__id__transfer_jobs__host_id',
  );

  $$TransferJobsTableProcessedTableManager get transferJobsRefs {
    final manager = $$TransferJobsTableTableManager(
      $_db,
      $_db.transferJobs,
    ).filter((f) => f.hostId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transferJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HostsTableFilterComposer extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get terminalMode => $composableBuilder(
    column: $table.terminalMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentState => $composableBuilder(
    column: $table.agentState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> knownHostKeysRefs(
    Expression<bool> Function($$KnownHostKeysTableFilterComposer f) f,
  ) {
    final $$KnownHostKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knownHostKeys,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnownHostKeysTableFilterComposer(
            $db: $db,
            $table: $db.knownHostKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> hostOperationTagsRefs(
    Expression<bool> Function($$HostOperationTagsTableFilterComposer f) f,
  ) {
    final $$HostOperationTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hostOperationTags,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostOperationTagsTableFilterComposer(
            $db: $db,
            $table: $db.hostOperationTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentStatesRefs(
    Expression<bool> Function($$AgentStatesTableFilterComposer f) f,
  ) {
    final $$AgentStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentStates,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentStatesTableFilterComposer(
            $db: $db,
            $table: $db.agentStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> portForwardProfilesRefs(
    Expression<bool> Function($$PortForwardProfilesTableFilterComposer f) f,
  ) {
    final $$PortForwardProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portForwardProfiles,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortForwardProfilesTableFilterComposer(
            $db: $db,
            $table: $db.portForwardProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> commandResultsRefs(
    Expression<bool> Function($$CommandResultsTableFilterComposer f) f,
  ) {
    final $$CommandResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandResults,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandResultsTableFilterComposer(
            $db: $db,
            $table: $db.commandResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transferJobsRefs(
    Expression<bool> Function($$TransferJobsTableFilterComposer f) f,
  ) {
    final $$TransferJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transferJobs,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransferJobsTableFilterComposer(
            $db: $db,
            $table: $db.transferJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HostsTableOrderingComposer
    extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get terminalMode => $composableBuilder(
    column: $table.terminalMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentState => $composableBuilder(
    column: $table.agentState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HostsTable> {
  $$HostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<String> get terminalMode => $composableBuilder(
    column: $table.terminalMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentState => $composableBuilder(
    column: $table.agentState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> knownHostKeysRefs<T extends Object>(
    Expression<T> Function($$KnownHostKeysTableAnnotationComposer a) f,
  ) {
    final $$KnownHostKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knownHostKeys,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnownHostKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.knownHostKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> hostOperationTagsRefs<T extends Object>(
    Expression<T> Function($$HostOperationTagsTableAnnotationComposer a) f,
  ) {
    final $$HostOperationTagsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.hostOperationTags,
          getReferencedColumn: (t) => t.hostId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HostOperationTagsTableAnnotationComposer(
                $db: $db,
                $table: $db.hostOperationTags,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> agentStatesRefs<T extends Object>(
    Expression<T> Function($$AgentStatesTableAnnotationComposer a) f,
  ) {
    final $$AgentStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentStates,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.agentStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> portForwardProfilesRefs<T extends Object>(
    Expression<T> Function($$PortForwardProfilesTableAnnotationComposer a) f,
  ) {
    final $$PortForwardProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.portForwardProfiles,
          getReferencedColumn: (t) => t.hostId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PortForwardProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.portForwardProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> commandResultsRefs<T extends Object>(
    Expression<T> Function($$CommandResultsTableAnnotationComposer a) f,
  ) {
    final $$CommandResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandResults,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.commandResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transferJobsRefs<T extends Object>(
    Expression<T> Function($$TransferJobsTableAnnotationComposer a) f,
  ) {
    final $$TransferJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transferJobs,
      getReferencedColumn: (t) => t.hostId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransferJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.transferJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HostsTable,
          Host,
          $$HostsTableFilterComposer,
          $$HostsTableOrderingComposer,
          $$HostsTableAnnotationComposer,
          $$HostsTableCreateCompanionBuilder,
          $$HostsTableUpdateCompanionBuilder,
          (Host, $$HostsTableReferences),
          Host,
          PrefetchHooks Function({
            bool knownHostKeysRefs,
            bool hostOperationTagsRefs,
            bool agentStatesRefs,
            bool portForwardProfilesRefs,
            bool commandResultsRefs,
            bool transferJobsRefs,
          })
        > {
  $$HostsTableTableManager(_$AppDatabase db, $HostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String> terminalMode = const Value.absent(),
                Value<String> agentState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostsCompanion(
                id: id,
                name: name,
                address: address,
                port: port,
                username: username,
                groupId: groupId,
                credentialRef: credentialRef,
                notes: notes,
                favorite: favorite,
                terminalMode: terminalMode,
                agentState: agentState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String address,
                Value<int> port = const Value.absent(),
                required String username,
                Value<String?> groupId = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String> terminalMode = const Value.absent(),
                Value<String> agentState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostsCompanion.insert(
                id: id,
                name: name,
                address: address,
                port: port,
                username: username,
                groupId: groupId,
                credentialRef: credentialRef,
                notes: notes,
                favorite: favorite,
                terminalMode: terminalMode,
                agentState: agentState,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$HostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                knownHostKeysRefs = false,
                hostOperationTagsRefs = false,
                agentStatesRefs = false,
                portForwardProfilesRefs = false,
                commandResultsRefs = false,
                transferJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (knownHostKeysRefs) db.knownHostKeys,
                    if (hostOperationTagsRefs) db.hostOperationTags,
                    if (agentStatesRefs) db.agentStates,
                    if (portForwardProfilesRefs) db.portForwardProfiles,
                    if (commandResultsRefs) db.commandResults,
                    if (transferJobsRefs) db.transferJobs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (knownHostKeysRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          KnownHostKey
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._knownHostKeysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).knownHostKeysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (hostOperationTagsRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          HostOperationTag
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._hostOperationTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).hostOperationTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (agentStatesRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          AgentState
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._agentStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (portForwardProfilesRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          PortForwardProfile
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._portForwardProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).portForwardProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (commandResultsRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          CommandResult
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._commandResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).commandResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transferJobsRefs)
                        await $_getPrefetchedData<
                          Host,
                          $HostsTable,
                          TransferJob
                        >(
                          currentTable: table,
                          referencedTable: $$HostsTableReferences
                              ._transferJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HostsTableReferences(
                                db,
                                table,
                                p0,
                              ).transferJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.hostId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$HostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HostsTable,
      Host,
      $$HostsTableFilterComposer,
      $$HostsTableOrderingComposer,
      $$HostsTableAnnotationComposer,
      $$HostsTableCreateCompanionBuilder,
      $$HostsTableUpdateCompanionBuilder,
      (Host, $$HostsTableReferences),
      Host,
      PrefetchHooks Function({
        bool knownHostKeysRefs,
        bool hostOperationTagsRefs,
        bool agentStatesRefs,
        bool portForwardProfilesRefs,
        bool commandResultsRefs,
        bool transferJobsRefs,
      })
    >;
typedef $$HostGroupsTableCreateCompanionBuilder =
    HostGroupsCompanion Function({
      required String id,
      required String name,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$HostGroupsTableUpdateCompanionBuilder =
    HostGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$HostGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $HostGroupsTable> {
  $$HostGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HostGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $HostGroupsTable> {
  $$HostGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HostGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HostGroupsTable> {
  $$HostGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HostGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HostGroupsTable,
          HostGroup,
          $$HostGroupsTableFilterComposer,
          $$HostGroupsTableOrderingComposer,
          $$HostGroupsTableAnnotationComposer,
          $$HostGroupsTableCreateCompanionBuilder,
          $$HostGroupsTableUpdateCompanionBuilder,
          (
            HostGroup,
            BaseReferences<_$AppDatabase, $HostGroupsTable, HostGroup>,
          ),
          HostGroup,
          PrefetchHooks Function()
        > {
  $$HostGroupsTableTableManager(_$AppDatabase db, $HostGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostGroupsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostGroupsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HostGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HostGroupsTable,
      HostGroup,
      $$HostGroupsTableFilterComposer,
      $$HostGroupsTableOrderingComposer,
      $$HostGroupsTableAnnotationComposer,
      $$HostGroupsTableCreateCompanionBuilder,
      $$HostGroupsTableUpdateCompanionBuilder,
      (HostGroup, BaseReferences<_$AppDatabase, $HostGroupsTable, HostGroup>),
      HostGroup,
      PrefetchHooks Function()
    >;
typedef $$KnownHostKeysTableCreateCompanionBuilder =
    KnownHostKeysCompanion Function({
      required String hostId,
      required String algorithm,
      required String fingerprintSha256,
      Value<String> status,
      required DateTime acceptedAt,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$KnownHostKeysTableUpdateCompanionBuilder =
    KnownHostKeysCompanion Function({
      Value<String> hostId,
      Value<String> algorithm,
      Value<String> fingerprintSha256,
      Value<String> status,
      Value<DateTime> acceptedAt,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

final class $$KnownHostKeysTableReferences
    extends BaseReferences<_$AppDatabase, $KnownHostKeysTable, KnownHostKey> {
  $$KnownHostKeysTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('known_host_keys__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KnownHostKeysTableFilterComposer
    extends Composer<_$AppDatabase, $KnownHostKeysTable> {
  $$KnownHostKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get algorithm => $composableBuilder(
    column: $table.algorithm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprintSha256 => $composableBuilder(
    column: $table.fingerprintSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnownHostKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $KnownHostKeysTable> {
  $$KnownHostKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get algorithm => $composableBuilder(
    column: $table.algorithm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprintSha256 => $composableBuilder(
    column: $table.fingerprintSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnownHostKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnownHostKeysTable> {
  $$KnownHostKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get algorithm =>
      $composableBuilder(column: $table.algorithm, builder: (column) => column);

  GeneratedColumn<String> get fingerprintSha256 => $composableBuilder(
    column: $table.fingerprintSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnownHostKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KnownHostKeysTable,
          KnownHostKey,
          $$KnownHostKeysTableFilterComposer,
          $$KnownHostKeysTableOrderingComposer,
          $$KnownHostKeysTableAnnotationComposer,
          $$KnownHostKeysTableCreateCompanionBuilder,
          $$KnownHostKeysTableUpdateCompanionBuilder,
          (KnownHostKey, $$KnownHostKeysTableReferences),
          KnownHostKey,
          PrefetchHooks Function({bool hostId})
        > {
  $$KnownHostKeysTableTableManager(_$AppDatabase db, $KnownHostKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownHostKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownHostKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownHostKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hostId = const Value.absent(),
                Value<String> algorithm = const Value.absent(),
                Value<String> fingerprintSha256 = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> acceptedAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnownHostKeysCompanion(
                hostId: hostId,
                algorithm: algorithm,
                fingerprintSha256: fingerprintSha256,
                status: status,
                acceptedAt: acceptedAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hostId,
                required String algorithm,
                required String fingerprintSha256,
                Value<String> status = const Value.absent(),
                required DateTime acceptedAt,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => KnownHostKeysCompanion.insert(
                hostId: hostId,
                algorithm: algorithm,
                fingerprintSha256: fingerprintSha256,
                status: status,
                acceptedAt: acceptedAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KnownHostKeysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable: $$KnownHostKeysTableReferences
                                    ._hostIdTable(db),
                                referencedColumn: $$KnownHostKeysTableReferences
                                    ._hostIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KnownHostKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KnownHostKeysTable,
      KnownHostKey,
      $$KnownHostKeysTableFilterComposer,
      $$KnownHostKeysTableOrderingComposer,
      $$KnownHostKeysTableAnnotationComposer,
      $$KnownHostKeysTableCreateCompanionBuilder,
      $$KnownHostKeysTableUpdateCompanionBuilder,
      (KnownHostKey, $$KnownHostKeysTableReferences),
      KnownHostKey,
      PrefetchHooks Function({bool hostId})
    >;
typedef $$OperationTagsTableCreateCompanionBuilder =
    OperationTagsCompanion Function({
      required String id,
      required String name,
      Value<int?> colorArgb,
      Value<int> rowid,
    });
typedef $$OperationTagsTableUpdateCompanionBuilder =
    OperationTagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> colorArgb,
      Value<int> rowid,
    });

final class $$OperationTagsTableReferences
    extends BaseReferences<_$AppDatabase, $OperationTagsTable, OperationTag> {
  $$OperationTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$HostOperationTagsTable, List<HostOperationTag>>
  _hostOperationTagsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.hostOperationTags,
        aliasName: 'operation_tags__id__host_operation_tags__tag_id',
      );

  $$HostOperationTagsTableProcessedTableManager get hostOperationTagsRefs {
    final manager = $$HostOperationTagsTableTableManager(
      $_db,
      $_db.hostOperationTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _hostOperationTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OperationTagsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationTagsTable> {
  $$OperationTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> hostOperationTagsRefs(
    Expression<bool> Function($$HostOperationTagsTableFilterComposer f) f,
  ) {
    final $$HostOperationTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hostOperationTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostOperationTagsTableFilterComposer(
            $db: $db,
            $table: $db.hostOperationTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OperationTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationTagsTable> {
  $$OperationTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationTagsTable> {
  $$OperationTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  Expression<T> hostOperationTagsRefs<T extends Object>(
    Expression<T> Function($$HostOperationTagsTableAnnotationComposer a) f,
  ) {
    final $$HostOperationTagsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.hostOperationTags,
          getReferencedColumn: (t) => t.tagId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HostOperationTagsTableAnnotationComposer(
                $db: $db,
                $table: $db.hostOperationTags,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$OperationTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationTagsTable,
          OperationTag,
          $$OperationTagsTableFilterComposer,
          $$OperationTagsTableOrderingComposer,
          $$OperationTagsTableAnnotationComposer,
          $$OperationTagsTableCreateCompanionBuilder,
          $$OperationTagsTableUpdateCompanionBuilder,
          (OperationTag, $$OperationTagsTableReferences),
          OperationTag,
          PrefetchHooks Function({bool hostOperationTagsRefs})
        > {
  $$OperationTagsTableTableManager(_$AppDatabase db, $OperationTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> colorArgb = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationTagsCompanion(
                id: id,
                name: name,
                colorArgb: colorArgb,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> colorArgb = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationTagsCompanion.insert(
                id: id,
                name: name,
                colorArgb: colorArgb,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OperationTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostOperationTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (hostOperationTagsRefs) db.hostOperationTags,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (hostOperationTagsRefs)
                    await $_getPrefetchedData<
                      OperationTag,
                      $OperationTagsTable,
                      HostOperationTag
                    >(
                      currentTable: table,
                      referencedTable: $$OperationTagsTableReferences
                          ._hostOperationTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$OperationTagsTableReferences(
                            db,
                            table,
                            p0,
                          ).hostOperationTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$OperationTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationTagsTable,
      OperationTag,
      $$OperationTagsTableFilterComposer,
      $$OperationTagsTableOrderingComposer,
      $$OperationTagsTableAnnotationComposer,
      $$OperationTagsTableCreateCompanionBuilder,
      $$OperationTagsTableUpdateCompanionBuilder,
      (OperationTag, $$OperationTagsTableReferences),
      OperationTag,
      PrefetchHooks Function({bool hostOperationTagsRefs})
    >;
typedef $$HostOperationTagsTableCreateCompanionBuilder =
    HostOperationTagsCompanion Function({
      required String hostId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$HostOperationTagsTableUpdateCompanionBuilder =
    HostOperationTagsCompanion Function({
      Value<String> hostId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$HostOperationTagsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HostOperationTagsTable,
          HostOperationTag
        > {
  $$HostOperationTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('host_operation_tags__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $OperationTagsTable _tagIdTable(_$AppDatabase db) => db.operationTags
      .createAlias('host_operation_tags__tag_id__operation_tags__id');

  $$OperationTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$OperationTagsTableTableManager(
      $_db,
      $_db.operationTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HostOperationTagsTableFilterComposer
    extends Composer<_$AppDatabase, $HostOperationTagsTable> {
  $$HostOperationTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OperationTagsTableFilterComposer get tagId {
    final $$OperationTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.operationTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationTagsTableFilterComposer(
            $db: $db,
            $table: $db.operationTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostOperationTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $HostOperationTagsTable> {
  $$HostOperationTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OperationTagsTableOrderingComposer get tagId {
    final $$OperationTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.operationTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationTagsTableOrderingComposer(
            $db: $db,
            $table: $db.operationTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostOperationTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HostOperationTagsTable> {
  $$HostOperationTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OperationTagsTableAnnotationComposer get tagId {
    final $$OperationTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.operationTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.operationTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HostOperationTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HostOperationTagsTable,
          HostOperationTag,
          $$HostOperationTagsTableFilterComposer,
          $$HostOperationTagsTableOrderingComposer,
          $$HostOperationTagsTableAnnotationComposer,
          $$HostOperationTagsTableCreateCompanionBuilder,
          $$HostOperationTagsTableUpdateCompanionBuilder,
          (HostOperationTag, $$HostOperationTagsTableReferences),
          HostOperationTag,
          PrefetchHooks Function({bool hostId, bool tagId})
        > {
  $$HostOperationTagsTableTableManager(
    _$AppDatabase db,
    $HostOperationTagsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HostOperationTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HostOperationTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HostOperationTagsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> hostId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HostOperationTagsCompanion(
                hostId: hostId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hostId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => HostOperationTagsCompanion.insert(
                hostId: hostId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HostOperationTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable:
                                    $$HostOperationTagsTableReferences
                                        ._hostIdTable(db),
                                referencedColumn:
                                    $$HostOperationTagsTableReferences
                                        ._hostIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable:
                                    $$HostOperationTagsTableReferences
                                        ._tagIdTable(db),
                                referencedColumn:
                                    $$HostOperationTagsTableReferences
                                        ._tagIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HostOperationTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HostOperationTagsTable,
      HostOperationTag,
      $$HostOperationTagsTableFilterComposer,
      $$HostOperationTagsTableOrderingComposer,
      $$HostOperationTagsTableAnnotationComposer,
      $$HostOperationTagsTableCreateCompanionBuilder,
      $$HostOperationTagsTableUpdateCompanionBuilder,
      (HostOperationTag, $$HostOperationTagsTableReferences),
      HostOperationTag,
      PrefetchHooks Function({bool hostId, bool tagId})
    >;
typedef $$AgentStatesTableCreateCompanionBuilder =
    AgentStatesCompanion Function({
      required String hostId,
      required int protocolVersion,
      required String agentVersion,
      required String architecture,
      required String capabilitiesJson,
      required String transport,
      required String health,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$AgentStatesTableUpdateCompanionBuilder =
    AgentStatesCompanion Function({
      Value<String> hostId,
      Value<int> protocolVersion,
      Value<String> agentVersion,
      Value<String> architecture,
      Value<String> capabilitiesJson,
      Value<String> transport,
      Value<String> health,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

final class $$AgentStatesTableReferences
    extends BaseReferences<_$AppDatabase, $AgentStatesTable, AgentState> {
  $$AgentStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('agent_states__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AgentStatesTableFilterComposer
    extends Composer<_$AppDatabase, $AgentStatesTable> {
  $$AgentStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentVersion => $composableBuilder(
    column: $table.agentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get architecture => $composableBuilder(
    column: $table.architecture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get health => $composableBuilder(
    column: $table.health,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentStatesTable> {
  $$AgentStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentVersion => $composableBuilder(
    column: $table.agentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get architecture => $composableBuilder(
    column: $table.architecture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get health => $composableBuilder(
    column: $table.health,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentStatesTable> {
  $$AgentStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentVersion => $composableBuilder(
    column: $table.agentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get architecture => $composableBuilder(
    column: $table.architecture,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<String> get health =>
      $composableBuilder(column: $table.health, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentStatesTable,
          AgentState,
          $$AgentStatesTableFilterComposer,
          $$AgentStatesTableOrderingComposer,
          $$AgentStatesTableAnnotationComposer,
          $$AgentStatesTableCreateCompanionBuilder,
          $$AgentStatesTableUpdateCompanionBuilder,
          (AgentState, $$AgentStatesTableReferences),
          AgentState,
          PrefetchHooks Function({bool hostId})
        > {
  $$AgentStatesTableTableManager(_$AppDatabase db, $AgentStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hostId = const Value.absent(),
                Value<int> protocolVersion = const Value.absent(),
                Value<String> agentVersion = const Value.absent(),
                Value<String> architecture = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<String> health = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentStatesCompanion(
                hostId: hostId,
                protocolVersion: protocolVersion,
                agentVersion: agentVersion,
                architecture: architecture,
                capabilitiesJson: capabilitiesJson,
                transport: transport,
                health: health,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hostId,
                required int protocolVersion,
                required String agentVersion,
                required String architecture,
                required String capabilitiesJson,
                required String transport,
                required String health,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentStatesCompanion.insert(
                hostId: hostId,
                protocolVersion: protocolVersion,
                agentVersion: agentVersion,
                architecture: architecture,
                capabilitiesJson: capabilitiesJson,
                transport: transport,
                health: health,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable: $$AgentStatesTableReferences
                                    ._hostIdTable(db),
                                referencedColumn: $$AgentStatesTableReferences
                                    ._hostIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AgentStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentStatesTable,
      AgentState,
      $$AgentStatesTableFilterComposer,
      $$AgentStatesTableOrderingComposer,
      $$AgentStatesTableAnnotationComposer,
      $$AgentStatesTableCreateCompanionBuilder,
      $$AgentStatesTableUpdateCompanionBuilder,
      (AgentState, $$AgentStatesTableReferences),
      AgentState,
      PrefetchHooks Function({bool hostId})
    >;
typedef $$PortForwardProfilesTableCreateCompanionBuilder =
    PortForwardProfilesCompanion Function({
      required String id,
      required String hostId,
      required String name,
      Value<String> bindAddress,
      required int localPort,
      required String targetHost,
      required int targetPort,
      Value<bool> autoStart,
      Value<String> state,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PortForwardProfilesTableUpdateCompanionBuilder =
    PortForwardProfilesCompanion Function({
      Value<String> id,
      Value<String> hostId,
      Value<String> name,
      Value<String> bindAddress,
      Value<int> localPort,
      Value<String> targetHost,
      Value<int> targetPort,
      Value<bool> autoStart,
      Value<String> state,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PortForwardProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PortForwardProfilesTable,
          PortForwardProfile
        > {
  $$PortForwardProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('port_forward_profiles__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PortForwardProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $PortForwardProfilesTable> {
  $$PortForwardProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bindAddress => $composableBuilder(
    column: $table.bindAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localPort => $composableBuilder(
    column: $table.localPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoStart => $composableBuilder(
    column: $table.autoStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortForwardProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $PortForwardProfilesTable> {
  $$PortForwardProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bindAddress => $composableBuilder(
    column: $table.bindAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localPort => $composableBuilder(
    column: $table.localPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoStart => $composableBuilder(
    column: $table.autoStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortForwardProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortForwardProfilesTable> {
  $$PortForwardProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bindAddress => $composableBuilder(
    column: $table.bindAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localPort =>
      $composableBuilder(column: $table.localPort, builder: (column) => column);

  GeneratedColumn<String> get targetHost => $composableBuilder(
    column: $table.targetHost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetPort => $composableBuilder(
    column: $table.targetPort,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoStart =>
      $composableBuilder(column: $table.autoStart, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PortForwardProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortForwardProfilesTable,
          PortForwardProfile,
          $$PortForwardProfilesTableFilterComposer,
          $$PortForwardProfilesTableOrderingComposer,
          $$PortForwardProfilesTableAnnotationComposer,
          $$PortForwardProfilesTableCreateCompanionBuilder,
          $$PortForwardProfilesTableUpdateCompanionBuilder,
          (PortForwardProfile, $$PortForwardProfilesTableReferences),
          PortForwardProfile,
          PrefetchHooks Function({bool hostId})
        > {
  $$PortForwardProfilesTableTableManager(
    _$AppDatabase db,
    $PortForwardProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortForwardProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortForwardProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PortForwardProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hostId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> bindAddress = const Value.absent(),
                Value<int> localPort = const Value.absent(),
                Value<String> targetHost = const Value.absent(),
                Value<int> targetPort = const Value.absent(),
                Value<bool> autoStart = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PortForwardProfilesCompanion(
                id: id,
                hostId: hostId,
                name: name,
                bindAddress: bindAddress,
                localPort: localPort,
                targetHost: targetHost,
                targetPort: targetPort,
                autoStart: autoStart,
                state: state,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String hostId,
                required String name,
                Value<String> bindAddress = const Value.absent(),
                required int localPort,
                required String targetHost,
                required int targetPort,
                Value<bool> autoStart = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PortForwardProfilesCompanion.insert(
                id: id,
                hostId: hostId,
                name: name,
                bindAddress: bindAddress,
                localPort: localPort,
                targetHost: targetHost,
                targetPort: targetPort,
                autoStart: autoStart,
                state: state,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortForwardProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable:
                                    $$PortForwardProfilesTableReferences
                                        ._hostIdTable(db),
                                referencedColumn:
                                    $$PortForwardProfilesTableReferences
                                        ._hostIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PortForwardProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortForwardProfilesTable,
      PortForwardProfile,
      $$PortForwardProfilesTableFilterComposer,
      $$PortForwardProfilesTableOrderingComposer,
      $$PortForwardProfilesTableAnnotationComposer,
      $$PortForwardProfilesTableCreateCompanionBuilder,
      $$PortForwardProfilesTableUpdateCompanionBuilder,
      (PortForwardProfile, $$PortForwardProfilesTableReferences),
      PortForwardProfile,
      PrefetchHooks Function({bool hostId})
    >;
typedef $$CommandSnippetsTableCreateCompanionBuilder =
    CommandSnippetsCompanion Function({
      required String id,
      required String name,
      required String command,
      Value<String> tagsJson,
      Value<int> timeoutSeconds,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CommandSnippetsTableUpdateCompanionBuilder =
    CommandSnippetsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> command,
      Value<String> tagsJson,
      Value<int> timeoutSeconds,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CommandSnippetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CommandSnippetsTable, CommandSnippet> {
  $$CommandSnippetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CommandBatchesTable, List<CommandBatche>>
  _commandBatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.commandBatches,
    aliasName: 'command_snippets__id__command_batches__snippet_id',
  );

  $$CommandBatchesTableProcessedTableManager get commandBatchesRefs {
    final manager = $$CommandBatchesTableTableManager(
      $_db,
      $_db.commandBatches,
    ).filter((f) => f.snippetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_commandBatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CommandSnippetsTableFilterComposer
    extends Composer<_$AppDatabase, $CommandSnippetsTable> {
  $$CommandSnippetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> commandBatchesRefs(
    Expression<bool> Function($$CommandBatchesTableFilterComposer f) f,
  ) {
    final $$CommandBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandBatches,
      getReferencedColumn: (t) => t.snippetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandBatchesTableFilterComposer(
            $db: $db,
            $table: $db.commandBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommandSnippetsTableOrderingComposer
    extends Composer<_$AppDatabase, $CommandSnippetsTable> {
  $$CommandSnippetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CommandSnippetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommandSnippetsTable> {
  $$CommandSnippetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> commandBatchesRefs<T extends Object>(
    Expression<T> Function($$CommandBatchesTableAnnotationComposer a) f,
  ) {
    final $$CommandBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandBatches,
      getReferencedColumn: (t) => t.snippetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.commandBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommandSnippetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CommandSnippetsTable,
          CommandSnippet,
          $$CommandSnippetsTableFilterComposer,
          $$CommandSnippetsTableOrderingComposer,
          $$CommandSnippetsTableAnnotationComposer,
          $$CommandSnippetsTableCreateCompanionBuilder,
          $$CommandSnippetsTableUpdateCompanionBuilder,
          (CommandSnippet, $$CommandSnippetsTableReferences),
          CommandSnippet,
          PrefetchHooks Function({bool commandBatchesRefs})
        > {
  $$CommandSnippetsTableTableManager(
    _$AppDatabase db,
    $CommandSnippetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommandSnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommandSnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommandSnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandSnippetsCompanion(
                id: id,
                name: name,
                command: command,
                tagsJson: tagsJson,
                timeoutSeconds: timeoutSeconds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String command,
                Value<String> tagsJson = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandSnippetsCompanion.insert(
                id: id,
                name: name,
                command: command,
                tagsJson: tagsJson,
                timeoutSeconds: timeoutSeconds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CommandSnippetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({commandBatchesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (commandBatchesRefs) db.commandBatches,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (commandBatchesRefs)
                    await $_getPrefetchedData<
                      CommandSnippet,
                      $CommandSnippetsTable,
                      CommandBatche
                    >(
                      currentTable: table,
                      referencedTable: $$CommandSnippetsTableReferences
                          ._commandBatchesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CommandSnippetsTableReferences(
                            db,
                            table,
                            p0,
                          ).commandBatchesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.snippetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CommandSnippetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CommandSnippetsTable,
      CommandSnippet,
      $$CommandSnippetsTableFilterComposer,
      $$CommandSnippetsTableOrderingComposer,
      $$CommandSnippetsTableAnnotationComposer,
      $$CommandSnippetsTableCreateCompanionBuilder,
      $$CommandSnippetsTableUpdateCompanionBuilder,
      (CommandSnippet, $$CommandSnippetsTableReferences),
      CommandSnippet,
      PrefetchHooks Function({bool commandBatchesRefs})
    >;
typedef $$CommandBatchesTableCreateCompanionBuilder =
    CommandBatchesCompanion Function({
      required String id,
      Value<String?> snippetId,
      required String commandSnapshot,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });
typedef $$CommandBatchesTableUpdateCompanionBuilder =
    CommandBatchesCompanion Function({
      Value<String> id,
      Value<String?> snippetId,
      Value<String> commandSnapshot,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });

final class $$CommandBatchesTableReferences
    extends BaseReferences<_$AppDatabase, $CommandBatchesTable, CommandBatche> {
  $$CommandBatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CommandSnippetsTable _snippetIdTable(_$AppDatabase db) => db
      .commandSnippets
      .createAlias('command_batches__snippet_id__command_snippets__id');

  $$CommandSnippetsTableProcessedTableManager? get snippetId {
    final $_column = $_itemColumn<String>('snippet_id');
    if ($_column == null) return null;
    final manager = $$CommandSnippetsTableTableManager(
      $_db,
      $_db.commandSnippets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snippetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CommandResultsTable, List<CommandResult>>
  _commandResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.commandResults,
    aliasName: 'command_batches__id__command_results__batch_id',
  );

  $$CommandResultsTableProcessedTableManager get commandResultsRefs {
    final manager = $$CommandResultsTableTableManager(
      $_db,
      $_db.commandResults,
    ).filter((f) => f.batchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_commandResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CommandBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $CommandBatchesTable> {
  $$CommandBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandSnapshot => $composableBuilder(
    column: $table.commandSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CommandSnippetsTableFilterComposer get snippetId {
    final $$CommandSnippetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.commandSnippets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandSnippetsTableFilterComposer(
            $db: $db,
            $table: $db.commandSnippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> commandResultsRefs(
    Expression<bool> Function($$CommandResultsTableFilterComposer f) f,
  ) {
    final $$CommandResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandResults,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandResultsTableFilterComposer(
            $db: $db,
            $table: $db.commandResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommandBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $CommandBatchesTable> {
  $$CommandBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandSnapshot => $composableBuilder(
    column: $table.commandSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CommandSnippetsTableOrderingComposer get snippetId {
    final $$CommandSnippetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.commandSnippets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandSnippetsTableOrderingComposer(
            $db: $db,
            $table: $db.commandSnippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommandBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommandBatchesTable> {
  $$CommandBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandSnapshot => $composableBuilder(
    column: $table.commandSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  $$CommandSnippetsTableAnnotationComposer get snippetId {
    final $$CommandSnippetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.commandSnippets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandSnippetsTableAnnotationComposer(
            $db: $db,
            $table: $db.commandSnippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> commandResultsRefs<T extends Object>(
    Expression<T> Function($$CommandResultsTableAnnotationComposer a) f,
  ) {
    final $$CommandResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commandResults,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.commandResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommandBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CommandBatchesTable,
          CommandBatche,
          $$CommandBatchesTableFilterComposer,
          $$CommandBatchesTableOrderingComposer,
          $$CommandBatchesTableAnnotationComposer,
          $$CommandBatchesTableCreateCompanionBuilder,
          $$CommandBatchesTableUpdateCompanionBuilder,
          (CommandBatche, $$CommandBatchesTableReferences),
          CommandBatche,
          PrefetchHooks Function({bool snippetId, bool commandResultsRefs})
        > {
  $$CommandBatchesTableTableManager(
    _$AppDatabase db,
    $CommandBatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommandBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommandBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommandBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> snippetId = const Value.absent(),
                Value<String> commandSnapshot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandBatchesCompanion(
                id: id,
                snippetId: snippetId,
                commandSnapshot: commandSnapshot,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> snippetId = const Value.absent(),
                required String commandSnapshot,
                required String status,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandBatchesCompanion.insert(
                id: id,
                snippetId: snippetId,
                commandSnapshot: commandSnapshot,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CommandBatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({snippetId = false, commandResultsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (commandResultsRefs) db.commandResults,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (snippetId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.snippetId,
                                    referencedTable:
                                        $$CommandBatchesTableReferences
                                            ._snippetIdTable(db),
                                    referencedColumn:
                                        $$CommandBatchesTableReferences
                                            ._snippetIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (commandResultsRefs)
                        await $_getPrefetchedData<
                          CommandBatche,
                          $CommandBatchesTable,
                          CommandResult
                        >(
                          currentTable: table,
                          referencedTable: $$CommandBatchesTableReferences
                              ._commandResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CommandBatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).commandResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.batchId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CommandBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CommandBatchesTable,
      CommandBatche,
      $$CommandBatchesTableFilterComposer,
      $$CommandBatchesTableOrderingComposer,
      $$CommandBatchesTableAnnotationComposer,
      $$CommandBatchesTableCreateCompanionBuilder,
      $$CommandBatchesTableUpdateCompanionBuilder,
      (CommandBatche, $$CommandBatchesTableReferences),
      CommandBatche,
      PrefetchHooks Function({bool snippetId, bool commandResultsRefs})
    >;
typedef $$CommandResultsTableCreateCompanionBuilder =
    CommandResultsCompanion Function({
      required String id,
      required String batchId,
      required String hostId,
      required String status,
      Value<int?> exitCode,
      Value<String> stdoutPreview,
      Value<String> stderrPreview,
      Value<String?> artifactRef,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$CommandResultsTableUpdateCompanionBuilder =
    CommandResultsCompanion Function({
      Value<String> id,
      Value<String> batchId,
      Value<String> hostId,
      Value<String> status,
      Value<int?> exitCode,
      Value<String> stdoutPreview,
      Value<String> stderrPreview,
      Value<String?> artifactRef,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$CommandResultsTableReferences
    extends BaseReferences<_$AppDatabase, $CommandResultsTable, CommandResult> {
  $$CommandResultsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CommandBatchesTable _batchIdTable(_$AppDatabase db) => db
      .commandBatches
      .createAlias('command_results__batch_id__command_batches__id');

  $$CommandBatchesTableProcessedTableManager get batchId {
    final $_column = $_itemColumn<String>('batch_id')!;

    final manager = $$CommandBatchesTableTableManager(
      $_db,
      $_db.commandBatches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('command_results__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CommandResultsTableFilterComposer
    extends Composer<_$AppDatabase, $CommandResultsTable> {
  $$CommandResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stdoutPreview => $composableBuilder(
    column: $table.stdoutPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stderrPreview => $composableBuilder(
    column: $table.stderrPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifactRef => $composableBuilder(
    column: $table.artifactRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CommandBatchesTableFilterComposer get batchId {
    final $$CommandBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.commandBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandBatchesTableFilterComposer(
            $db: $db,
            $table: $db.commandBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommandResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $CommandResultsTable> {
  $$CommandResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stdoutPreview => $composableBuilder(
    column: $table.stdoutPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stderrPreview => $composableBuilder(
    column: $table.stderrPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifactRef => $composableBuilder(
    column: $table.artifactRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CommandBatchesTableOrderingComposer get batchId {
    final $$CommandBatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.commandBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandBatchesTableOrderingComposer(
            $db: $db,
            $table: $db.commandBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommandResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommandResultsTable> {
  $$CommandResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<String> get stdoutPreview => $composableBuilder(
    column: $table.stdoutPreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stderrPreview => $composableBuilder(
    column: $table.stderrPreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artifactRef => $composableBuilder(
    column: $table.artifactRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$CommandBatchesTableAnnotationComposer get batchId {
    final $$CommandBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.commandBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommandBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.commandBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommandResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CommandResultsTable,
          CommandResult,
          $$CommandResultsTableFilterComposer,
          $$CommandResultsTableOrderingComposer,
          $$CommandResultsTableAnnotationComposer,
          $$CommandResultsTableCreateCompanionBuilder,
          $$CommandResultsTableUpdateCompanionBuilder,
          (CommandResult, $$CommandResultsTableReferences),
          CommandResult,
          PrefetchHooks Function({bool batchId, bool hostId})
        > {
  $$CommandResultsTableTableManager(
    _$AppDatabase db,
    $CommandResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommandResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommandResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommandResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> batchId = const Value.absent(),
                Value<String> hostId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String> stdoutPreview = const Value.absent(),
                Value<String> stderrPreview = const Value.absent(),
                Value<String?> artifactRef = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandResultsCompanion(
                id: id,
                batchId: batchId,
                hostId: hostId,
                status: status,
                exitCode: exitCode,
                stdoutPreview: stdoutPreview,
                stderrPreview: stderrPreview,
                artifactRef: artifactRef,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String batchId,
                required String hostId,
                required String status,
                Value<int?> exitCode = const Value.absent(),
                Value<String> stdoutPreview = const Value.absent(),
                Value<String> stderrPreview = const Value.absent(),
                Value<String?> artifactRef = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommandResultsCompanion.insert(
                id: id,
                batchId: batchId,
                hostId: hostId,
                status: status,
                exitCode: exitCode,
                stdoutPreview: stdoutPreview,
                stderrPreview: stderrPreview,
                artifactRef: artifactRef,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CommandResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batchId = false, hostId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.batchId,
                                referencedTable: $$CommandResultsTableReferences
                                    ._batchIdTable(db),
                                referencedColumn:
                                    $$CommandResultsTableReferences
                                        ._batchIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable: $$CommandResultsTableReferences
                                    ._hostIdTable(db),
                                referencedColumn:
                                    $$CommandResultsTableReferences
                                        ._hostIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CommandResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CommandResultsTable,
      CommandResult,
      $$CommandResultsTableFilterComposer,
      $$CommandResultsTableOrderingComposer,
      $$CommandResultsTableAnnotationComposer,
      $$CommandResultsTableCreateCompanionBuilder,
      $$CommandResultsTableUpdateCompanionBuilder,
      (CommandResult, $$CommandResultsTableReferences),
      CommandResult,
      PrefetchHooks Function({bool batchId, bool hostId})
    >;
typedef $$TransferJobsTableCreateCompanionBuilder =
    TransferJobsCompanion Function({
      required String id,
      required String hostId,
      required String direction,
      required String localPath,
      required String remotePath,
      required int totalBytes,
      Value<int> confirmedOffset,
      Value<String?> expectedSha256,
      Value<String?> remoteIdentityJson,
      Value<String> state,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TransferJobsTableUpdateCompanionBuilder =
    TransferJobsCompanion Function({
      Value<String> id,
      Value<String> hostId,
      Value<String> direction,
      Value<String> localPath,
      Value<String> remotePath,
      Value<int> totalBytes,
      Value<int> confirmedOffset,
      Value<String?> expectedSha256,
      Value<String?> remoteIdentityJson,
      Value<String> state,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TransferJobsTableReferences
    extends BaseReferences<_$AppDatabase, $TransferJobsTable, TransferJob> {
  $$TransferJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HostsTable _hostIdTable(_$AppDatabase db) =>
      db.hosts.createAlias('transfer_jobs__host_id__hosts__id');

  $$HostsTableProcessedTableManager get hostId {
    final $_column = $_itemColumn<String>('host_id')!;

    final manager = $$HostsTableTableManager(
      $_db,
      $_db.hosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_hostIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransferJobsTableFilterComposer
    extends Composer<_$AppDatabase, $TransferJobsTable> {
  $$TransferJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmedOffset => $composableBuilder(
    column: $table.confirmedOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedSha256 => $composableBuilder(
    column: $table.expectedSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteIdentityJson => $composableBuilder(
    column: $table.remoteIdentityJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HostsTableFilterComposer get hostId {
    final $$HostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableFilterComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransferJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransferJobsTable> {
  $$TransferJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedOffset => $composableBuilder(
    column: $table.confirmedOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedSha256 => $composableBuilder(
    column: $table.expectedSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteIdentityJson => $composableBuilder(
    column: $table.remoteIdentityJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HostsTableOrderingComposer get hostId {
    final $$HostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableOrderingComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransferJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransferJobsTable> {
  $$TransferJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confirmedOffset => $composableBuilder(
    column: $table.confirmedOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expectedSha256 => $composableBuilder(
    column: $table.expectedSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteIdentityJson => $composableBuilder(
    column: $table.remoteIdentityJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$HostsTableAnnotationComposer get hostId {
    final $$HostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.hostId,
      referencedTable: $db.hosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HostsTableAnnotationComposer(
            $db: $db,
            $table: $db.hosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransferJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransferJobsTable,
          TransferJob,
          $$TransferJobsTableFilterComposer,
          $$TransferJobsTableOrderingComposer,
          $$TransferJobsTableAnnotationComposer,
          $$TransferJobsTableCreateCompanionBuilder,
          $$TransferJobsTableUpdateCompanionBuilder,
          (TransferJob, $$TransferJobsTableReferences),
          TransferJob,
          PrefetchHooks Function({bool hostId})
        > {
  $$TransferJobsTableTableManager(_$AppDatabase db, $TransferJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransferJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransferJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransferJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hostId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> remotePath = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> confirmedOffset = const Value.absent(),
                Value<String?> expectedSha256 = const Value.absent(),
                Value<String?> remoteIdentityJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransferJobsCompanion(
                id: id,
                hostId: hostId,
                direction: direction,
                localPath: localPath,
                remotePath: remotePath,
                totalBytes: totalBytes,
                confirmedOffset: confirmedOffset,
                expectedSha256: expectedSha256,
                remoteIdentityJson: remoteIdentityJson,
                state: state,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String hostId,
                required String direction,
                required String localPath,
                required String remotePath,
                required int totalBytes,
                Value<int> confirmedOffset = const Value.absent(),
                Value<String?> expectedSha256 = const Value.absent(),
                Value<String?> remoteIdentityJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransferJobsCompanion.insert(
                id: id,
                hostId: hostId,
                direction: direction,
                localPath: localPath,
                remotePath: remotePath,
                totalBytes: totalBytes,
                confirmedOffset: confirmedOffset,
                expectedSha256: expectedSha256,
                remoteIdentityJson: remoteIdentityJson,
                state: state,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransferJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({hostId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (hostId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.hostId,
                                referencedTable: $$TransferJobsTableReferences
                                    ._hostIdTable(db),
                                referencedColumn: $$TransferJobsTableReferences
                                    ._hostIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransferJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransferJobsTable,
      TransferJob,
      $$TransferJobsTableFilterComposer,
      $$TransferJobsTableOrderingComposer,
      $$TransferJobsTableAnnotationComposer,
      $$TransferJobsTableCreateCompanionBuilder,
      $$TransferJobsTableUpdateCompanionBuilder,
      (TransferJob, $$TransferJobsTableReferences),
      TransferJob,
      PrefetchHooks Function({bool hostId})
    >;
typedef $$ScheduleEventsTableCreateCompanionBuilder =
    ScheduleEventsCompanion Function({
      required String id,
      required String title,
      Value<String> notes,
      required DateTime startsAtUtc,
      required int durationMinutes,
      required String timezoneId,
      Value<bool> allDay,
      Value<String?> recurrenceJson,
      Value<String> status,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ScheduleEventsTableUpdateCompanionBuilder =
    ScheduleEventsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> notes,
      Value<DateTime> startsAtUtc,
      Value<int> durationMinutes,
      Value<String> timezoneId,
      Value<bool> allDay,
      Value<String?> recurrenceJson,
      Value<String> status,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ScheduleEventsTableReferences
    extends BaseReferences<_$AppDatabase, $ScheduleEventsTable, ScheduleEvent> {
  $$ScheduleEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ScheduleRemindersTable, List<ScheduleReminder>>
  _scheduleRemindersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduleReminders,
        aliasName: 'schedule_events__id__schedule_reminders__event_id',
      );

  $$ScheduleRemindersTableProcessedTableManager get scheduleRemindersRefs {
    final manager = $$ScheduleRemindersTableTableManager(
      $_db,
      $_db.scheduleReminders,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduleRemindersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $NotificationMappingsTable,
    List<NotificationMapping>
  >
  _notificationMappingsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.notificationMappings,
        aliasName: 'schedule_events__id__notification_mappings__event_id',
      );

  $$NotificationMappingsTableProcessedTableManager
  get notificationMappingsRefs {
    final manager = $$NotificationMappingsTableTableManager(
      $_db,
      $_db.notificationMappings,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _notificationMappingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduleEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsAtUtc => $composableBuilder(
    column: $table.startsAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scheduleRemindersRefs(
    Expression<bool> Function($$ScheduleRemindersTableFilterComposer f) f,
  ) {
    final $$ScheduleRemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleReminders,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRemindersTableFilterComposer(
            $db: $db,
            $table: $db.scheduleReminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notificationMappingsRefs(
    Expression<bool> Function($$NotificationMappingsTableFilterComposer f) f,
  ) {
    final $$NotificationMappingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notificationMappings,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotificationMappingsTableFilterComposer(
            $db: $db,
            $table: $db.notificationMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduleEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsAtUtc => $composableBuilder(
    column: $table.startsAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAtUtc => $composableBuilder(
    column: $table.startsAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> scheduleRemindersRefs<T extends Object>(
    Expression<T> Function($$ScheduleRemindersTableAnnotationComposer a) f,
  ) {
    final $$ScheduleRemindersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduleReminders,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduleRemindersTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduleReminders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> notificationMappingsRefs<T extends Object>(
    Expression<T> Function($$NotificationMappingsTableAnnotationComposer a) f,
  ) {
    final $$NotificationMappingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.notificationMappings,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NotificationMappingsTableAnnotationComposer(
                $db: $db,
                $table: $db.notificationMappings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduleEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleEventsTable,
          ScheduleEvent,
          $$ScheduleEventsTableFilterComposer,
          $$ScheduleEventsTableOrderingComposer,
          $$ScheduleEventsTableAnnotationComposer,
          $$ScheduleEventsTableCreateCompanionBuilder,
          $$ScheduleEventsTableUpdateCompanionBuilder,
          (ScheduleEvent, $$ScheduleEventsTableReferences),
          ScheduleEvent,
          PrefetchHooks Function({
            bool scheduleRemindersRefs,
            bool notificationMappingsRefs,
          })
        > {
  $$ScheduleEventsTableTableManager(
    _$AppDatabase db,
    $ScheduleEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> startsAtUtc = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleEventsCompanion(
                id: id,
                title: title,
                notes: notes,
                startsAtUtc: startsAtUtc,
                durationMinutes: durationMinutes,
                timezoneId: timezoneId,
                allDay: allDay,
                recurrenceJson: recurrenceJson,
                status: status,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> notes = const Value.absent(),
                required DateTime startsAtUtc,
                required int durationMinutes,
                required String timezoneId,
                Value<bool> allDay = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleEventsCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                startsAtUtc: startsAtUtc,
                durationMinutes: durationMinutes,
                timezoneId: timezoneId,
                allDay: allDay,
                recurrenceJson: recurrenceJson,
                status: status,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScheduleEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                scheduleRemindersRefs = false,
                notificationMappingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (scheduleRemindersRefs) db.scheduleReminders,
                    if (notificationMappingsRefs) db.notificationMappings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (scheduleRemindersRefs)
                        await $_getPrefetchedData<
                          ScheduleEvent,
                          $ScheduleEventsTable,
                          ScheduleReminder
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduleEventsTableReferences
                              ._scheduleRemindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduleEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduleRemindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notificationMappingsRefs)
                        await $_getPrefetchedData<
                          ScheduleEvent,
                          $ScheduleEventsTable,
                          NotificationMapping
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduleEventsTableReferences
                              ._notificationMappingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduleEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).notificationMappingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScheduleEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleEventsTable,
      ScheduleEvent,
      $$ScheduleEventsTableFilterComposer,
      $$ScheduleEventsTableOrderingComposer,
      $$ScheduleEventsTableAnnotationComposer,
      $$ScheduleEventsTableCreateCompanionBuilder,
      $$ScheduleEventsTableUpdateCompanionBuilder,
      (ScheduleEvent, $$ScheduleEventsTableReferences),
      ScheduleEvent,
      PrefetchHooks Function({
        bool scheduleRemindersRefs,
        bool notificationMappingsRefs,
      })
    >;
typedef $$ScheduleRemindersTableCreateCompanionBuilder =
    ScheduleRemindersCompanion Function({
      required String id,
      required String eventId,
      required int offsetMinutes,
      Value<bool> enabled,
      Value<bool> exactRequested,
      Value<int> rowid,
    });
typedef $$ScheduleRemindersTableUpdateCompanionBuilder =
    ScheduleRemindersCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<int> offsetMinutes,
      Value<bool> enabled,
      Value<bool> exactRequested,
      Value<int> rowid,
    });

final class $$ScheduleRemindersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduleRemindersTable,
          ScheduleReminder
        > {
  $$ScheduleRemindersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ScheduleEventsTable _eventIdTable(_$AppDatabase db) => db
      .scheduleEvents
      .createAlias('schedule_reminders__event_id__schedule_events__id');

  $$ScheduleEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$ScheduleEventsTableTableManager(
      $_db,
      $_db.scheduleEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $NotificationMappingsTable,
    List<NotificationMapping>
  >
  _notificationMappingsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.notificationMappings,
        aliasName: 'schedule_reminders__id__notification_mappings__reminder_id',
      );

  $$NotificationMappingsTableProcessedTableManager
  get notificationMappingsRefs {
    final manager = $$NotificationMappingsTableTableManager(
      $_db,
      $_db.notificationMappings,
    ).filter((f) => f.reminderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _notificationMappingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduleRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleRemindersTable> {
  $$ScheduleRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exactRequested => $composableBuilder(
    column: $table.exactRequested,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduleEventsTableFilterComposer get eventId {
    final $$ScheduleEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> notificationMappingsRefs(
    Expression<bool> Function($$NotificationMappingsTableFilterComposer f) f,
  ) {
    final $$NotificationMappingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notificationMappings,
      getReferencedColumn: (t) => t.reminderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotificationMappingsTableFilterComposer(
            $db: $db,
            $table: $db.notificationMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduleRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleRemindersTable> {
  $$ScheduleRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exactRequested => $composableBuilder(
    column: $table.exactRequested,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduleEventsTableOrderingComposer get eventId {
    final $$ScheduleEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableOrderingComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleRemindersTable> {
  $$ScheduleRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get exactRequested => $composableBuilder(
    column: $table.exactRequested,
    builder: (column) => column,
  );

  $$ScheduleEventsTableAnnotationComposer get eventId {
    final $$ScheduleEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> notificationMappingsRefs<T extends Object>(
    Expression<T> Function($$NotificationMappingsTableAnnotationComposer a) f,
  ) {
    final $$NotificationMappingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.notificationMappings,
          getReferencedColumn: (t) => t.reminderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NotificationMappingsTableAnnotationComposer(
                $db: $db,
                $table: $db.notificationMappings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduleRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleRemindersTable,
          ScheduleReminder,
          $$ScheduleRemindersTableFilterComposer,
          $$ScheduleRemindersTableOrderingComposer,
          $$ScheduleRemindersTableAnnotationComposer,
          $$ScheduleRemindersTableCreateCompanionBuilder,
          $$ScheduleRemindersTableUpdateCompanionBuilder,
          (ScheduleReminder, $$ScheduleRemindersTableReferences),
          ScheduleReminder,
          PrefetchHooks Function({bool eventId, bool notificationMappingsRefs})
        > {
  $$ScheduleRemindersTableTableManager(
    _$AppDatabase db,
    $ScheduleRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleRemindersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<int> offsetMinutes = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> exactRequested = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleRemindersCompanion(
                id: id,
                eventId: eventId,
                offsetMinutes: offsetMinutes,
                enabled: enabled,
                exactRequested: exactRequested,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required int offsetMinutes,
                Value<bool> enabled = const Value.absent(),
                Value<bool> exactRequested = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleRemindersCompanion.insert(
                id: id,
                eventId: eventId,
                offsetMinutes: offsetMinutes,
                enabled: enabled,
                exactRequested: exactRequested,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScheduleRemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({eventId = false, notificationMappingsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notificationMappingsRefs) db.notificationMappings,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (eventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.eventId,
                                    referencedTable:
                                        $$ScheduleRemindersTableReferences
                                            ._eventIdTable(db),
                                    referencedColumn:
                                        $$ScheduleRemindersTableReferences
                                            ._eventIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notificationMappingsRefs)
                        await $_getPrefetchedData<
                          ScheduleReminder,
                          $ScheduleRemindersTable,
                          NotificationMapping
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduleRemindersTableReferences
                              ._notificationMappingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduleRemindersTableReferences(
                                db,
                                table,
                                p0,
                              ).notificationMappingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.reminderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScheduleRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleRemindersTable,
      ScheduleReminder,
      $$ScheduleRemindersTableFilterComposer,
      $$ScheduleRemindersTableOrderingComposer,
      $$ScheduleRemindersTableAnnotationComposer,
      $$ScheduleRemindersTableCreateCompanionBuilder,
      $$ScheduleRemindersTableUpdateCompanionBuilder,
      (ScheduleReminder, $$ScheduleRemindersTableReferences),
      ScheduleReminder,
      PrefetchHooks Function({bool eventId, bool notificationMappingsRefs})
    >;
typedef $$NotificationMappingsTableCreateCompanionBuilder =
    NotificationMappingsCompanion Function({
      Value<int> notificationId,
      required String reminderId,
      required String eventId,
      required DateTime occurrenceStartsAtUtc,
      required DateTime scheduledForUtc,
      required String capability,
    });
typedef $$NotificationMappingsTableUpdateCompanionBuilder =
    NotificationMappingsCompanion Function({
      Value<int> notificationId,
      Value<String> reminderId,
      Value<String> eventId,
      Value<DateTime> occurrenceStartsAtUtc,
      Value<DateTime> scheduledForUtc,
      Value<String> capability,
    });

final class $$NotificationMappingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NotificationMappingsTable,
          NotificationMapping
        > {
  $$NotificationMappingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ScheduleRemindersTable _reminderIdTable(_$AppDatabase db) =>
      db.scheduleReminders.createAlias(
        'notification_mappings__reminder_id__schedule_reminders__id',
      );

  $$ScheduleRemindersTableProcessedTableManager get reminderId {
    final $_column = $_itemColumn<String>('reminder_id')!;

    final manager = $$ScheduleRemindersTableTableManager(
      $_db,
      $_db.scheduleReminders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reminderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ScheduleEventsTable _eventIdTable(_$AppDatabase db) => db
      .scheduleEvents
      .createAlias('notification_mappings__event_id__schedule_events__id');

  $$ScheduleEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$ScheduleEventsTableTableManager(
      $_db,
      $_db.scheduleEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotificationMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationMappingsTable> {
  $$NotificationMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurrenceStartsAtUtc => $composableBuilder(
    column: $table.occurrenceStartsAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledForUtc => $composableBuilder(
    column: $table.scheduledForUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduleRemindersTableFilterComposer get reminderId {
    final $$ScheduleRemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.scheduleReminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRemindersTableFilterComposer(
            $db: $db,
            $table: $db.scheduleReminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScheduleEventsTableFilterComposer get eventId {
    final $$ScheduleEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationMappingsTable> {
  $$NotificationMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurrenceStartsAtUtc => $composableBuilder(
    column: $table.occurrenceStartsAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledForUtc => $composableBuilder(
    column: $table.scheduledForUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduleRemindersTableOrderingComposer get reminderId {
    final $$ScheduleRemindersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.scheduleReminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleRemindersTableOrderingComposer(
            $db: $db,
            $table: $db.scheduleReminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScheduleEventsTableOrderingComposer get eventId {
    final $$ScheduleEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableOrderingComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationMappingsTable> {
  $$NotificationMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurrenceStartsAtUtc => $composableBuilder(
    column: $table.occurrenceStartsAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledForUtc => $composableBuilder(
    column: $table.scheduledForUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => column,
  );

  $$ScheduleRemindersTableAnnotationComposer get reminderId {
    final $$ScheduleRemindersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.reminderId,
          referencedTable: $db.scheduleReminders,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduleRemindersTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduleReminders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ScheduleEventsTableAnnotationComposer get eventId {
    final $$ScheduleEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.scheduleEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationMappingsTable,
          NotificationMapping,
          $$NotificationMappingsTableFilterComposer,
          $$NotificationMappingsTableOrderingComposer,
          $$NotificationMappingsTableAnnotationComposer,
          $$NotificationMappingsTableCreateCompanionBuilder,
          $$NotificationMappingsTableUpdateCompanionBuilder,
          (NotificationMapping, $$NotificationMappingsTableReferences),
          NotificationMapping,
          PrefetchHooks Function({bool reminderId, bool eventId})
        > {
  $$NotificationMappingsTableTableManager(
    _$AppDatabase db,
    $NotificationMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> notificationId = const Value.absent(),
                Value<String> reminderId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<DateTime> occurrenceStartsAtUtc = const Value.absent(),
                Value<DateTime> scheduledForUtc = const Value.absent(),
                Value<String> capability = const Value.absent(),
              }) => NotificationMappingsCompanion(
                notificationId: notificationId,
                reminderId: reminderId,
                eventId: eventId,
                occurrenceStartsAtUtc: occurrenceStartsAtUtc,
                scheduledForUtc: scheduledForUtc,
                capability: capability,
              ),
          createCompanionCallback:
              ({
                Value<int> notificationId = const Value.absent(),
                required String reminderId,
                required String eventId,
                required DateTime occurrenceStartsAtUtc,
                required DateTime scheduledForUtc,
                required String capability,
              }) => NotificationMappingsCompanion.insert(
                notificationId: notificationId,
                reminderId: reminderId,
                eventId: eventId,
                occurrenceStartsAtUtc: occurrenceStartsAtUtc,
                scheduledForUtc: scheduledForUtc,
                capability: capability,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NotificationMappingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reminderId = false, eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (reminderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.reminderId,
                                referencedTable:
                                    $$NotificationMappingsTableReferences
                                        ._reminderIdTable(db),
                                referencedColumn:
                                    $$NotificationMappingsTableReferences
                                        ._reminderIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable:
                                    $$NotificationMappingsTableReferences
                                        ._eventIdTable(db),
                                referencedColumn:
                                    $$NotificationMappingsTableReferences
                                        ._eventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotificationMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationMappingsTable,
      NotificationMapping,
      $$NotificationMappingsTableFilterComposer,
      $$NotificationMappingsTableOrderingComposer,
      $$NotificationMappingsTableAnnotationComposer,
      $$NotificationMappingsTableCreateCompanionBuilder,
      $$NotificationMappingsTableUpdateCompanionBuilder,
      (NotificationMapping, $$NotificationMappingsTableReferences),
      NotificationMapping,
      PrefetchHooks Function({bool reminderId, bool eventId})
    >;
typedef $$AiProviderConfigsTableCreateCompanionBuilder =
    AiProviderConfigsCompanion Function({
      required String id,
      required String name,
      required String kind,
      required String baseUrl,
      required String textModel,
      Value<String?> imageModel,
      required String secretRef,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AiProviderConfigsTableUpdateCompanionBuilder =
    AiProviderConfigsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> kind,
      Value<String> baseUrl,
      Value<String> textModel,
      Value<String?> imageModel,
      Value<String> secretRef,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$AiProviderConfigsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AiProviderConfigsTable,
          AiProviderConfig
        > {
  $$AiProviderConfigsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$AiConversationsTable, List<AiConversation>>
  _aiConversationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiConversations,
    aliasName: 'ai_provider_configs__id__ai_conversations__provider_id',
  );

  $$AiConversationsTableProcessedTableManager get aiConversationsRefs {
    final manager = $$AiConversationsTableTableManager(
      $_db,
      $_db.aiConversations,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _aiConversationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AiProviderConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $AiProviderConfigsTable> {
  $$AiProviderConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textModel => $composableBuilder(
    column: $table.textModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageModel => $composableBuilder(
    column: $table.imageModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> aiConversationsRefs(
    Expression<bool> Function($$AiConversationsTableFilterComposer f) f,
  ) {
    final $$AiConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiConversations,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiConversationsTableFilterComposer(
            $db: $db,
            $table: $db.aiConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiProviderConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiProviderConfigsTable> {
  $$AiProviderConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textModel => $composableBuilder(
    column: $table.textModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageModel => $composableBuilder(
    column: $table.imageModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiProviderConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiProviderConfigsTable> {
  $$AiProviderConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get textModel =>
      $composableBuilder(column: $table.textModel, builder: (column) => column);

  GeneratedColumn<String> get imageModel => $composableBuilder(
    column: $table.imageModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> aiConversationsRefs<T extends Object>(
    Expression<T> Function($$AiConversationsTableAnnotationComposer a) f,
  ) {
    final $$AiConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiConversations,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiProviderConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiProviderConfigsTable,
          AiProviderConfig,
          $$AiProviderConfigsTableFilterComposer,
          $$AiProviderConfigsTableOrderingComposer,
          $$AiProviderConfigsTableAnnotationComposer,
          $$AiProviderConfigsTableCreateCompanionBuilder,
          $$AiProviderConfigsTableUpdateCompanionBuilder,
          (AiProviderConfig, $$AiProviderConfigsTableReferences),
          AiProviderConfig,
          PrefetchHooks Function({bool aiConversationsRefs})
        > {
  $$AiProviderConfigsTableTableManager(
    _$AppDatabase db,
    $AiProviderConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiProviderConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiProviderConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiProviderConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> textModel = const Value.absent(),
                Value<String?> imageModel = const Value.absent(),
                Value<String> secretRef = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProviderConfigsCompanion(
                id: id,
                name: name,
                kind: kind,
                baseUrl: baseUrl,
                textModel: textModel,
                imageModel: imageModel,
                secretRef: secretRef,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                required String baseUrl,
                required String textModel,
                Value<String?> imageModel = const Value.absent(),
                required String secretRef,
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiProviderConfigsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                baseUrl: baseUrl,
                textModel: textModel,
                imageModel: imageModel,
                secretRef: secretRef,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AiProviderConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({aiConversationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (aiConversationsRefs) db.aiConversations,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (aiConversationsRefs)
                    await $_getPrefetchedData<
                      AiProviderConfig,
                      $AiProviderConfigsTable,
                      AiConversation
                    >(
                      currentTable: table,
                      referencedTable: $$AiProviderConfigsTableReferences
                          ._aiConversationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AiProviderConfigsTableReferences(
                            db,
                            table,
                            p0,
                          ).aiConversationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.providerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AiProviderConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiProviderConfigsTable,
      AiProviderConfig,
      $$AiProviderConfigsTableFilterComposer,
      $$AiProviderConfigsTableOrderingComposer,
      $$AiProviderConfigsTableAnnotationComposer,
      $$AiProviderConfigsTableCreateCompanionBuilder,
      $$AiProviderConfigsTableUpdateCompanionBuilder,
      (AiProviderConfig, $$AiProviderConfigsTableReferences),
      AiProviderConfig,
      PrefetchHooks Function({bool aiConversationsRefs})
    >;
typedef $$AiConversationsTableCreateCompanionBuilder =
    AiConversationsCompanion Function({
      required String id,
      required String providerId,
      Value<String> title,
      Value<String?> previousResponseId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AiConversationsTableUpdateCompanionBuilder =
    AiConversationsCompanion Function({
      Value<String> id,
      Value<String> providerId,
      Value<String> title,
      Value<String?> previousResponseId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$AiConversationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AiConversationsTable, AiConversation> {
  $$AiConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AiProviderConfigsTable _providerIdTable(_$AppDatabase db) => db
      .aiProviderConfigs
      .createAlias('ai_conversations__provider_id__ai_provider_configs__id');

  $$AiProviderConfigsTableProcessedTableManager get providerId {
    final $_column = $_itemColumn<String>('provider_id')!;

    final manager = $$AiProviderConfigsTableTableManager(
      $_db,
      $_db.aiProviderConfigs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AiRunsTable, List<AiRun>> _aiRunsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.aiRuns,
    aliasName: 'ai_conversations__id__ai_runs__conversation_id',
  );

  $$AiRunsTableProcessedTableManager get aiRunsRefs {
    final manager = $$AiRunsTableTableManager(
      $_db,
      $_db.aiRuns,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AiConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousResponseId => $composableBuilder(
    column: $table.previousResponseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AiProviderConfigsTableFilterComposer get providerId {
    final $$AiProviderConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.aiProviderConfigs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiProviderConfigsTableFilterComposer(
            $db: $db,
            $table: $db.aiProviderConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> aiRunsRefs(
    Expression<bool> Function($$AiRunsTableFilterComposer f) f,
  ) {
    final $$AiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiRuns,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiRunsTableFilterComposer(
            $db: $db,
            $table: $db.aiRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousResponseId => $composableBuilder(
    column: $table.previousResponseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AiProviderConfigsTableOrderingComposer get providerId {
    final $$AiProviderConfigsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.aiProviderConfigs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiProviderConfigsTableOrderingComposer(
            $db: $db,
            $table: $db.aiProviderConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get previousResponseId => $composableBuilder(
    column: $table.previousResponseId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AiProviderConfigsTableAnnotationComposer get providerId {
    final $$AiProviderConfigsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.providerId,
          referencedTable: $db.aiProviderConfigs,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AiProviderConfigsTableAnnotationComposer(
                $db: $db,
                $table: $db.aiProviderConfigs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> aiRunsRefs<T extends Object>(
    Expression<T> Function($$AiRunsTableAnnotationComposer a) f,
  ) {
    final $$AiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiRuns,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiConversationsTable,
          AiConversation,
          $$AiConversationsTableFilterComposer,
          $$AiConversationsTableOrderingComposer,
          $$AiConversationsTableAnnotationComposer,
          $$AiConversationsTableCreateCompanionBuilder,
          $$AiConversationsTableUpdateCompanionBuilder,
          (AiConversation, $$AiConversationsTableReferences),
          AiConversation,
          PrefetchHooks Function({bool providerId, bool aiRunsRefs})
        > {
  $$AiConversationsTableTableManager(
    _$AppDatabase db,
    $AiConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> previousResponseId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConversationsCompanion(
                id: id,
                providerId: providerId,
                title: title,
                previousResponseId: previousResponseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String providerId,
                Value<String> title = const Value.absent(),
                Value<String?> previousResponseId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiConversationsCompanion.insert(
                id: id,
                providerId: providerId,
                title: title,
                previousResponseId: previousResponseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AiConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerId = false, aiRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (aiRunsRefs) db.aiRuns],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (providerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.providerId,
                                referencedTable:
                                    $$AiConversationsTableReferences
                                        ._providerIdTable(db),
                                referencedColumn:
                                    $$AiConversationsTableReferences
                                        ._providerIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (aiRunsRefs)
                    await $_getPrefetchedData<
                      AiConversation,
                      $AiConversationsTable,
                      AiRun
                    >(
                      currentTable: table,
                      referencedTable: $$AiConversationsTableReferences
                          ._aiRunsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AiConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).aiRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AiConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiConversationsTable,
      AiConversation,
      $$AiConversationsTableFilterComposer,
      $$AiConversationsTableOrderingComposer,
      $$AiConversationsTableAnnotationComposer,
      $$AiConversationsTableCreateCompanionBuilder,
      $$AiConversationsTableUpdateCompanionBuilder,
      (AiConversation, $$AiConversationsTableReferences),
      AiConversation,
      PrefetchHooks Function({bool providerId, bool aiRunsRefs})
    >;
typedef $$AiRunsTableCreateCompanionBuilder =
    AiRunsCompanion Function({
      required String id,
      required String conversationId,
      required String status,
      required String model,
      required String requestDigest,
      Value<String?> responseId,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$AiRunsTableUpdateCompanionBuilder =
    AiRunsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> status,
      Value<String> model,
      Value<String> requestDigest,
      Value<String?> responseId,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$AiRunsTableReferences
    extends BaseReferences<_$AppDatabase, $AiRunsTable, AiRun> {
  $$AiRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AiConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .aiConversations
      .createAlias('ai_runs__conversation_id__ai_conversations__id');

  $$AiConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$AiConversationsTableTableManager(
      $_db,
      $_db.aiConversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AiToolCallsTable, List<AiToolCall>>
  _aiToolCallsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiToolCalls,
    aliasName: 'ai_runs__id__ai_tool_calls__run_id',
  );

  $$AiToolCallsTableProcessedTableManager get aiToolCallsRefs {
    final manager = $$AiToolCallsTableTableManager(
      $_db,
      $_db.aiToolCalls,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiToolCallsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AiRunsTableFilterComposer
    extends Composer<_$AppDatabase, $AiRunsTable> {
  $$AiRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AiConversationsTableFilterComposer get conversationId {
    final $$AiConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.aiConversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiConversationsTableFilterComposer(
            $db: $db,
            $table: $db.aiConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> aiToolCallsRefs(
    Expression<bool> Function($$AiToolCallsTableFilterComposer f) f,
  ) {
    final $$AiToolCallsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiToolCalls,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiToolCallsTableFilterComposer(
            $db: $db,
            $table: $db.aiToolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiRunsTable> {
  $$AiRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AiConversationsTableOrderingComposer get conversationId {
    final $$AiConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.aiConversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.aiConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiRunsTable> {
  $$AiRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get requestDigest => $composableBuilder(
    column: $table.requestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$AiConversationsTableAnnotationComposer get conversationId {
    final $$AiConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.aiConversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> aiToolCallsRefs<T extends Object>(
    Expression<T> Function($$AiToolCallsTableAnnotationComposer a) f,
  ) {
    final $$AiToolCallsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiToolCalls,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiToolCallsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiToolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AiRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiRunsTable,
          AiRun,
          $$AiRunsTableFilterComposer,
          $$AiRunsTableOrderingComposer,
          $$AiRunsTableAnnotationComposer,
          $$AiRunsTableCreateCompanionBuilder,
          $$AiRunsTableUpdateCompanionBuilder,
          (AiRun, $$AiRunsTableReferences),
          AiRun,
          PrefetchHooks Function({bool conversationId, bool aiToolCallsRefs})
        > {
  $$AiRunsTableTableManager(_$AppDatabase db, $AiRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> requestDigest = const Value.absent(),
                Value<String?> responseId = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiRunsCompanion(
                id: id,
                conversationId: conversationId,
                status: status,
                model: model,
                requestDigest: requestDigest,
                responseId: responseId,
                errorCode: errorCode,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String status,
                required String model,
                required String requestDigest,
                Value<String?> responseId = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiRunsCompanion.insert(
                id: id,
                conversationId: conversationId,
                status: status,
                model: model,
                requestDigest: requestDigest,
                responseId: responseId,
                errorCode: errorCode,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$AiRunsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationId = false, aiToolCallsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (aiToolCallsRefs) db.aiToolCalls,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (conversationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.conversationId,
                                    referencedTable: $$AiRunsTableReferences
                                        ._conversationIdTable(db),
                                    referencedColumn: $$AiRunsTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (aiToolCallsRefs)
                        await $_getPrefetchedData<
                          AiRun,
                          $AiRunsTable,
                          AiToolCall
                        >(
                          currentTable: table,
                          referencedTable: $$AiRunsTableReferences
                              ._aiToolCallsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AiRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).aiToolCallsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AiRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiRunsTable,
      AiRun,
      $$AiRunsTableFilterComposer,
      $$AiRunsTableOrderingComposer,
      $$AiRunsTableAnnotationComposer,
      $$AiRunsTableCreateCompanionBuilder,
      $$AiRunsTableUpdateCompanionBuilder,
      (AiRun, $$AiRunsTableReferences),
      AiRun,
      PrefetchHooks Function({bool conversationId, bool aiToolCallsRefs})
    >;
typedef $$AiToolCallsTableCreateCompanionBuilder =
    AiToolCallsCompanion Function({
      required String id,
      required String runId,
      required String name,
      required String argumentsJson,
      required String risk,
      required String approvalStatus,
      Value<String?> resultJson,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$AiToolCallsTableUpdateCompanionBuilder =
    AiToolCallsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> name,
      Value<String> argumentsJson,
      Value<String> risk,
      Value<String> approvalStatus,
      Value<String?> resultJson,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$AiToolCallsTableReferences
    extends BaseReferences<_$AppDatabase, $AiToolCallsTable, AiToolCall> {
  $$AiToolCallsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AiRunsTable _runIdTable(_$AppDatabase db) =>
      db.aiRuns.createAlias('ai_tool_calls__run_id__ai_runs__id');

  $$AiRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$AiRunsTableTableManager(
      $_db,
      $_db.aiRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AiToolCallsTableFilterComposer
    extends Composer<_$AppDatabase, $AiToolCallsTable> {
  $$AiToolCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AiRunsTableFilterComposer get runId {
    final $$AiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.aiRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiRunsTableFilterComposer(
            $db: $db,
            $table: $db.aiRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiToolCallsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiToolCallsTable> {
  $$AiToolCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get risk => $composableBuilder(
    column: $table.risk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AiRunsTableOrderingComposer get runId {
    final $$AiRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.aiRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiRunsTableOrderingComposer(
            $db: $db,
            $table: $db.aiRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiToolCallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiToolCallsTable> {
  $$AiToolCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get argumentsJson => $composableBuilder(
    column: $table.argumentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get risk =>
      $composableBuilder(column: $table.risk, builder: (column) => column);

  GeneratedColumn<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$AiRunsTableAnnotationComposer get runId {
    final $$AiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.aiRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiToolCallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiToolCallsTable,
          AiToolCall,
          $$AiToolCallsTableFilterComposer,
          $$AiToolCallsTableOrderingComposer,
          $$AiToolCallsTableAnnotationComposer,
          $$AiToolCallsTableCreateCompanionBuilder,
          $$AiToolCallsTableUpdateCompanionBuilder,
          (AiToolCall, $$AiToolCallsTableReferences),
          AiToolCall,
          PrefetchHooks Function({bool runId})
        > {
  $$AiToolCallsTableTableManager(_$AppDatabase db, $AiToolCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiToolCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiToolCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiToolCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> argumentsJson = const Value.absent(),
                Value<String> risk = const Value.absent(),
                Value<String> approvalStatus = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiToolCallsCompanion(
                id: id,
                runId: runId,
                name: name,
                argumentsJson: argumentsJson,
                risk: risk,
                approvalStatus: approvalStatus,
                resultJson: resultJson,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String name,
                required String argumentsJson,
                required String risk,
                required String approvalStatus,
                Value<String?> resultJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiToolCallsCompanion.insert(
                id: id,
                runId: runId,
                name: name,
                argumentsJson: argumentsJson,
                risk: risk,
                approvalStatus: approvalStatus,
                resultJson: resultJson,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AiToolCallsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable: $$AiToolCallsTableReferences
                                    ._runIdTable(db),
                                referencedColumn: $$AiToolCallsTableReferences
                                    ._runIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AiToolCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiToolCallsTable,
      AiToolCall,
      $$AiToolCallsTableFilterComposer,
      $$AiToolCallsTableOrderingComposer,
      $$AiToolCallsTableAnnotationComposer,
      $$AiToolCallsTableCreateCompanionBuilder,
      $$AiToolCallsTableUpdateCompanionBuilder,
      (AiToolCall, $$AiToolCallsTableReferences),
      AiToolCall,
      PrefetchHooks Function({bool runId})
    >;
typedef $$SharePollRefsTableCreateCompanionBuilder =
    SharePollRefsCompanion Function({
      required String id,
      required String title,
      required String inviteUrl,
      Value<String?> publicToken,
      Value<String> timezoneId,
      required String manageTokenSecretRef,
      required String status,
      Value<int> version,
      Value<String?> selectedSlotJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SharePollRefsTableUpdateCompanionBuilder =
    SharePollRefsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> inviteUrl,
      Value<String?> publicToken,
      Value<String> timezoneId,
      Value<String> manageTokenSecretRef,
      Value<String> status,
      Value<int> version,
      Value<String?> selectedSlotJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SharePollRefsTableFilterComposer
    extends Composer<_$AppDatabase, $SharePollRefsTable> {
  $$SharePollRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inviteUrl => $composableBuilder(
    column: $table.inviteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicToken => $composableBuilder(
    column: $table.publicToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manageTokenSecretRef => $composableBuilder(
    column: $table.manageTokenSecretRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedSlotJson => $composableBuilder(
    column: $table.selectedSlotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharePollRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $SharePollRefsTable> {
  $$SharePollRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inviteUrl => $composableBuilder(
    column: $table.inviteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicToken => $composableBuilder(
    column: $table.publicToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manageTokenSecretRef => $composableBuilder(
    column: $table.manageTokenSecretRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedSlotJson => $composableBuilder(
    column: $table.selectedSlotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharePollRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharePollRefsTable> {
  $$SharePollRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get inviteUrl =>
      $composableBuilder(column: $table.inviteUrl, builder: (column) => column);

  GeneratedColumn<String> get publicToken => $composableBuilder(
    column: $table.publicToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manageTokenSecretRef => $composableBuilder(
    column: $table.manageTokenSecretRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get selectedSlotJson => $composableBuilder(
    column: $table.selectedSlotJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharePollRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharePollRefsTable,
          SharePollRef,
          $$SharePollRefsTableFilterComposer,
          $$SharePollRefsTableOrderingComposer,
          $$SharePollRefsTableAnnotationComposer,
          $$SharePollRefsTableCreateCompanionBuilder,
          $$SharePollRefsTableUpdateCompanionBuilder,
          (
            SharePollRef,
            BaseReferences<_$AppDatabase, $SharePollRefsTable, SharePollRef>,
          ),
          SharePollRef,
          PrefetchHooks Function()
        > {
  $$SharePollRefsTableTableManager(_$AppDatabase db, $SharePollRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharePollRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharePollRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharePollRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> inviteUrl = const Value.absent(),
                Value<String?> publicToken = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                Value<String> manageTokenSecretRef = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> selectedSlotJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharePollRefsCompanion(
                id: id,
                title: title,
                inviteUrl: inviteUrl,
                publicToken: publicToken,
                timezoneId: timezoneId,
                manageTokenSecretRef: manageTokenSecretRef,
                status: status,
                version: version,
                selectedSlotJson: selectedSlotJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String inviteUrl,
                Value<String?> publicToken = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                required String manageTokenSecretRef,
                required String status,
                Value<int> version = const Value.absent(),
                Value<String?> selectedSlotJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharePollRefsCompanion.insert(
                id: id,
                title: title,
                inviteUrl: inviteUrl,
                publicToken: publicToken,
                timezoneId: timezoneId,
                manageTokenSecretRef: manageTokenSecretRef,
                status: status,
                version: version,
                selectedSlotJson: selectedSlotJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharePollRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharePollRefsTable,
      SharePollRef,
      $$SharePollRefsTableFilterComposer,
      $$SharePollRefsTableOrderingComposer,
      $$SharePollRefsTableAnnotationComposer,
      $$SharePollRefsTableCreateCompanionBuilder,
      $$SharePollRefsTableUpdateCompanionBuilder,
      (
        SharePollRef,
        BaseReferences<_$AppDatabase, $SharePollRefsTable, SharePollRef>,
      ),
      SharePollRef,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HostsTableTableManager get hosts =>
      $$HostsTableTableManager(_db, _db.hosts);
  $$HostGroupsTableTableManager get hostGroups =>
      $$HostGroupsTableTableManager(_db, _db.hostGroups);
  $$KnownHostKeysTableTableManager get knownHostKeys =>
      $$KnownHostKeysTableTableManager(_db, _db.knownHostKeys);
  $$OperationTagsTableTableManager get operationTags =>
      $$OperationTagsTableTableManager(_db, _db.operationTags);
  $$HostOperationTagsTableTableManager get hostOperationTags =>
      $$HostOperationTagsTableTableManager(_db, _db.hostOperationTags);
  $$AgentStatesTableTableManager get agentStates =>
      $$AgentStatesTableTableManager(_db, _db.agentStates);
  $$PortForwardProfilesTableTableManager get portForwardProfiles =>
      $$PortForwardProfilesTableTableManager(_db, _db.portForwardProfiles);
  $$CommandSnippetsTableTableManager get commandSnippets =>
      $$CommandSnippetsTableTableManager(_db, _db.commandSnippets);
  $$CommandBatchesTableTableManager get commandBatches =>
      $$CommandBatchesTableTableManager(_db, _db.commandBatches);
  $$CommandResultsTableTableManager get commandResults =>
      $$CommandResultsTableTableManager(_db, _db.commandResults);
  $$TransferJobsTableTableManager get transferJobs =>
      $$TransferJobsTableTableManager(_db, _db.transferJobs);
  $$ScheduleEventsTableTableManager get scheduleEvents =>
      $$ScheduleEventsTableTableManager(_db, _db.scheduleEvents);
  $$ScheduleRemindersTableTableManager get scheduleReminders =>
      $$ScheduleRemindersTableTableManager(_db, _db.scheduleReminders);
  $$NotificationMappingsTableTableManager get notificationMappings =>
      $$NotificationMappingsTableTableManager(_db, _db.notificationMappings);
  $$AiProviderConfigsTableTableManager get aiProviderConfigs =>
      $$AiProviderConfigsTableTableManager(_db, _db.aiProviderConfigs);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(_db, _db.aiConversations);
  $$AiRunsTableTableManager get aiRuns =>
      $$AiRunsTableTableManager(_db, _db.aiRuns);
  $$AiToolCallsTableTableManager get aiToolCalls =>
      $$AiToolCallsTableTableManager(_db, _db.aiToolCalls);
  $$SharePollRefsTableTableManager get sharePollRefs =>
      $$SharePollRefsTableTableManager(_db, _db.sharePollRefs);
}
