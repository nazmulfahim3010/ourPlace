import 'dart:convert';

/// Ephemeral wire envelope representing a queued ciphertext payload in the temporary relay (Phase 11).
///
/// Under the core philosophy ("The phones own the conversation. The server only helps the phones communicate"),
/// the remote relay NEVER stores plaintext or metadata beyond what is needed to route and purge the message.
class EphemeralRelayEnvelope {
  /// Unique identifier for the message
  final String id;

  /// Normalized username of the sender (e.g. '@alex')
  final String senderId;

  /// Normalized username of the target recipient (e.g. '@twilight')
  final String recipientId;

  /// Serialized [EncryptedPayload] JSON string containing the ciphertext, nonce, and MAC tag
  final String ciphertextPayload;

  /// UTC timestamp of when the message was dispatched to the relay
  final DateTime timestamp;

  /// Expiration timestamp (TTL) after which the relay automatically purges the message
  final DateTime expiresAt;

  /// Type of relay envelope: message, delivery_receipt, or read_receipt (Phase 12)
  final String envelopeType;

  const EphemeralRelayEnvelope({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.ciphertextPayload,
    required this.timestamp,
    required this.expiresAt,
    this.envelopeType = 'message',
  });

  /// Factory constructor to create an envelope with a standard 48-hour default TTL
  factory EphemeralRelayEnvelope.create({
    required String id,
    required String senderId,
    required String recipientId,
    required String ciphertextPayload,
    String envelopeType = 'message',
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 48),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: ciphertextPayload,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: envelopeType,
    );
  }

  /// Create a delivery receipt envelope notifying sender that message was received
  factory EphemeralRelayEnvelope.deliveryReceipt({
    required String messageId,
    required String senderId,
    required String recipientId,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'receipt_del_${messageId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: messageId,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'delivery_receipt',
    );
  }

  /// Create a read receipt envelope notifying sender that message was opened/read
  factory EphemeralRelayEnvelope.readReceipt({
    required String messageId,
    required String senderId,
    required String recipientId,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'receipt_read_${messageId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: messageId,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'read_receipt',
    );
  }

  /// Create an ephemeral typing indicator signal (Phase 13)
  factory EphemeralRelayEnvelope.typing({
    required String senderId,
    required String recipientId,
    required bool isTyping,
    DateTime? timestamp,
    Duration ttl = const Duration(seconds: 5),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'sig_typing_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: isTyping ? 'true' : 'false',
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'typing',
    );
  }

  /// Create an ephemeral presence heartbeat signal (Phase 13)
  factory EphemeralRelayEnvelope.presence({
    required String senderId,
    required String recipientId,
    required bool isOnline,
    DateTime? lastSeen,
    DateTime? timestamp,
    Duration ttl = const Duration(seconds: 35),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    final payload = jsonEncode({
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': lastSeen.toIso8601String(),
    });
    return EphemeralRelayEnvelope(
      id: 'sig_presence_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: payload,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'presence',
    );
  }

  /// Create an ephemeral love connection invitation request (Phase 16)
  factory EphemeralRelayEnvelope.loveRequest({
    required String senderId,
    required String recipientId,
    String? senderPublicKey,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 48),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    final payloadMap = <String, dynamic>{
      'type': 'love_request',
      'sender_username': senderId,
    };
    if (senderPublicKey != null) {
      payloadMap['sender_public_key'] = senderPublicKey;
    }
    final payload = jsonEncode(payloadMap);
    return EphemeralRelayEnvelope(
      id: 'love_req_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: payload,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'love_request',
    );
  }

  /// Create an ephemeral love connection acceptance signal (Phase 16)
  factory EphemeralRelayEnvelope.loveAccept({
    required String senderId,
    required String recipientId,
    String? senderPublicKey,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    final payloadMap = <String, dynamic>{
      'type': 'love_accept',
      'sender_username': senderId,
    };
    if (senderPublicKey != null) {
      payloadMap['sender_public_key'] = senderPublicKey;
    }
    final payload = jsonEncode(payloadMap);
    return EphemeralRelayEnvelope(
      id: 'love_acc_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: payload,
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'love_accept',
    );
  }

  /// Create an ephemeral love connection decline signal (Phase 16)
  factory EphemeralRelayEnvelope.loveDecline({
    required String senderId,
    required String recipientId,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'love_dec_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: jsonEncode({'type': 'love_decline', 'sender_username': senderId}),
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'love_decline',
    );
  }

  /// Create an ephemeral love connection cancellation signal (Phase 16)
  factory EphemeralRelayEnvelope.loveCancel({
    required String senderId,
    required String recipientId,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'love_can_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: jsonEncode({'type': 'love_cancel', 'sender_username': senderId}),
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'love_cancel',
    );
  }

  /// Create an ephemeral love connection unlink signal (Phase 16)
  factory EphemeralRelayEnvelope.loveUnlink({
    required String senderId,
    required String recipientId,
    DateTime? timestamp,
    Duration ttl = const Duration(hours: 24),
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    return EphemeralRelayEnvelope(
      id: 'love_unl_${senderId}_${recipientId}_${now.millisecondsSinceEpoch}',
      senderId: senderId,
      recipientId: recipientId,
      ciphertextPayload: jsonEncode({'type': 'love_unlink', 'sender_username': senderId}),
      timestamp: now,
      expiresAt: now.add(ttl),
      envelopeType: 'love_unlink',
    );
  }

  /// Whether this envelope is a status receipt rather than a content payload
  bool get isReceipt =>
      envelopeType == 'delivery_receipt' || envelopeType == 'read_receipt';

  /// Whether this envelope is a delivery receipt
  bool get isDeliveryReceipt => envelopeType == 'delivery_receipt';

  /// Whether this envelope is a read receipt
  bool get isReadReceipt => envelopeType == 'read_receipt';

  /// Whether this envelope is an ephemeral real-time typing indicator
  bool get isTypingSignal => envelopeType == 'typing';

  /// Whether typing indicator is actively active
  bool get isTypingActive => isTypingSignal && ciphertextPayload == 'true';

  /// Whether this envelope is an ephemeral presence heartbeat
  bool get isPresenceSignal => envelopeType == 'presence';

  /// Whether this envelope is an ephemeral Love Connection signal (Phase 16)
  bool get isLoveSignal => envelopeType.startsWith('love_');

  /// Target message ID for receipt envelopes
  String get targetMessageId => ciphertextPayload;

  /// Whether this envelope has expired past its TTL
  bool isExpired([DateTime? now]) {
    final currentTime = now ?? DateTime.now().toUtc();
    return currentTime.isAfter(expiresAt);
  }

  /// Convert to JSON map suitable for Firebase Firestore or Realtime Database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'ciphertext': ciphertextPayload,
      'type': envelopeType,
      'timestamp': timestamp.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// Reconstruct an envelope from a JSON map
  factory EphemeralRelayEnvelope.fromJson(Map<String, dynamic> json) {
    return EphemeralRelayEnvelope(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      ciphertextPayload: json['ciphertext'] as String,
      envelopeType: json['type'] as String? ?? 'message',
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Serialize to a compact JSON string
  String serialize() => jsonEncode(toJson());

  /// Deserialize from a compact JSON string
  factory EphemeralRelayEnvelope.deserialize(String raw) {
    return EphemeralRelayEnvelope.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  String toString() =>
      'EphemeralRelayEnvelope(id: $id, type: $envelopeType, from: $senderId, to: $recipientId, expires: $expiresAt)';
}

