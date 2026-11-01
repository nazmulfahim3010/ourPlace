import 'dart:async';
import 'dart:convert';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/media_attachment.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/conversation_sharing_service.dart';
import 'package:chatbox/services/couple_features_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/love_connection_service.dart';
import 'package:chatbox/services/media_encryption_service.dart';
import 'package:chatbox/services/media_relay_service.dart';
import 'package:chatbox/services/media_storage_service.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/services/realtime_service.dart';
import 'package:chatbox/services/sync_service.dart';
import 'package:chatbox/services/public_key_resolver.dart';

/// Abstract contract for chat messaging operations
abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String partnerId, {String? currentUserId});
  Future<List<ChatMessage>> getMessagesPaginated(
    String partnerId, {
    required int offset,
    required int limit,
    String? currentUserId,
  });
  Stream<List<ChatMessage>> watchMessages(String partnerId, {String? currentUserId});
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

  // Phase 14 Push Notifications additions
  NotificationService get notificationService;

  // Phase 15 Media Messaging additions
  MediaRelayService get mediaRelayService;
  MediaStorageService get mediaStorageService;
  MediaEncryptionService get mediaEncryptionService;
  Future<void> sendMediaMessage(ChatMessage message, List<int> mediaBytes);

  // Phase 16 Love Connection additions
  LoveConnectionService get loveConnectionService;

  // Phase 17 One-Time Love Code & Conversation Sharing additions
  ConversationSharingService get conversationSharingService;

  // Phase 18 Couple-Specific Features additions
  CoupleFeaturesService get coupleFeaturesService;

  // Active Relay Inbound Listener controls
  void startRelayListener(String currentUserId);
  void stopRelayListener();
}

/// Primary implementation coordinating local SQLite storage, E2EE, and chat transport
class LocalChatRepository implements ChatRepository {
  final LocalDatabase _database;
  final ChatService _chatService;
  final EncryptionService? _encryptionService;
  final SyncService _syncService;
  final RealtimeService _realtimeService;
  final NotificationService _notificationService;
  final MediaRelayService _mediaRelayService;
  final MediaStorageService _mediaStorageService;
  final MediaEncryptionService _mediaEncryptionService;
  final LoveConnectionService _loveConnectionService;
  final ConversationSharingService _conversationSharingService;
  final CoupleFeaturesService _coupleFeaturesService;

  /// Resolves every dependency exactly once so the sync service, the repository
  /// and the sharing service all operate on the same service instances.
  factory LocalChatRepository({
    LocalDatabase? database,
    ChatService? chatService,
    EncryptionService? encryptionService,
    SyncService? syncService,
    RealtimeService? realtimeService,
    NotificationService? notificationService,
    MediaRelayService? mediaRelayService,
    MediaStorageService? mediaStorageService,
    MediaEncryptionService? mediaEncryptionService,
    LoveConnectionService? loveConnectionService,
    ConversationSharingService? conversationSharingService,
    CoupleFeaturesService? coupleFeaturesService,
    ConversationRepository? conversationRepository,
  }) {
    final db = database ?? LocalDatabase();
    final chat = chatService ?? ChatService();
    final enc = encryptionService ?? StandardE2EEEncryptionService.instance;
    final notifications = notificationService ?? DefaultNotificationService();
    final mediaRelay = mediaRelayService ?? DefaultMediaRelayService();
    final mediaStorage = mediaStorageService ?? DefaultMediaStorageService();
    final mediaEncryption = mediaEncryptionService ?? StandardMediaEncryptionService();
    final love = loveConnectionService ??
        DefaultLoveConnectionService(
          database: db,
          relayService: chat.relayService,
          conversationRepository: conversationRepository ??
              LocalConversationRepository(database: database),
        );
    final sharing = conversationSharingService ??
        DefaultConversationSharingService(
          relayService: chat.relayService,
          encryptionService: enc,
          localDatabase: db,
          loveConnectionService: love,
        );
    final couple = coupleFeaturesService ??
        DefaultCoupleFeaturesService(
          localDatabase: db,
          relayService: chat.relayService,
          encryptionService: enc,
        );
    final sync = syncService ??
        DefaultSyncService(
          database: db,
          chatService: chat,
          encryptionService: enc,
          notificationService: notifications,
          mediaRelayService: mediaRelay,
          mediaStorageService: mediaStorage,
          mediaEncryptionService: mediaEncryption,
          loveConnectionService: love,
          conversationSharingService: sharing,
          coupleFeaturesService: couple,
        );
    final realtime = realtimeService ?? DefaultRealtimeService(chatService: chat);

    return LocalChatRepository._(
      database: db,
      chatService: chat,
      encryptionService: enc,
      syncService: sync,
      realtimeService: realtime,
      notificationService: notifications,
      mediaRelayService: mediaRelay,
      mediaStorageService: mediaStorage,
      mediaEncryptionService: mediaEncryption,
      loveConnectionService: love,
      conversationSharingService: sharing,
      coupleFeaturesService: couple,
    );
  }

