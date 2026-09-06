import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/chat_service.dart';

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
  Future<bool> updateMessageStatus(String messageId, MessageStatus status);
  Future<bool> deleteMessage(String messageId);
  Future<List<ChatMessage>> searchMessages(String partnerId, String query);
  Future<void> clearConversation(String partnerId);
  Future<int> getMessageCount(String partnerId);
  Future<void> seedInitialMessages(List<ChatMessage> initialMessages);
}

/// Primary implementation coordinating local SQLite storage and chat transport
class LocalChatRepository implements ChatRepository {
  final LocalDatabase _database;
  final ChatService _chatService;

  LocalChatRepository({
    LocalDatabase? database,
    ChatService? chatService,
  })  : _database = database ?? LocalDatabase(),
        _chatService = chatService ?? ChatService();

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
    // 1. Immediately persist locally (local-first truth)
    await _database.saveMessage(message);

    // 2. Dispatch via transport service (Phase 9 Relay)
    await _chatService.sendMessage(message);
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
