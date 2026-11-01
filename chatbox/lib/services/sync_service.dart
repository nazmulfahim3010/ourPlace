import 'dart:async';
import 'dart:convert';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/encrypted_payload.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/love_note.dart';
import 'package:chatbox/models/media_attachment.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/conversation_sharing_service.dart';
import 'package:chatbox/services/couple_features_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/love_connection_service.dart';
import 'package:chatbox/services/media_encryption_service.dart';
import 'package:chatbox/services/media_relay_service.dart';
import 'package:chatbox/services/media_storage_service.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/services/user_directory_service.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:flutter/foundation.dart';

/// Abstract service contract for message synchronization and offline queueing (Phase 12)
abstract class SyncService {
  /// Whether the network connectivity is active
  bool get isOnline;

  /// Update online state (supports live connectivity monitoring and test simulation)
  void setOnline(bool online);

  /// Drain and flush all unsent / failed messages queued offline
  Future<int> flushOutboundQueue({required String currentUserId});

  /// Pull and process incoming messages and delivery/read receipts from the ephemeral relay
  Future<List<ChatMessage>> processInboundEnvelopes({required String currentUserId});

  /// Dispatch an ephemeral delivery receipt back to the original sender
  Future<void> sendDeliveryReceipt({
    required String messageId,
    required String recipientId,
    required String senderId,
  });

  /// Dispatch an ephemeral read receipt back to the original sender
  Future<void> sendReadReceipt({
    required String messageId,
    required String recipientId,
    required String senderId,
  });

  /// Perform bidirectional synchronization: drain inbound queue then flush outbound queue
  Future<void> reconcile({required String currentUserId});

  /// Manually retry sending an individual failed message
  Future<bool> retryMessage(String messageId, {required String currentUserId});

  /// Mark all incoming messages from partner as read and dispatch read receipts
  Future<int> markConversationAsRead(String partnerId, {required String currentUserId});

  /// Begin continuous reactive listening to incoming relay envelopes
  void startRelayListener({required String currentUserId});

  /// Stop reactive listening to incoming relay envelopes
  void stopRelayListener();
}

/// Primary implementation of [SyncService] coordinating SQLite and the ephemeral relay
class DefaultSyncService implements SyncService {
  final LocalDatabase _database;
  final ChatService _chatService;
  final EncryptionService? _encryptionService;
  final NotificationService? _notificationService;
  final MediaRelayService? _mediaRelayService;
  final MediaStorageService? _mediaStorageService;
  final MediaEncryptionService? _mediaEncryptionService;
  final LoveConnectionService? _loveConnectionService;
  final ConversationSharingService? _conversationSharingService;
  final CoupleFeaturesService? _coupleFeaturesService;

  bool _isOnline = true;

  DefaultSyncService({
    LocalDatabase? database,
    ChatService? chatService,
    EncryptionService? encryptionService,
    NotificationService? notificationService,
    MediaRelayService? mediaRelayService,
    MediaStorageService? mediaStorageService,
    MediaEncryptionService? mediaEncryptionService,
    LoveConnectionService? loveConnectionService,
    ConversationSharingService? conversationSharingService,
    CoupleFeaturesService? coupleFeaturesService,
  })  : _database = database ?? LocalDatabase(),
        _chatService = chatService ?? ChatService(),
        _encryptionService =
            encryptionService ?? StandardE2EEEncryptionService.instance,
        _notificationService = notificationService,
        _mediaRelayService = mediaRelayService,
        _mediaStorageService = mediaStorageService,
        _mediaEncryptionService = mediaEncryptionService,
        _loveConnectionService = loveConnectionService,
        _conversationSharingService = conversationSharingService,
        _coupleFeaturesService = coupleFeaturesService;

  CoupleFeaturesService? get coupleFeaturesService => _coupleFeaturesService;
  LoveConnectionService? get loveConnectionService => _loveConnectionService;
  ConversationSharingService? get conversationSharingService => _conversationSharingService;
  MediaEncryptionService? get mediaEncryptionService => _mediaEncryptionService;
  MediaRelayService? get mediaRelayService => _mediaRelayService;
  MediaStorageService? get mediaStorageService => _mediaStorageService;

