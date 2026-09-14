import 'package:drift/drift.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user_account.dart';

/// Local database service for persisting chat messages and anonymous accounts using Drift / SQLite
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

  // ==================== MESSAGE CONVERSIONS & CRUD ====================

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
  Future<List<ChatMessage>> getMessagesForPartner(
    String partnerId, {
    String currentUserId = 'current_user',
  }) async {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals(currentUserId)) |
          (tbl.senderId.equals(currentUserId) &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    final rows = await query.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Retrieve messages with pagination
  Future<List<ChatMessage>> getMessagesForPartnerPaginated(
    String partnerId, {
    String currentUserId = 'current_user',
    required int offset,
    required int limit,
  }) async {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals(currentUserId)) |
          (tbl.senderId.equals(currentUserId) &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit, offset: offset);

    final rows = await query.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Reactive stream of messages for a partner (updates UI automatically)
  Stream<List<ChatMessage>> watchMessagesForPartner(
    String partnerId, {
    String currentUserId = 'current_user',
  }) {
    final query = db.select(db.messages)
      ..where((tbl) =>
          (tbl.senderId.equals(partnerId) &
              tbl.recipientId.equals(currentUserId)) |
          (tbl.senderId.equals(currentUserId) &
              tbl.recipientId.equals(partnerId)))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    return query.watch().map((rows) => rows.map(_rowToMessage).toList());
  }

  /// Search messages by content
  Future<List<ChatMessage>> searchMessages({
    required String partnerId,
    required String query,
    String currentUserId = 'current_user',
  }) async {
    final q = db.select(db.messages)
      ..where((tbl) =>
          ((tbl.senderId.equals(partnerId) &
                  tbl.recipientId.equals(currentUserId)) |
              (tbl.senderId.equals(currentUserId) &
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
  Future<void> clearMessagesForPartner(
    String partnerId, {
    String currentUserId = 'current_user',
  }) async {
    await (db.delete(db.messages)
          ..where((tbl) =>
              (tbl.senderId.equals(partnerId) &
                  tbl.recipientId.equals(currentUserId)) |
              (tbl.senderId.equals(currentUserId) &
                  tbl.recipientId.equals(partnerId))))
        .go();
  }

  /// Get total message count for a partner
  Future<int> getMessageCountForPartner(
    String partnerId, {
    String currentUserId = 'current_user',
  }) async {
    final countExp = db.messages.id.count();
    final query = db.selectOnly(db.messages)
      ..addColumns([countExp])
      ..where((db.messages.senderId.equals(partnerId) &
              db.messages.recipientId.equals(currentUserId)) |
          (db.messages.senderId.equals(currentUserId) &
              db.messages.recipientId.equals(partnerId)));

    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  // ==================== USER ACCOUNT CONVERSIONS & CRUD ====================

  /// Convert Drift DbUserAccount row to domain UserAccount
  UserAccount _rowToAccount(DbUserAccount row) {
    return UserAccount(
      accountId: row.accountId,
      username: row.username,
      passwordHash: row.passwordHash,
      salt: row.salt,
      createdAt: row.createdAt,
      publicIdentityKey: row.publicIdentityKey,
    );
  }

  /// Convert domain UserAccount to Drift UserAccountsCompanion
  UserAccountsCompanion _accountToCompanion(UserAccount account) {
    return UserAccountsCompanion(
      accountId: Value(account.accountId),
      username: Value(account.username),
      passwordHash: Value(account.passwordHash),
      salt: Value(account.salt),
      createdAt: Value(account.createdAt),
      publicIdentityKey: Value(account.publicIdentityKey),
    );
  }

  /// Save or update an anonymous user account
  Future<void> saveAccount(UserAccount account) async {
    await db.into(db.userAccounts).insertOnConflictUpdate(
          _accountToCompanion(account),
        );
  }

  /// Retrieve an account by username (normalizing with or without '@')
  Future<UserAccount?> getAccountByUsername(String username) async {
    final clean = username.trim().replaceAll('@', '').toLowerCase();
    final normalized = '@$clean';
    final query = db.select(db.userAccounts)
      ..where((tbl) => tbl.username.equals(normalized));
    final row = await query.getSingleOrNull();
    return row != null ? _rowToAccount(row) : null;
  }

  /// Retrieve an account by account ID
  Future<UserAccount?> getAccountById(String accountId) async {
    final query = db.select(db.userAccounts)
      ..where((tbl) => tbl.accountId.equals(accountId));
    final row = await query.getSingleOrNull();
    return row != null ? _rowToAccount(row) : null;
  }

  /// Check if a username is already taken
  Future<bool> isUsernameTaken(String username) async {
    final account = await getAccountByUsername(username);
    return account != null;
  }

  /// Get all registered accounts on device
  Future<List<UserAccount>> getAllAccounts() async {
    final rows = await db.select(db.userAccounts).get();
    return rows.map(_rowToAccount).toList();
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
