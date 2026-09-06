import 'package:drift/drift.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/models/message.dart';

/// Local database service for persisting chat messages using Drift / SQLite
class LocalDatabase {
  /// Singleton instance
  static final LocalDatabase _instance = LocalDatabase._internal();

  factory LocalDatabase({AppDatabase? database}) {
    if (database != null) {
      _instance._db = database;
    }
    return _instance;
  }

  LocalDatabase._internal();

  AppDatabase? _db;

  /// Internal getter for the Drift database instance
  AppDatabase get db {
    _db ??= AppDatabase();
    return _db!;
  }

  /// Initialize the database
  Future<void> initialize() async {
    // Accessing db ensures initialization
    final _ = db;
  }

  /// Convert a Drift database Message row to domain ChatMessage
  ChatMessage _rowToMessage(Message row) {
    return ChatMessage(
      id: row.id,
      senderId: row.senderId,
      recipientId: row.recipientId,
      text: row.messageText,
      timestamp: row.timestamp,
      type: MessageType.values.firstWhere(
        (e) => e.name == row.type,
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  /// Convert domain ChatMessage to Drift MessagesCompanion for insert/update
  MessagesCompanion _messageToCompanion(ChatMessage message) {
    return MessagesCompanion(
      id: Value(message.id),
      senderId: Value(message.senderId),
      recipientId: Value(message.recipientId),
      messageText: Value(message.text),
      timestamp: Value(message.timestamp),
      type: Value(message.type.name),
      status: Value(message.status.name),
    );
  }

  /// Save a single message to local database (insert or update on conflict)
  Future<void> saveMessage(ChatMessage message) async {
    await db.into(db.messages).insertOnConflictUpdate(
          _messageToCompanion(message),
        );
  }

  /// Batch save messages (e.g., initial seed or sync)
  Future<void> saveMessages(List<ChatMessage> messages) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.messages,
        messages.map(_messageToCompanion).toList(),
      );
    });
  }

  /// Retrieve all messages for a partner, newest first (matching reverse list)
  Future<List<ChatMessage>> getMessagesForPartner(String partnerId) async {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals('current_user')) |
          (tbl.senderId.equals('current_user') &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    final rows = await query.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Retrieve messages with pagination
  Future<List<ChatMessage>> getMessagesForPartnerPaginated(
    String partnerId, {
    required int offset,
    required int limit,
  }) async {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals('current_user')) |
          (tbl.senderId.equals('current_user') &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit, offset: offset);

    final rows = await query.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Reactive stream of messages for a partner (updates UI automatically)
  Stream<List<ChatMessage>> watchMessagesForPartner(String partnerId) {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals('current_user')) |
          (tbl.senderId.equals('current_user') &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    return query.watch().map((rows) => rows.map(_rowToMessage).toList());
  }

  /// Search messages by content
  Future<List<ChatMessage>> searchMessages({
    required String partnerId,
    required String query,
  }) async {
    final q = db.select(db.messages)
      ..where((tbl) =>
          ((tbl.senderId.equals(partnerId) &
                  tbl.recipientId.equals('current_user')) |
              (tbl.senderId.equals('current_user') &
                  tbl.recipientId.equals(partnerId))) &
          tbl.messageText.contains(query))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    final rows = await q.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Delete a message from local database
  Future<bool> deleteMessage(String messageId) async {
    final count = await (db.delete(db.messages)
          ..where((tbl) => tbl.id.equals(messageId)))
        .go();
    return count > 0;
  }

  /// Update an existing message
  Future<bool> updateMessage(ChatMessage message) async {
    return await db.update(db.messages).replace(_messageToCompanion(message));
  }

  /// Update status of an individual message
  Future<bool> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final count = await (db.update(db.messages)
          ..where((tbl) => tbl.id.equals(messageId)))
        .write(MessagesCompanion(status: Value(status.name)));
    return count > 0;
  }

  /// Clear all messages for a partner
  Future<void> clearMessagesForPartner(String partnerId) async {
    await (db.delete(db.messages)
          ..where((tbl) =>
              (tbl.senderId.equals(partnerId) &
                  tbl.recipientId.equals('current_user')) |
              (tbl.senderId.equals('current_user') &
                  tbl.recipientId.equals(partnerId))))
        .go();
  }

  /// Get total message count for a partner
  Future<int> getMessageCountForPartner(String partnerId) async {
    final countExp = db.messages.id.count();
    final query = db.selectOnly(db.messages)
      ..addColumns([countExp])
      ..where((db.messages.senderId.equals(partnerId) &
              db.messages.recipientId.equals('current_user')) |
          (db.messages.senderId.equals('current_user') &
              db.messages.recipientId.equals(partnerId)));

    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Check if database is initialized
  Future<bool> isInitialized() async {
    return _db != null;
  }

  /// Close the database
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
