import 'dart:async';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/encrypted_payload.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/realtime_service.dart';
import 'package:chatbox/services/sync_service.dart';

/// Abstract contract for chat messaging operations
abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String partnerId);
  Future<List<ChatMessage>> getMessagesPaginated(
    String partnerId, {
    required int offset,
    required int limit,
  });
  Stream<List<ChatMessage>> watchMessages(String partnerId);
  Future<void> sendMessage(ChatMessage message);
  Future<ChatMessage> processIncomingMessage(ChatMessage rawMessage);
  Future<List<ChatMessage>> syncPendingRelayMessages(String currentUserId);
  Stream<ChatMessage> listenToIncomingRelayMessages(String currentUserId);
  Future<bool> updateMessageStatus(String messageId, MessageStatus status);
  Future<bool> deleteMessage(String messageId);
  Future<List<ChatMessage>> searchMessages(String partnerId, String query);
  Future<void> clearConversation(String partnerId);
  Future<int> getMessageCount(String partnerId);
  Future<void> seedInitialMessages(List<ChatMessage> initialMessages);

  // Phase 12 Message Synchronization additions
  Future<bool> retryMessage(String messageId, {required String currentUserId});
  Future<int> markConversationAsRead(String partnerId, {required String currentUserId});
  Future<void> reconcile({required String currentUserId});
  SyncService get syncService;

  // Phase 13 Real-Time Features additions
  RealtimeService get realtimeService;
}

/// Primary implementation coordinating local SQLite storage, E2EE, and chat transport
class LocalChatRepository implements ChatRepository {
  final LocalDatabase _database;
  final ChatService _chatService;
  final EncryptionService? _encryptionService;
  final SyncService _syncService;
  final RealtimeService _realtimeService;

  LocalChatRepository({
    LocalDatabase? database,
    ChatService? chatService,
    EncryptionService? encryptionService,
    SyncService? syncService,
    RealtimeService? realtimeService,
  })  : _database = database ?? LocalDatabase(),
        _chatService = chatService ?? ChatService(),
        _encryptionService = encryptionService,
        _syncService = syncService ??
            DefaultSyncService(
              database: database ?? LocalDatabase(),
              chatService: chatService ?? ChatService(),
              encryptionService: encryptionService,
            ),
        _realtimeService = realtimeService ??
            DefaultRealtimeService(
              chatService: chatService ?? ChatService(),
            );

  @override
  SyncService get syncService => _syncService;

  @override
  RealtimeService get realtimeService => _realtimeService;

  @override
  Future<List<ChatMessage>> getMessages(String partnerId) {
    return _database.getMessagesForPartner(partnerId);
  }

