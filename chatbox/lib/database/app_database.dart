import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table schema for storing chat messages locally
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get senderId => text()();
  TextColumn get recipientId => text()();
  TextColumn get messageText => text().named('text')();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get mediaData => text().nullable()();
  TextColumn get reactions => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table schema for storing anonymous user accounts and salted verifiers locally
@DataClassName('DbUserAccount')
class UserAccounts extends Table {
  TextColumn get accountId => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get salt => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get publicIdentityKey => text().nullable()();
  TextColumn get recoveryKeyHash => text().nullable()();
  TextColumn get recoveryKeySalt => text().nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// Table schema for storing device-local security audit logs
@DataClassName('DbSecurityLog')
class SecurityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get details => text()();
  TextColumn get severity => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table schema for storing 1-to-1 Love Connection state locally (Phase 16)
@DataClassName('DbLoveConnection')
class LoveConnections extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get partnerUsername => text()();
  TextColumn get partnerUserId => text().nullable()();
  TextColumn get partnerPublicKey => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get connectedAt => dateTime().nullable()();
  DateTimeColumn get disconnectedAt => dateTime().nullable()();
  BoolColumn get isVisibleOnProfile =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table schema for storing couple love letters and "Open When..." notes (Phase 18)
@DataClassName('DbLoveNote')
class LoveNotes extends Table {
  TextColumn get id => text()();
  TextColumn get senderUsername => text()();
  TextColumn get recipientUsername => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get openAt => dateTime().nullable()();
  BoolColumn get isOpened => boolean().withDefault(const Constant(false))();
  TextColumn get tag => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Messages, UserAccounts, SecurityLogs, LoveConnections, LoveNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(name: 'ourplace_chat'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(userAccounts);
          }
          if (from < 3) {
            await m.addColumn(userAccounts, userAccounts.recoveryKeyHash);
            await m.addColumn(userAccounts, userAccounts.recoveryKeySalt);
            await m.createTable(securityLogs);
          }
          if (from < 4) {
            await m.addColumn(messages, messages.mediaData);
          }
          if (from < 5) {
            await m.createTable(loveConnections);
          }
          if (from < 6) {
            await m.addColumn(messages, messages.reactions);
            await m.createTable(loveNotes);
          }
        },
      );
}

