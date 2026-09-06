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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(name: 'ourplace_chat'));

  @override
  int get schemaVersion => 1;
}
