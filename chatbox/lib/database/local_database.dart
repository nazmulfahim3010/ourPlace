import 'package:drift/drift.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/security_log.dart';
import 'package:chatbox/models/user_account.dart';

/// Local database service for persisting chat messages, anonymous accounts, and security logs using Drift / SQLite
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

  /// Retrieve a message by its unique ID
  Future<ChatMessage?> getMessageById(String messageId) async {
    final row = await (db.select(db.messages)
          ..where((tbl) => tbl.id.equals(messageId)))
        .getSingleOrNull();
    return row != null ? _rowToMessage(row) : null;
  }

  /// Update message status strictly if moving forward in the lifecycle (Phase 12)
  Future<bool> updateMessageStatusIfProgressing(
    String messageId,
    MessageStatus newStatus,
  ) async {
    final message = await getMessageById(messageId);
    if (message == null) return false;
    if (!message.canTransitionTo(newStatus)) return false;

    return updateMessageStatus(messageId, newStatus);
  }

  /// Retrieve all unsent / failed messages pending offline transmission
  Future<List<ChatMessage>> getUnsentMessages({
    String? partnerId,
    String currentUserId = 'current_user',
  }) async {
    final query = db.select(db.messages)
      ..where((tbl) {
        final senderCheck = tbl.senderId.equals(currentUserId) |
            tbl.senderId.equals('current_user');
        final statusCheck = tbl.status.equals(MessageStatus.sending.name) |
            tbl.status.equals(MessageStatus.failed.name);
        if (partnerId != null && partnerId.isNotEmpty) {
          return senderCheck & statusCheck & tbl.recipientId.equals(partnerId);
        }
        return senderCheck & statusCheck;
      })
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.timestamp)]);

    final rows = await query.get();
    return rows.map(_rowToMessage).toList();
  }

  /// Mark all unread incoming messages from partner as read (Phase 12)
  Future<int> markConversationAsRead(
    String partnerId, {
    String currentUserId = 'current_user',
  }) async {
    final count = await (db.update(db.messages)
          ..where((tbl) =>
              tbl.senderId.equals(partnerId) &
              (tbl.recipientId.equals(currentUserId) |
                  tbl.recipientId.equals('current_user')) &
              tbl.status.equals(MessageStatus.read.name).not()))
        .write(MessagesCompanion(status: Value(MessageStatus.read.name)));
    return count;
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
      recoveryKeyHash: row.recoveryKeyHash,
      recoveryKeySalt: row.recoveryKeySalt,
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
      recoveryKeyHash: Value(account.recoveryKeyHash),
      recoveryKeySalt: Value(account.recoveryKeySalt),
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

  /// Set or update recovery key hash and salt for an existing account
  Future<bool> setAccountRecoveryKey(
    String username, {
    required String recoveryKeyHash,
    required String recoveryKeySalt,
  }) async {
    final account = await getAccountByUsername(username);
    if (account == null) return false;

    final updated = account.copyWith(
      recoveryKeyHash: recoveryKeyHash,
      recoveryKeySalt: recoveryKeySalt,
    );
    await saveAccount(updated);
    await logSecurityEvent(
      'recovery_key_updated',
      'Recovery key configured/updated for account ${account.username}',
      severity: 'info',
    );
    return true;
  }

  /// Reset account password using verified recovery phrase
  Future<bool> resetPasswordWithRecoveryKey({
    required String username,
    required String recoveryPhrase,
    required String newPlaintextPassword,
  }) async {
    final account = await getAccountByUsername(username);
    if (account == null) return false;

    final isRecoveryValid = account.verifyRecoveryKey(recoveryPhrase);
    if (!isRecoveryValid) {
      await logSecurityEvent(
        'recovery_reset_failed',
        'Invalid recovery phrase provided for password reset on ${account.username}',
        severity: 'warning',
      );
      return false;
    }

    final newSalt = HashUtils.generateSalt();
    final newPasswordHash = HashUtils.hashPassword(newPlaintextPassword, newSalt);

    final updated = account.copyWith(
      passwordHash: newPasswordHash,
      salt: newSalt,
    );

    await saveAccount(updated);
    await logSecurityEvent(
      'password_reset_success',
      'Password successfully reset using recovery key for ${account.username}',
      severity: 'critical',
    );
    return true;
  }

  // ==================== SECURITY AUDIT LOGS CRUD ====================

  /// Convert Drift DbSecurityLog row to domain SecurityLog
  SecurityLog _rowToSecurityLog(DbSecurityLog row) {
    return SecurityLog(
      id: row.id,
      eventType: row.eventType,
      details: row.details,
      severity: row.severity,
      timestamp: row.timestamp,
    );
  }

  /// Convert domain SecurityLog to Drift SecurityLogsCompanion
  SecurityLogsCompanion _logToCompanion(SecurityLog log) {
    return SecurityLogsCompanion(
      id: Value(log.id),
      eventType: Value(log.eventType),
      details: Value(log.details),
      severity: Value(log.severity),
      timestamp: Value(log.timestamp),
    );
  }

  /// Log a local security event
  Future<void> logSecurityEvent(
    String eventType,
    String details, {
    String severity = 'info',
  }) async {
    final id = 'sec_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    final log = SecurityLog(
      id: id,
      eventType: eventType,
      details: details,
      severity: severity,
      timestamp: DateTime.now(),
    );

    await db.into(db.securityLogs).insertOnConflictUpdate(_logToCompanion(log));
  }

  /// Retrieve recent security logs, newest first
  Future<List<SecurityLog>> getSecurityLogs({int limit = 50}) async {
    final query = db.select(db.securityLogs)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.timestamp),
        (tbl) => OrderingTerm.desc(tbl.id),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_rowToSecurityLog).toList();
  }

  /// Reactive stream of security logs for UI display
  Stream<List<SecurityLog>> watchSecurityLogs({int limit = 50}) {
    final query = db.select(db.securityLogs)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.timestamp),
        (tbl) => OrderingTerm.desc(tbl.id),
      ])
      ..limit(limit);

    return query.watch().map((rows) => rows.map(_rowToSecurityLog).toList());
  }


  /// Clear local security logs
  Future<void> clearSecurityLogs() async {
    await db.delete(db.securityLogs).go();
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