  LocalChatRepository._({
    required LocalDatabase database,
    required ChatService chatService,
    required EncryptionService? encryptionService,
    required SyncService syncService,
    required RealtimeService realtimeService,
    required NotificationService notificationService,
    required MediaRelayService mediaRelayService,
    required MediaStorageService mediaStorageService,
    required MediaEncryptionService mediaEncryptionService,
    required LoveConnectionService loveConnectionService,
    required ConversationSharingService conversationSharingService,
    required CoupleFeaturesService coupleFeaturesService,
  })  : _database = database,
        _chatService = chatService,
        _encryptionService = encryptionService,
        _syncService = syncService,
        _realtimeService = realtimeService,
        _notificationService = notificationService,
        _mediaRelayService = mediaRelayService,
        _mediaStorageService = mediaStorageService,
        _mediaEncryptionService = mediaEncryptionService,
        _loveConnectionService = loveConnectionService,
        _conversationSharingService = conversationSharingService,
        _coupleFeaturesService = coupleFeaturesService;

  @override
  CoupleFeaturesService get coupleFeaturesService => _coupleFeaturesService;

  @override
  ConversationSharingService get conversationSharingService => _conversationSharingService;

  @override
  LoveConnectionService get loveConnectionService => _loveConnectionService;

  @override
  SyncService get syncService => _syncService;

  @override
  RealtimeService get realtimeService => _realtimeService;

  @override
  NotificationService get notificationService => _notificationService;

  @override
  MediaRelayService get mediaRelayService => _mediaRelayService;

  @override
  MediaStorageService get mediaStorageService => _mediaStorageService;

  @override
  MediaEncryptionService get mediaEncryptionService => _mediaEncryptionService;

  @override
  void startRelayListener(String currentUserId) {
    _syncService.startRelayListener(currentUserId: currentUserId);
  }

  @override
  void stopRelayListener() {
    _syncService.stopRelayListener();
  }

  /// Resolves the X25519 public identity key for a target recipient.
  /// Priority:
  /// 1. Local user account (for multi-account simulation/test)
  /// 2. Active Love Connection partner public key
  /// 3. Global Firebase User Directory lookup
  Future<String?> resolveRecipientPublicKey(String recipientUsername) =>
      PublicKeyResolver(database: _database).resolve(recipientUsername);

  @override
  Future<List<ChatMessage>> getMessages(String partnerId, {String? currentUserId}) {
    return _database.getMessagesForPartner(partnerId, currentUserId: currentUserId);
  }

  @override
  Future<List<ChatMessage>> getMessagesPaginated(
    String partnerId, {
    required int offset,
    required int limit,
    String? currentUserId,
  }) {
    return _database.getMessagesForPartnerPaginated(
      partnerId,
      offset: offset,
      limit: limit,
      currentUserId: currentUserId,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String partnerId, {String? currentUserId}) {
    return _database.watchMessagesForPartner(partnerId, currentUserId: currentUserId);
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
      final recipientKey = await resolveRecipientPublicKey(initial.recipientId);
      if (recipientKey == null || recipientKey.isEmpty) {
        await _database.updateMessageStatus(message.id, MessageStatus.failed);
        throw SecurityException(
          'Recipient ${initial.recipientId} has not registered on Nest yet. Ask them to create an account first.',
        );
      }
      final String payload;
      if (initial.mediaAttachment != null) {
        payload = jsonEncode({
          'text': initial.text,
          'mediaAttachment': initial.mediaAttachment!.toJson(),
        });
      } else {
        payload = initial.text;
      }
      final ciphertext = await enc.encryptPayload(
        payload,
        recipientKey,
      );
      outboundMessage = initial.copyWith(text: ciphertext);
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
    } finally {
      try {
        LocalConversationRepository.instance
            .refreshConversations(currentUserId: message.senderId);
      } catch (_) {}
    }
  }

