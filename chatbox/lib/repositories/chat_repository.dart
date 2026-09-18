import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/encryption_service.dart';

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
  Future<bool> updateMessageStatus(String messageId, MessageStatus status);
  Future<bool> deleteMessage(String messageId);
  Future<List<ChatMessage>> searchMessages(String partnerId, String query);
  Future<void> clearConversation(String partnerId);
  Future<int> getMessageCount(String partnerId);
  Future<void> seedInitialMessages(List<ChatMessage> initialMessages);
}

/// Primary implementation coordinating local SQLite storage, E2EE, and chat transport
class LocalChatRepository implements ChatRepository {
  final LocalDatabase _database;
  final ChatService _chatService;
  final EncryptionService? _encryptionService;

  LocalChatRepository({
    LocalDatabase? database,
    ChatService? chatService,
    EncryptionService? encryptionService,
  })  : _database = database ?? LocalDatabase(),
        _chatService = chatService ?? ChatService(),
        _encryptionService = encryptionService;

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
    // 1. Immediately persist locally in cleartext (local device owns conversation history)
    await _database.saveMessage(message);

    // 2. Dispatch via transport service (Phase 10 E2EE & Phase 11 Relay)
    ChatMessage outboundMessage = message;
    final enc = _encryptionService;
    if (enc != null) {
      final recipientAccount =
          await _database.getAccountByUsername(message.recipientId);
      final recipientKey = recipientAccount?.publicIdentityKey;
      if (recipientKey != null && recipientKey.isNotEmpty) {
        final ciphertext = await enc.encryptPayload(
          message.text,
          recipientKey,
        );
        outboundMessage = message.copyWith(text: ciphertext);
      }
    }

    await _chatService.sendMessage(outboundMessage);
  }

  @override
  Future<ChatMessage> processIncomingMessage(ChatMessage rawMessage) async {
    ChatMessage decryptedMessage = rawMessage;
    final enc = _encryptionService;
    if (enc != null) {
      try {
        final senderAccount =
            await _database.getAccountByUsername(rawMessage.senderId);
        final senderKey = senderAccount?.publicIdentityKey ?? '';
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
