// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientIdMeta = const VerificationMeta(
    'recipientId',
  );
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
    'recipient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTextMeta = const VerificationMeta(
    'messageText',
  );
  @override
  late final GeneratedColumn<String> messageText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    senderId,
    recipientId,
    messageText,
    timestamp,
    type,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
        _recipientIdMeta,
        recipientId.isAcceptableOrUnknown(
          data['recipient_id']!,
          _recipientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _messageTextMeta,
        messageText.isAcceptableOrUnknown(data['text']!, _messageTextMeta),
      );
    } else if (isInserting) {
      context.missing(_messageTextMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      recipientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_id'],
      )!,
      messageText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String senderId;
  final String recipientId;
  final String messageText;
  final DateTime timestamp;
  final String type;
  final String status;
  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.messageText,
    required this.timestamp,
    required this.type,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sender_id'] = Variable<String>(senderId);
    map['recipient_id'] = Variable<String>(recipientId);
    map['text'] = Variable<String>(messageText);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      senderId: Value(senderId),
      recipientId: Value(recipientId),
      messageText: Value(messageText),
      timestamp: Value(timestamp),
      type: Value(type),
      status: Value(status),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      senderId: serializer.fromJson<String>(json['senderId']),
      recipientId: serializer.fromJson<String>(json['recipientId']),
      messageText: serializer.fromJson<String>(json['messageText']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'senderId': serializer.toJson<String>(senderId),
      'recipientId': serializer.toJson<String>(recipientId),
      'messageText': serializer.toJson<String>(messageText),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? messageText,
    DateTime? timestamp,
    String? type,
    String? status,
  }) => Message(
    id: id ?? this.id,
    senderId: senderId ?? this.senderId,
    recipientId: recipientId ?? this.recipientId,
    messageText: messageText ?? this.messageText,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    status: status ?? this.status,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      messageText: data.messageText.present
          ? data.messageText.value
          : this.messageText,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('senderId: $senderId, ')
          ..write('recipientId: $recipientId, ')
          ..write('messageText: $messageText, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    senderId,
    recipientId,
    messageText,
    timestamp,
    type,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.senderId == this.senderId &&
          other.recipientId == this.recipientId &&
          other.messageText == this.messageText &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.status == this.status);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> senderId;
  final Value<String> recipientId;
  final Value<String> messageText;
  final Value<DateTime> timestamp;
  final Value<String> type;
  final Value<String> status;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.senderId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.messageText = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String senderId,
    required String recipientId,
    required String messageText,
    required DateTime timestamp,
    required String type,
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       senderId = Value(senderId),
       recipientId = Value(recipientId),
       messageText = Value(messageText),
       timestamp = Value(timestamp),
       type = Value(type),
       status = Value(status);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? senderId,
    Expression<String>? recipientId,
    Expression<String>? messageText,
    Expression<DateTime>? timestamp,
    Expression<String>? type,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (senderId != null) 'sender_id': senderId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (messageText != null) 'text': messageText,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? senderId,
    Value<String>? recipientId,
    Value<String>? messageText,
    Value<DateTime>? timestamp,
    Value<String>? type,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      messageText: messageText ?? this.messageText,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (messageText.present) {
      map['text'] = Variable<String>(messageText.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('senderId: $senderId, ')
          ..write('recipientId: $recipientId, ')
          ..write('messageText: $messageText, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserAccountsTable extends UserAccounts
    with TableInfo<$UserAccountsTable, DbUserAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
    'salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicIdentityKeyMeta = const VerificationMeta(
    'publicIdentityKey',
  );
  @override
  late final GeneratedColumn<String> publicIdentityKey =
      GeneratedColumn<String>(
        'public_identity_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recoveryKeyHashMeta = const VerificationMeta(
    'recoveryKeyHash',
  );
  @override
  late final GeneratedColumn<String> recoveryKeyHash = GeneratedColumn<String>(
    'recovery_key_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryKeySaltMeta = const VerificationMeta(
    'recoveryKeySalt',
  );
  @override
  late final GeneratedColumn<String> recoveryKeySalt = GeneratedColumn<String>(
    'recovery_key_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    username,
    passwordHash,
    salt,
    createdAt,
    publicIdentityKey,
    recoveryKeyHash,
    recoveryKeySalt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbUserAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    } else if (isInserting) {
      context.missing(_saltMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('public_identity_key')) {
      context.handle(
        _publicIdentityKeyMeta,
        publicIdentityKey.isAcceptableOrUnknown(
          data['public_identity_key']!,
          _publicIdentityKeyMeta,
        ),
      );
    }
    if (data.containsKey('recovery_key_hash')) {
      context.handle(
        _recoveryKeyHashMeta,
        recoveryKeyHash.isAcceptableOrUnknown(
          data['recovery_key_hash']!,
          _recoveryKeyHashMeta,
        ),
      );
    }
    if (data.containsKey('recovery_key_salt')) {
      context.handle(
        _recoveryKeySaltMeta,
        recoveryKeySalt.isAcceptableOrUnknown(
          data['recovery_key_salt']!,
          _recoveryKeySaltMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  DbUserAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbUserAccount(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      publicIdentityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_identity_key'],
      ),
      recoveryKeyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_key_hash'],
      ),
      recoveryKeySalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_key_salt'],
      ),
    );
  }

  @override
  $UserAccountsTable createAlias(String alias) {
    return $UserAccountsTable(attachedDatabase, alias);
  }
}

class DbUserAccount extends DataClass implements Insertable<DbUserAccount> {
  final String accountId;
  final String username;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final String? publicIdentityKey;
  final String? recoveryKeyHash;
  final String? recoveryKeySalt;
  const DbUserAccount({
    required this.accountId,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.publicIdentityKey,
    this.recoveryKeyHash,
    this.recoveryKeySalt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['username'] = Variable<String>(username);
    map['password_hash'] = Variable<String>(passwordHash);
    map['salt'] = Variable<String>(salt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || publicIdentityKey != null) {
      map['public_identity_key'] = Variable<String>(publicIdentityKey);
    }
    if (!nullToAbsent || recoveryKeyHash != null) {
      map['recovery_key_hash'] = Variable<String>(recoveryKeyHash);
    }
    if (!nullToAbsent || recoveryKeySalt != null) {
      map['recovery_key_salt'] = Variable<String>(recoveryKeySalt);
    }
    return map;
  }

  UserAccountsCompanion toCompanion(bool nullToAbsent) {
    return UserAccountsCompanion(
      accountId: Value(accountId),
      username: Value(username),
      passwordHash: Value(passwordHash),
      salt: Value(salt),
      createdAt: Value(createdAt),
      publicIdentityKey: publicIdentityKey == null && nullToAbsent
          ? const Value.absent()
          : Value(publicIdentityKey),
      recoveryKeyHash: recoveryKeyHash == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryKeyHash),
      recoveryKeySalt: recoveryKeySalt == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryKeySalt),
    );
  }

  factory DbUserAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbUserAccount(
      accountId: serializer.fromJson<String>(json['accountId']),
      username: serializer.fromJson<String>(json['username']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      salt: serializer.fromJson<String>(json['salt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      publicIdentityKey: serializer.fromJson<String?>(
        json['publicIdentityKey'],
      ),
      recoveryKeyHash: serializer.fromJson<String?>(json['recoveryKeyHash']),
      recoveryKeySalt: serializer.fromJson<String?>(json['recoveryKeySalt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'username': serializer.toJson<String>(username),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'salt': serializer.toJson<String>(salt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'publicIdentityKey': serializer.toJson<String?>(publicIdentityKey),
      'recoveryKeyHash': serializer.toJson<String?>(recoveryKeyHash),
      'recoveryKeySalt': serializer.toJson<String?>(recoveryKeySalt),
    };
  }

  DbUserAccount copyWith({
    String? accountId,
    String? username,
    String? passwordHash,
    String? salt,
    DateTime? createdAt,
    Value<String?> publicIdentityKey = const Value.absent(),
    Value<String?> recoveryKeyHash = const Value.absent(),
    Value<String?> recoveryKeySalt = const Value.absent(),
  }) => DbUserAccount(
    accountId: accountId ?? this.accountId,
    username: username ?? this.username,
    passwordHash: passwordHash ?? this.passwordHash,
    salt: salt ?? this.salt,
    createdAt: createdAt ?? this.createdAt,
    publicIdentityKey: publicIdentityKey.present
        ? publicIdentityKey.value
        : this.publicIdentityKey,
    recoveryKeyHash: recoveryKeyHash.present
        ? recoveryKeyHash.value
        : this.recoveryKeyHash,
    recoveryKeySalt: recoveryKeySalt.present
        ? recoveryKeySalt.value
        : this.recoveryKeySalt,
  );
  DbUserAccount copyWithCompanion(UserAccountsCompanion data) {
    return DbUserAccount(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      username: data.username.present ? data.username.value : this.username,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      salt: data.salt.present ? data.salt.value : this.salt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      publicIdentityKey: data.publicIdentityKey.present
          ? data.publicIdentityKey.value
          : this.publicIdentityKey,
      recoveryKeyHash: data.recoveryKeyHash.present
          ? data.recoveryKeyHash.value
          : this.recoveryKeyHash,
      recoveryKeySalt: data.recoveryKeySalt.present
          ? data.recoveryKeySalt.value
          : this.recoveryKeySalt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbUserAccount(')
          ..write('accountId: $accountId, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('salt: $salt, ')
          ..write('createdAt: $createdAt, ')
          ..write('publicIdentityKey: $publicIdentityKey, ')
          ..write('recoveryKeyHash: $recoveryKeyHash, ')
          ..write('recoveryKeySalt: $recoveryKeySalt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    username,
    passwordHash,
    salt,
    createdAt,
    publicIdentityKey,
    recoveryKeyHash,
    recoveryKeySalt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbUserAccount &&
          other.accountId == this.accountId &&
          other.username == this.username &&
          other.passwordHash == this.passwordHash &&
          other.salt == this.salt &&
          other.createdAt == this.createdAt &&
          other.publicIdentityKey == this.publicIdentityKey &&
          other.recoveryKeyHash == this.recoveryKeyHash &&
          other.recoveryKeySalt == this.recoveryKeySalt);
}

class UserAccountsCompanion extends UpdateCompanion<DbUserAccount> {
  final Value<String> accountId;
  final Value<String> username;
  final Value<String> passwordHash;
  final Value<String> salt;
  final Value<DateTime> createdAt;
  final Value<String?> publicIdentityKey;
  final Value<String?> recoveryKeyHash;
  final Value<String?> recoveryKeySalt;
  final Value<int> rowid;
  const UserAccountsCompanion({
    this.accountId = const Value.absent(),
    this.username = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.salt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.publicIdentityKey = const Value.absent(),
    this.recoveryKeyHash = const Value.absent(),
    this.recoveryKeySalt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAccountsCompanion.insert({
    required String accountId,
    required String username,
    required String passwordHash,
    required String salt,
    required DateTime createdAt,
    this.publicIdentityKey = const Value.absent(),
    this.recoveryKeyHash = const Value.absent(),
    this.recoveryKeySalt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       username = Value(username),
       passwordHash = Value(passwordHash),
       salt = Value(salt),
       createdAt = Value(createdAt);
  static Insertable<DbUserAccount> custom({
    Expression<String>? accountId,
    Expression<String>? username,
    Expression<String>? passwordHash,
    Expression<String>? salt,
    Expression<DateTime>? createdAt,
    Expression<String>? publicIdentityKey,
    Expression<String>? recoveryKeyHash,
    Expression<String>? recoveryKeySalt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (username != null) 'username': username,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (salt != null) 'salt': salt,
      if (createdAt != null) 'created_at': createdAt,
      if (publicIdentityKey != null) 'public_identity_key': publicIdentityKey,
      if (recoveryKeyHash != null) 'recovery_key_hash': recoveryKeyHash,
      if (recoveryKeySalt != null) 'recovery_key_salt': recoveryKeySalt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAccountsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? username,
    Value<String>? passwordHash,
    Value<String>? salt,
    Value<DateTime>? createdAt,
    Value<String?>? publicIdentityKey,
    Value<String?>? recoveryKeyHash,
    Value<String?>? recoveryKeySalt,
    Value<int>? rowid,
  }) {
    return UserAccountsCompanion(
      accountId: accountId ?? this.accountId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
      publicIdentityKey: publicIdentityKey ?? this.publicIdentityKey,
      recoveryKeyHash: recoveryKeyHash ?? this.recoveryKeyHash,
      recoveryKeySalt: recoveryKeySalt ?? this.recoveryKeySalt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (publicIdentityKey.present) {
      map['public_identity_key'] = Variable<String>(publicIdentityKey.value);
    }
    if (recoveryKeyHash.present) {
      map['recovery_key_hash'] = Variable<String>(recoveryKeyHash.value);
    }
    if (recoveryKeySalt.present) {
      map['recovery_key_salt'] = Variable<String>(recoveryKeySalt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAccountsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('salt: $salt, ')
          ..write('createdAt: $createdAt, ')
          ..write('publicIdentityKey: $publicIdentityKey, ')
          ..write('recoveryKeyHash: $recoveryKeyHash, ')
          ..write('recoveryKeySalt: $recoveryKeySalt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecurityLogsTable extends SecurityLogs
    with TableInfo<$SecurityLogsTable, DbSecurityLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecurityLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    details,
    severity,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'security_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSecurityLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbSecurityLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSecurityLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $SecurityLogsTable createAlias(String alias) {
    return $SecurityLogsTable(attachedDatabase, alias);
  }
}

class DbSecurityLog extends DataClass implements Insertable<DbSecurityLog> {
  final String id;
  final String eventType;
  final String details;
  final String severity;
  final DateTime timestamp;
  const DbSecurityLog({
    required this.id,
    required this.eventType,
    required this.details,
    required this.severity,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    map['details'] = Variable<String>(details);
    map['severity'] = Variable<String>(severity);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SecurityLogsCompanion toCompanion(bool nullToAbsent) {
    return SecurityLogsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      details: Value(details),
      severity: Value(severity),
      timestamp: Value(timestamp),
    );
  }

  factory DbSecurityLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSecurityLog(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      details: serializer.fromJson<String>(json['details']),
      severity: serializer.fromJson<String>(json['severity']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'details': serializer.toJson<String>(details),
      'severity': serializer.toJson<String>(severity),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  DbSecurityLog copyWith({
    String? id,
    String? eventType,
    String? details,
    String? severity,
    DateTime? timestamp,
  }) => DbSecurityLog(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    details: details ?? this.details,
    severity: severity ?? this.severity,
    timestamp: timestamp ?? this.timestamp,
  );
  DbSecurityLog copyWithCompanion(SecurityLogsCompanion data) {
    return DbSecurityLog(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      details: data.details.present ? data.details.value : this.details,
      severity: data.severity.present ? data.severity.value : this.severity,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSecurityLog(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('details: $details, ')
          ..write('severity: $severity, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventType, details, severity, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSecurityLog &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.details == this.details &&
          other.severity == this.severity &&
          other.timestamp == this.timestamp);
}

class SecurityLogsCompanion extends UpdateCompanion<DbSecurityLog> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String> details;
  final Value<String> severity;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const SecurityLogsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.details = const Value.absent(),
    this.severity = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecurityLogsCompanion.insert({
    required String id,
    required String eventType,
    required String details,
    required String severity,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventType = Value(eventType),
       details = Value(details),
       severity = Value(severity),
       timestamp = Value(timestamp);
  static Insertable<DbSecurityLog> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? details,
    Expression<String>? severity,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (details != null) 'details': details,
      if (severity != null) 'severity': severity,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecurityLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventType,
    Value<String>? details,
    Value<String>? severity,
    Value<DateTime>? timestamp,
    Value<int>? rowid,
  }) {
    return SecurityLogsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      details: details ?? this.details,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecurityLogsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('details: $details, ')
          ..write('severity: $severity, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $UserAccountsTable userAccounts = $UserAccountsTable(this);
  late final $SecurityLogsTable securityLogs = $SecurityLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    userAccounts,
    securityLogs,
  ];
}

typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String senderId,
      required String recipientId,
      required String messageText,
      required DateTime timestamp,
      required String type,
      required String status,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> senderId,
      Value<String> recipientId,
      Value<String> messageText,
      Value<DateTime> timestamp,
      Value<String> type,
      Value<String> status,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> recipientId = const Value.absent(),
                Value<String> messageText = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                senderId: senderId,
                recipientId: recipientId,
                messageText: messageText,
                timestamp: timestamp,
                type: type,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String senderId,
                required String recipientId,
                required String messageText,
                required DateTime timestamp,
                required String type,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                senderId: senderId,
                recipientId: recipientId,
                messageText: messageText,
                timestamp: timestamp,
                type: type,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$UserAccountsTableCreateCompanionBuilder =
    UserAccountsCompanion Function({
      required String accountId,
      required String username,
      required String passwordHash,
      required String salt,
      required DateTime createdAt,
      Value<String?> publicIdentityKey,
      Value<String?> recoveryKeyHash,
      Value<String?> recoveryKeySalt,
      Value<int> rowid,
    });
typedef $$UserAccountsTableUpdateCompanionBuilder =
    UserAccountsCompanion Function({
      Value<String> accountId,
      Value<String> username,
      Value<String> passwordHash,
      Value<String> salt,
      Value<DateTime> createdAt,
      Value<String?> publicIdentityKey,
      Value<String?> recoveryKeyHash,
      Value<String?> recoveryKeySalt,
      Value<int> rowid,
    });

class $$UserAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicIdentityKey => $composableBuilder(
    column: $table.publicIdentityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recoveryKeyHash => $composableBuilder(
    column: $table.recoveryKeyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recoveryKeySalt => $composableBuilder(
    column: $table.recoveryKeySalt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicIdentityKey => $composableBuilder(
    column: $table.publicIdentityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recoveryKeyHash => $composableBuilder(
    column: $table.recoveryKeyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recoveryKeySalt => $composableBuilder(
    column: $table.recoveryKeySalt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserAccountsTable> {
  $$UserAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get publicIdentityKey => $composableBuilder(
    column: $table.publicIdentityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recoveryKeyHash => $composableBuilder(
    column: $table.recoveryKeyHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recoveryKeySalt => $composableBuilder(
    column: $table.recoveryKeySalt,
    builder: (column) => column,
  );
}

class $$UserAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserAccountsTable,
          DbUserAccount,
          $$UserAccountsTableFilterComposer,
          $$UserAccountsTableOrderingComposer,
          $$UserAccountsTableAnnotationComposer,
          $$UserAccountsTableCreateCompanionBuilder,
          $$UserAccountsTableUpdateCompanionBuilder,
          (
            DbUserAccount,
            BaseReferences<_$AppDatabase, $UserAccountsTable, DbUserAccount>,
          ),
          DbUserAccount,
          PrefetchHooks Function()
        > {
  $$UserAccountsTableTableManager(_$AppDatabase db, $UserAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String> salt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> publicIdentityKey = const Value.absent(),
                Value<String?> recoveryKeyHash = const Value.absent(),
                Value<String?> recoveryKeySalt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAccountsCompanion(
                accountId: accountId,
                username: username,
                passwordHash: passwordHash,
                salt: salt,
                createdAt: createdAt,
                publicIdentityKey: publicIdentityKey,
                recoveryKeyHash: recoveryKeyHash,
                recoveryKeySalt: recoveryKeySalt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String username,
                required String passwordHash,
                required String salt,
                required DateTime createdAt,
                Value<String?> publicIdentityKey = const Value.absent(),
                Value<String?> recoveryKeyHash = const Value.absent(),
                Value<String?> recoveryKeySalt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAccountsCompanion.insert(
                accountId: accountId,
                username: username,
                passwordHash: passwordHash,
                salt: salt,
                createdAt: createdAt,
                publicIdentityKey: publicIdentityKey,
                recoveryKeyHash: recoveryKeyHash,
                recoveryKeySalt: recoveryKeySalt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserAccountsTable,
      DbUserAccount,
      $$UserAccountsTableFilterComposer,
      $$UserAccountsTableOrderingComposer,
      $$UserAccountsTableAnnotationComposer,
      $$UserAccountsTableCreateCompanionBuilder,
      $$UserAccountsTableUpdateCompanionBuilder,
      (
        DbUserAccount,
        BaseReferences<_$AppDatabase, $UserAccountsTable, DbUserAccount>,
      ),
      DbUserAccount,
      PrefetchHooks Function()
    >;
typedef $$SecurityLogsTableCreateCompanionBuilder =
    SecurityLogsCompanion Function({
      required String id,
      required String eventType,
      required String details,
      required String severity,
      required DateTime timestamp,
      Value<int> rowid,
    });
typedef $$SecurityLogsTableUpdateCompanionBuilder =
    SecurityLogsCompanion Function({
      Value<String> id,
      Value<String> eventType,
      Value<String> details,
      Value<String> severity,
      Value<DateTime> timestamp,
      Value<int> rowid,
    });

class $$SecurityLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SecurityLogsTable> {
  $$SecurityLogsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecurityLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SecurityLogsTable> {
  $$SecurityLogsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecurityLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecurityLogsTable> {
  $$SecurityLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$SecurityLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecurityLogsTable,
          DbSecurityLog,
          $$SecurityLogsTableFilterComposer,
          $$SecurityLogsTableOrderingComposer,
          $$SecurityLogsTableAnnotationComposer,
          $$SecurityLogsTableCreateCompanionBuilder,
          $$SecurityLogsTableUpdateCompanionBuilder,
          (
            DbSecurityLog,
            BaseReferences<_$AppDatabase, $SecurityLogsTable, DbSecurityLog>,
          ),
          DbSecurityLog,
          PrefetchHooks Function()
        > {
  $$SecurityLogsTableTableManager(_$AppDatabase db, $SecurityLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SecurityLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SecurityLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SecurityLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecurityLogsCompanion(
                id: id,
                eventType: eventType,
                details: details,
                severity: severity,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventType,
                required String details,
                required String severity,
                required DateTime timestamp,
                Value<int> rowid = const Value.absent(),
              }) => SecurityLogsCompanion.insert(
                id: id,
                eventType: eventType,
                details: details,
                severity: severity,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecurityLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecurityLogsTable,
      DbSecurityLog,
      $$SecurityLogsTableFilterComposer,
      $$SecurityLogsTableOrderingComposer,
      $$SecurityLogsTableAnnotationComposer,
      $$SecurityLogsTableCreateCompanionBuilder,
      $$SecurityLogsTableUpdateCompanionBuilder,
      (
        DbSecurityLog,
        BaseReferences<_$AppDatabase, $SecurityLogsTable, DbSecurityLog>,
      ),
      DbSecurityLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$UserAccountsTableTableManager get userAccounts =>
      $$UserAccountsTableTableManager(_db, _db.userAccounts);
  $$SecurityLogsTableTableManager get securityLogs =>
      $$SecurityLogsTableTableManager(_db, _db.securityLogs);
}