  @override
  Future<void> sendMediaMessage(ChatMessage message, List<int> mediaBytes) async {
    final att = message.mediaAttachment;
    if (att == null) {
      return sendMessage(message);
    }

    // Fail before uploading anything if the recipient cannot be encrypted for
    if (_encryptionService != null) {
      final recipientKey = await resolveRecipientPublicKey(message.recipientId);
      if (recipientKey == null || recipientKey.isEmpty) {
        throw SecurityException(
          'Recipient ${message.recipientId} has not registered on Nest yet. Ask them to create an account first.',
        );
      }
    }

    // 1. Save plaintext media to local sandboxed storage
    final localPath = await _mediaStorageService.saveToSandbox(
      fileName: att.fileName,
      bytes: mediaBytes,
      type: att.type,
    );

    // 2. Encrypt with a per-file key; the key travels only inside the
    //    E2EE-encrypted message payload, never alongside the blob
    final sealed = await _mediaEncryptionService.sealForTransport(
      rawBytes: mediaBytes,
      attachment: att,
    );

    // 3. Upload only the ciphertext to the ephemeral relay
    final blobId = 'blob_${message.id}_${DateTime.now().millisecondsSinceEpoch}';
    final remoteUrl =
        await _mediaRelayService.uploadEncryptedBlob(blobId, sealed.encryptedBytes);

    // 4. Update attachment descriptor with localPath, remoteUrl and media key
    final resolvedAttachment = sealed.attachment.copyWith(
      localPath: localPath,
      remoteUrl: remoteUrl,
    );

    final resolvedMessage = message.copyWith(
      mediaAttachment: resolvedAttachment,
      type: att.type,
    );

    // 5. Dispatch through regular E2EE sendMessage flow
    await sendMessage(resolvedMessage);
  }

  @override
  Future<ChatMessage> processIncomingMessage(ChatMessage rawMessage) async {
    ChatMessage decryptedMessage = rawMessage;
    final enc = _encryptionService;
    if (enc != null) {
      // Only a trusted key for the claimed sender may authenticate the
      // message; the key embedded in the envelope is attacker-controlled.
      final senderKey = await resolveRecipientPublicKey(rawMessage.senderId);
      String? cleartext;
      if (senderKey != null && senderKey.isNotEmpty) {
        try {
          cleartext = await enc.decryptPayload(rawMessage.text, senderKey);
        } catch (_) {}
      }

      if (cleartext == null) {
        decryptedMessage =
            rawMessage.copyWith(text: DefaultSyncService.undecryptableMessageText);
      } else {
        decryptedMessage = rawMessage.copyWith(text: cleartext);
        try {
          final decoded = jsonDecode(cleartext);
          if (decoded is Map<String, dynamic> && decoded.containsKey('mediaAttachment')) {
            final mediaMap = decoded['mediaAttachment'] as Map<String, dynamic>;
            final att = MediaAttachment.fromJson(mediaMap);
            final text = decoded['text'] as String? ?? '';
            decryptedMessage = rawMessage.copyWith(
              text: text,
              type: att.type,
              mediaAttachment: att,
            );
          }
        } catch (_) {}
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
    // Route through the sync service so every inbound path shares the same
    // decryption, sender verification and de-duplication rules.
    await for (final envelopes
        in _chatService.watchPendingRelayEnvelopes(currentUserId)) {
      if (envelopes.isEmpty) continue;
      final processed =
          await _syncService.processInboundEnvelopes(currentUserId: currentUserId);
      for (final message in processed) {
        yield message;
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