  StreamSubscription<List<EphemeralRelayEnvelope>>? _relaySubscription;
  Timer? _pollingTimer;
  String? _listeningUserId;

  @override
  void startRelayListener({required String currentUserId}) {
    if (_listeningUserId == currentUserId &&
        (_relaySubscription != null || _pollingTimer != null)) {
      return;
    }
    stopRelayListener();
    _listeningUserId = currentUserId;

    // 1. Reactive stream (on platforms where Firebase native socket is active)
    try {
      _relaySubscription = _chatService
          .watchPendingRelayEnvelopes(currentUserId)
          .listen((envelopes) async {
        if (envelopes.isNotEmpty) {
          await processInboundEnvelopes(currentUserId: currentUserId);
        }
      }, onError: (e) {
        debugPrint('DefaultSyncService relay stream notice: $e');
      });
    } catch (e) {
      debugPrint('DefaultSyncService stream init notice: $e');
    }

    // 2. Continuous 3-second polling timer for cross-platform and desktop reliability
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await processInboundEnvelopes(currentUserId: currentUserId);
      } catch (_) {}
    });

    // 3. Initial sync
    processInboundEnvelopes(currentUserId: currentUserId).ignore();
  }

  @override
  void stopRelayListener() {
    _relaySubscription?.cancel();
    _relaySubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _listeningUserId = null;
  }

  Future<String?> _resolveRecipientPublicKey(String username) async {
    final normUsername = HashUtils.normalizeUsername(username);
    final account = await _database.getAccountByUsername(username) ??
        await _database.getAccountByUsername(normUsername);
    if (account?.publicIdentityKey != null && account!.publicIdentityKey!.isNotEmpty) {
      return account.publicIdentityKey;
    }

    try {
      final loveConn = await _loveConnectionService?.getLoveConnection();
      if (loveConn != null &&
          loveConn.partnerPublicKey != null &&
          loveConn.partnerPublicKey!.isNotEmpty) {
        final normPartner = HashUtils.normalizeUsername(loveConn.partnerUsername);
        if (normPartner == normUsername) {
          return loveConn.partnerPublicKey;
        }
      }
    } catch (_) {}

    try {
      final profile = await DefaultUserDirectoryService().lookupProfile(username) ??
          await DefaultUserDirectoryService().lookupProfile(normUsername);
      if (profile?.publicIdentityKey != null && profile!.publicIdentityKey.isNotEmpty) {
        return profile.publicIdentityKey;
      }
    } catch (_) {}

    return null;
  }

  @override
  bool get isOnline => _isOnline;

  @override
  void setOnline(bool online) {
    _isOnline = online;
  }

  @override
  Future<int> flushOutboundQueue({required String currentUserId}) async {
    if (!_isOnline) return 0;

    final unsent = await _database.getUnsentMessages(currentUserId: currentUserId);
    int flushedCount = 0;

    for (final message in unsent) {
      final success = await _dispatchOutboundMessage(message);
      if (success) {
        flushedCount++;
      }
    }

    return flushedCount;
  }

  Future<bool> _dispatchOutboundMessage(ChatMessage message) async {
    if (!_isOnline) {
      await _database.updateMessageStatus(message.id, MessageStatus.failed);
      return false;
    }

    try {
      ChatMessage outbound = message;
      final enc = _encryptionService;
      if (enc != null) {
        final recipientKey = await _resolveRecipientPublicKey(message.recipientId);
        if (recipientKey != null && recipientKey.isNotEmpty) {
          final String payload;
          if (message.mediaAttachment != null) {
            payload = jsonEncode({
              'text': message.text,
              'mediaAttachment': message.mediaAttachment!.toJson(),
            });
          } else {
            payload = message.text;
          }
          final ciphertext = await enc.encryptPayload(payload, recipientKey);
          outbound = message.copyWith(text: ciphertext);
        }
      }

      await _chatService.sendMessage(outbound);
      await _database.updateMessageStatusIfProgressing(message.id, MessageStatus.sent);
      return true;
    } catch (_) {
      await _database.updateMessageStatus(message.id, MessageStatus.failed);
      return false;
    }
  }

  /// Drain currently in progress; concurrent callers share it instead of
  /// fetching (and handling) the same envelopes a second time.
  Future<List<ChatMessage>>? _inboundInFlight;
  String? _inboundInFlightUserId;
  bool _inboundRerunRequested = false;

  /// Envelope IDs already handled recently, guarding against stale snapshots
  /// that still contain an envelope we have just acknowledged.
  final Set<String> _recentlyHandledIds = <String>{};
  final List<String> _recentlyHandledOrder = <String>[];
  static const int _recentlyHandledCapacity = 500;

  /// Consecutive processing failures per envelope ID (poison-message guard).
  final Map<String, int> _inboundFailureCounts = <String, int>{};
  static const int _maxInboundAttempts = 5;

  @override
  Future<List<ChatMessage>> processInboundEnvelopes({required String currentUserId}) {
    if (!_isOnline) return Future.value(const []);

    final inFlight = _inboundInFlight;
    if (inFlight != null && _inboundInFlightUserId == currentUserId) {
      // New envelopes may have landed after the running drain fetched its batch
      _inboundRerunRequested = true;
      return inFlight;
    }

    _inboundInFlightUserId = currentUserId;
    final drain = _drainInboundEnvelopes(currentUserId: currentUserId);
    _inboundInFlight = drain;
    drain.whenComplete(() {
      if (!identical(_inboundInFlight, drain)) return;
      _inboundInFlight = null;
      _inboundInFlightUserId = null;
      if (_inboundRerunRequested) {
        _inboundRerunRequested = false;
        processInboundEnvelopes(currentUserId: currentUserId).ignore();
      }
    }).ignore();
    return drain;
  }

  void _rememberHandled(String envelopeId) {
    _inboundFailureCounts.remove(envelopeId);
    if (_recentlyHandledIds.add(envelopeId)) {
      _recentlyHandledOrder.add(envelopeId);
      if (_recentlyHandledOrder.length > _recentlyHandledCapacity) {
        _recentlyHandledIds.remove(_recentlyHandledOrder.removeAt(0));
      }
    }
  }

  Future<void> _retryPurge(String envelopeId, String currentUserId) async {
    try {
      await _chatService.acknowledgeAndPurge(envelopeId, recipientId: currentUserId);
    } catch (_) {}
  }

  Future<List<ChatMessage>> _drainInboundEnvelopes({required String currentUserId}) async {
    final envelopes = await _chatService.fetchPendingRelayEnvelopes(currentUserId);
    final processedMessages = <ChatMessage>[];

    for (final envelope in envelopes) {
      // Typing / presence signals are owned and purged by RealtimeService
      if (envelope.isTypingSignal || envelope.isPresenceSignal) continue;

      if (_recentlyHandledIds.contains(envelope.id)) {
        // Already handled; a previous purge must have failed, so retry it
        _retryPurge(envelope.id, currentUserId).ignore();
        continue;
      }

      try {
        final message = await _handleInboundEnvelope(
          envelope,
          currentUserId: currentUserId,
        );
        if (message != null) processedMessages.add(message);
        _rememberHandled(envelope.id);
      } catch (e) {
        final attempts = (_inboundFailureCounts[envelope.id] ?? 0) + 1;
        _inboundFailureCounts[envelope.id] = attempts;
        debugPrint(
          'DefaultSyncService: failed to process envelope ${envelope.id} '
          '(${envelope.envelopeType}), attempt $attempts/$_maxInboundAttempts: $e',
        );
        if (attempts >= _maxInboundAttempts) {
          // Drop the poison envelope so it cannot block the queue forever
          _rememberHandled(envelope.id);
          try {
            await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
          } catch (_) {}
        }
      }
    }

    if (processedMessages.isNotEmpty) {
      try {
        LocalConversationRepository.instance
            .refreshConversations(currentUserId: currentUserId);
      } catch (_) {}
    }

    return processedMessages;
  }

  /// Handle a single inbound envelope. Returns the persisted chat message for
  /// standard messages, or null for control signals. Throws on failure, in
  /// which case the envelope is left in the relay for a later retry.
  Future<ChatMessage?> _handleInboundEnvelope(
    EphemeralRelayEnvelope envelope, {
    required String currentUserId,
  }) async {
    {
      if (envelope.isLoveConnectionSignal) {
        if (_loveConnectionService != null) {
          await _loveConnectionService.processInboundLoveEnvelope(
            envelope,
            currentUserId: currentUserId,
            currentUsername: currentUserId,
          );
        }
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isLoveShareSignal) {
        if (_conversationSharingService != null) {
          await _conversationSharingService.handleInboundEnvelope(envelope);
        }
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isLoveLuvSignal) {
        if (_coupleFeaturesService != null) {
          _coupleFeaturesService.emitLuvBurst(envelope.senderId);
        }
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isReactionSignal) {
        if (_coupleFeaturesService != null) {
          try {
            final data = jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
            await _coupleFeaturesService.handleInboundReaction(
              messageId: data['message_id'] as String,
              senderUsername: data['sender_username'] as String? ?? envelope.senderId,
              emoji: data['emoji'] as String,
              isRemove: data['is_remove'] as bool? ?? false,
            );
          } catch (_) {}
        }
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isLoveNoteSignal) {
        if (_coupleFeaturesService != null) {
          try {
            final data = jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
            final note = LoveNote.fromJson(data);
            await _coupleFeaturesService.handleInboundLoveNote(note);
          } catch (_) {}
        }
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isDeliveryReceipt) {
        // Handle delivery receipt
        await _database.updateMessageStatusIfProgressing(
          envelope.targetMessageId,
          MessageStatus.delivered,
        );
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else if (envelope.isReadReceipt) {
        // Handle read receipt
        await _database.updateMessageStatusIfProgressing(
          envelope.targetMessageId,
          MessageStatus.read,
        );
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);
      } else {
        // Standard incoming message
        final raw = ChatMessage(
          id: envelope.id,
          senderId: envelope.senderId,
          recipientId: envelope.recipientId,
          text: envelope.ciphertextPayload,
          timestamp: envelope.timestamp,
          status: MessageStatus.delivered,
        );

        ChatMessage decryptedMessage = raw;
        final enc = _encryptionService;
        if (enc != null) {
          try {
            final senderAccount =
                await _database.getAccountByUsername(raw.senderId);
            String senderKey = senderAccount?.publicIdentityKey ?? '';
            if (senderKey.isEmpty) {
              senderKey = (await _resolveRecipientPublicKey(raw.senderId)) ?? '';
            }
            if (senderKey.isEmpty) {
              try {
                final ep = EncryptedPayload.deserialize(raw.text);
                senderKey = ep.senderPublicKey;
              } catch (_) {}
            }
            final cleartext = await enc.decryptPayload(raw.text, senderKey);
            try {
              final decoded = jsonDecode(cleartext);
              if (decoded is Map<String, dynamic> && decoded.containsKey('mediaAttachment')) {
                final mediaMap = decoded['mediaAttachment'] as Map<String, dynamic>;
                var att = MediaAttachment.fromJson(mediaMap);
                final text = decoded['text'] as String? ?? '';

                // If media blob is in relay, download and purge from cloud
                final relay = _mediaRelayService;
                final storage = _mediaStorageService;
                if (att.remoteUrl != null && relay != null) {
                  try {
                    final blob = await relay.downloadEncryptedBlob(att.remoteUrl!);
                    if (storage != null) {
                      final localPath = await storage.saveToSandbox(
                        fileName: att.fileName,
                        bytes: blob,
                        type: att.type,
                      );
                      att = att.copyWith(localPath: localPath);
                    }
                    await relay.purgeEncryptedBlob(att.remoteUrl!);
                  } catch (_) {}
                }

                decryptedMessage = raw.copyWith(
                  text: text,
                  type: att.type,
                  mediaAttachment: att,
                );
              } else {
                decryptedMessage = raw.copyWith(text: cleartext);
              }
            } catch (_) {
              decryptedMessage = raw.copyWith(text: cleartext);
            }
          } catch (_) {
            // Decryption fallback
          }
        }

        // Persist cleartext locally (local device owns history)
        await _database.saveMessage(decryptedMessage);

        // Acknowledge and purge ciphertext from remote relay
        await _chatService.acknowledgeAndPurge(envelope.id, recipientId: currentUserId);

        // Notify user locally using privacy-preserving settings (zero leak).
        // The message is already stored, so a notification failure must not
        // cause the envelope to be reprocessed.
        try {
          await _notificationService?.showLocalAlert(
            title: decryptedMessage.senderId,
            body: decryptedMessage.mediaAttachment != null
                ? (decryptedMessage.mediaAttachment!.isImage
                    ? '📷 Photo'
                    : decryptedMessage.mediaAttachment!.isAudio
                        ? '🎙️ Voice note'
                        : '🎥 Video')
                : decryptedMessage.text,
            conversationId: decryptedMessage.senderId,
          );
        } catch (e) {
          debugPrint('DefaultSyncService: local alert notice: $e');
        }

        // Dispatch ephemeral delivery receipt back to original sender
        // (best effort: a receipt failure must not block ingestion)
        sendDeliveryReceipt(
          messageId: envelope.id,
          recipientId: envelope.senderId,
          senderId: currentUserId,
        ).catchError((Object e) {
          debugPrint('DefaultSyncService: delivery receipt notice: $e');
        }).ignore();

        return decryptedMessage;
      }
    }

    return null;
  }

  @override
  Future<void> sendDeliveryReceipt({
    required String messageId,
    required String recipientId,
    required String senderId,
  }) async {
    final receipt = EphemeralRelayEnvelope.deliveryReceipt(
      messageId: messageId,
      senderId: senderId,
      recipientId: recipientId,
    );
    await _chatService.sendEphemeralEnvelope(receipt);
  }

  @override
  Future<void> sendReadReceipt({
    required String messageId,
    required String recipientId,
    required String senderId,
  }) async {
    final receipt = EphemeralRelayEnvelope.readReceipt(
      messageId: messageId,
      senderId: senderId,
      recipientId: recipientId,
    );
    await _chatService.sendEphemeralEnvelope(receipt);
  }

  @override
  Future<void> reconcile({required String currentUserId}) async {
    if (!_isOnline) return;

    // 1. Process all pending inbound messages and receipts
    await processInboundEnvelopes(currentUserId: currentUserId);

    // 2. Flush any pending outbound messages queued while offline
    await flushOutboundQueue(currentUserId: currentUserId);
  }

  @override
  Future<bool> retryMessage(String messageId, {required String currentUserId}) async {
    final message = await _database.getMessageById(messageId);
    if (message == null) return false;

    // Reset status to sending before attempt
    await _database.updateMessageStatus(messageId, MessageStatus.sending);
    return await _dispatchOutboundMessage(message);
  }

  @override
  Future<int> markConversationAsRead(
    String partnerId, {
    required String currentUserId,
  }) async {
    final unreadMessages = await _database.getMessagesForPartner(
      partnerId,
      currentUserId: currentUserId,
    );

    // Update local database
    final count = await _database.markConversationAsRead(
      partnerId,
      currentUserId: currentUserId,
    );

    // Send read receipts for incoming messages that weren't already read
    for (final msg in unreadMessages) {
      if (msg.senderId == partnerId && msg.status != MessageStatus.read) {
        await sendReadReceipt(
          messageId: msg.id,
          recipientId: partnerId,
          senderId: currentUserId,
        );
      }
    }

    return count;
  }
}
