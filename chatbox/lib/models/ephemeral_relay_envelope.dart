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

  const EphemeralRelayEnvelope({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.ciphertextPayload,
    required this.timestamp,
    required this.expiresAt,
  });

  /// Factory constructor to create an envelope with a standard 48-hour default TTL
  factory EphemeralRelayEnvelope.create({
    required String id,
    required String senderId,
    required String recipientId,
    required String ciphertextPayload,
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
    );
  }

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
      'EphemeralRelayEnvelope(id: $id, from: $senderId, to: $recipientId, ctLength: ${ciphertextPayload.length}, expires: $expiresAt)';
}
