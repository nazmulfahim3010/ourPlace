import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/relay_service.dart';

/// Service class coordinating chat operations and ephemeral transport relays (Phase 11)
class ChatService {
  final RelayService _relayService;

  static ChatService? _defaultInstance;

  /// Shared application instance backed by [InMemoryFirebaseRelayService]
  static ChatService get instance => _defaultInstance ??= ChatService();

  /// Default constructor allowing injection of custom [RelayService] (for tests/environments)
  ChatService({RelayService? relayService})
      : _relayService = relayService ?? InMemoryFirebaseRelayService.instance;

  /// Factory constructor returning the singleton instance for backward compatibility
  factory ChatService.singleton() => instance;

  /// Active relay service instance
  RelayService get relayService => _relayService;

  /// Enqueue an encrypted envelope directly to the temporary relay
  Future<void> sendEphemeralEnvelope(EphemeralRelayEnvelope envelope) async {
    await _relayService.enqueueMessage(envelope);
  }

  /// Send a message through the ephemeral transport relay
  Future<ChatMessage> sendMessage(ChatMessage message) async {
    // Wrap message into an ephemeral relay envelope
    final envelope = EphemeralRelayEnvelope.create(
      id: message.id,
      senderId: message.senderId,
      recipientId: message.recipientId,
      ciphertextPayload: message.text,
      timestamp: message.timestamp,
    );

    await _relayService.enqueueMessage(envelope);
    return message;
  }

  /// Pull all pending unacknowledged envelopes targeting [recipientId]
  Future<List<EphemeralRelayEnvelope>> fetchPendingRelayEnvelopes(
      String recipientId) {
    return _relayService.fetchPendingMessages(recipientId);
  }

  /// Stream of pending unacknowledged envelopes targeting [recipientId]
  Stream<List<EphemeralRelayEnvelope>> watchPendingRelayEnvelopes(
      String recipientId) {
    return _relayService.watchPendingMessages(recipientId);
  }

  /// Recipient delivery ACK: immediately and permanently deletes the ciphertext from the relay
  Future<bool> acknowledgeAndPurge(String messageId,
      {required String recipientId}) {
    return _relayService.acknowledgeAndPurge(messageId,
        recipientId: recipientId);
  }

  /// Fetch messages (placeholder / backward-compatible)
  Future<List<ChatMessage>> fetchMessages({
    required String partnerId,
    int limit = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }

  /// Send a "luv" emoji reaction
  Future<void> sendLuv({required String partnerId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({required String partnerId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Delete a message
  Future<bool> deleteMessage({required String messageId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  /// Edit a message
  Future<ChatMessage?> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }
}