  @override
  Future<List<ChatMessage>> getMessagesPaginated(
    String partnerId, {
    required int offset,
    required int limit,
  }) {
    return _database.getMessagesForPartnerPaginated(
      partnerId,
      offset: offset,
      limit: limit,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String partnerId) {
    return _database.watchMessagesForPartner(partnerId);
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    // 1. Immediately persist locally in cleartext with initial 'sending' state
    final initial = message.copyWithStatus(MessageStatus.sending);
    await _database.saveMessage(initial);

    // 2. Encrypt plaintext for transport via Phase 10 E2EE
    ChatMessage outboundMessage = initial;
    final enc = _encryptionService;
    if (enc != null) {
      final recipientAccount =
          await _database.getAccountByUsername(initial.recipientId);
      final recipientKey = recipientAccount?.publicIdentityKey;
      if (recipientKey != null && recipientKey.isNotEmpty) {
        final ciphertext = await enc.encryptPayload(
          initial.text,
          recipientKey,
        );
        outboundMessage = initial.copyWith(text: ciphertext);
      }
    }

    // 3. Dispatch to temporary relay (Phase 11 Ephemeral Queue)
    try {
      if (!_syncService.isOnline) {
        throw Exception('Device is offline');
      }
      await _chatService.sendMessage(outboundMessage);
      // 4. Update local state to sent
      await _database.updateMessageStatusIfProgressing(message.id, MessageStatus.sent);
    } catch (_) {
      // 5. If dispatch fails or offline, update to failed for offline retry
      await _database.updateMessageStatus(message.id, MessageStatus.failed);
    }
  }

  @override
  Future<ChatMessage> processIncomingMessage(ChatMessage rawMessage) async {
    ChatMessage decryptedMessage = rawMessage;
    final enc = _encryptionService;
    if (enc != null) {
      try {
        final senderAccount =
            await _database.getAccountByUsername(rawMessage.senderId);
        String senderKey = senderAccount?.publicIdentityKey ?? '';

        // If local database has not stored sender key yet, extract from envelope
        if (senderKey.isEmpty) {
          try {
            final envelope = EncryptedPayload.deserialize(rawMessage.text);
            senderKey = envelope.senderPublicKey;
          } catch (_) {}
        }

        final cleartext = await enc.decryptPayload(
          rawMessage.text,
          senderKey,
        );
        decryptedMessage = rawMessage.copyWith(text: cleartext);
      } catch (_) {
        // Fallback to raw text if decryption fails or message is unencrypted
      }
    }

    await _database.saveMessage(decryptedMessage);
    return decryptedMessage;
  }

  @override
  Future<List<ChatMessage>> syncPendingRelayMessages(
      String currentUserId) async {
    return _syncService.processInboundEnvelopes(currentUserId: currentUserId);
  }

  @override
  Stream<ChatMessage> listenToIncomingRelayMessages(
      String currentUserId) async* {
    final seenIds = <String>{};

    await for (final envelopes
        in _chatService.watchPendingRelayEnvelopes(currentUserId)) {
      for (final envelope in envelopes) {
        if (!seenIds.contains(envelope.id)) {
          seenIds.add(envelope.id);

          if (envelope.isDeliveryReceipt) {
            await _database.updateMessageStatusIfProgressing(
              envelope.targetMessageId,
              MessageStatus.delivered,
            );
            await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
            continue;
          }

          if (envelope.isReadReceipt) {
            await _database.updateMessageStatusIfProgressing(
              envelope.targetMessageId,
              MessageStatus.read,
            );
            await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
            continue;
          }

          final raw = ChatMessage(
            id: envelope.id,
            senderId: envelope.senderId,
            recipientId: envelope.recipientId,
            text: envelope.ciphertextPayload,
            timestamp: envelope.timestamp,
            status: MessageStatus.delivered,
          );

          final decrypted = await processIncomingMessage(raw);

          // Acknowledge and purge immediately
          await _chatService.acknowledgeAndPurge(envelope.id,
              recipientId: currentUserId);

          // Emit delivery receipt
          await _syncService.sendDeliveryReceipt(
            messageId: envelope.id,
            recipientId: envelope.senderId,
            senderId: currentUserId,
          );

          yield decrypted;
        }
      }
    }
  }

  @override
  Future<bool> retryMessage(String messageId, {required String currentUserId}) {
    return _syncService.retryMessage(messageId, currentUserId: currentUserId);
  }

  @override
  Future<int> markConversationAsRead(String partnerId, {required String currentUserId}) {
    return _syncService.markConversationAsRead(partnerId, currentUserId: currentUserId);
  }

  @override
  Future<void> reconcile({required String currentUserId}) {
    return _syncService.reconcile(currentUserId: currentUserId);
  }

  @override
  Future<bool> updateMessageStatus(String messageId, MessageStatus status) {
    return _database.updateMessageStatus(messageId, status);
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    final localDeleted = await _database.deleteMessage(messageId);
    await _chatService.deleteMessage(messageId: messageId);
    return localDeleted;
  }

  @override
  Future<List<ChatMessage>> searchMessages(String partnerId, String query) {
    return _database.searchMessages(partnerId: partnerId, query: query);
  }

  @override
  Future<void> clearConversation(String partnerId) {
    return _database.clearMessagesForPartner(partnerId);
  }

  @override
  Future<int> getMessageCount(String partnerId) {
    return _database.getMessageCountForPartner(partnerId);
  }

  @override
  Future<void> seedInitialMessages(List<ChatMessage> initialMessages) {
    return _database.saveMessages(initialMessages);
  }
}

