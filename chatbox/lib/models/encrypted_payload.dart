import 'dart:convert';

/// Domain model representing an end-to-end encrypted message payload (Phase 10)
///
/// Encapsulates cryptographic ciphertext, sender's public identity/ephemeral key,
/// initialization vector (nonce), and AEAD authentication tag (MAC).
class EncryptedPayload {
  /// Protocol format version
  final int version;

  /// Base64-encoded X25519 public key of the sender
  final String senderPublicKey;

  /// Base64-encoded initialization vector (nonce) unique per message
  final String nonce;

  /// Base64-encoded encrypted payload
  final String ciphertext;

  /// Base64-encoded 16-byte authentication tag (AEAD verification)
  final String mac;

  /// Timestamp of encryption
  final DateTime createdAt;

  const EncryptedPayload({
    this.version = 1,
    required this.senderPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.createdAt,
  });

  /// Serialize payload into a JSON map
  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'sender_pub': senderPublicKey,
      'nonce': nonce,
      'ct': ciphertext,
      'mac': mac,
      'ts': createdAt.toIso8601String(),
    };
  }

  /// Reconstruct an EncryptedPayload from a JSON map
  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      version: json['v'] as int? ?? 1,
      senderPublicKey: json['sender_pub'] as String,
      nonce: json['nonce'] as String,
      ciphertext: json['ct'] as String,
      mac: json['mac'] as String,
      createdAt: json['ts'] != null
          ? DateTime.parse(json['ts'] as String)
          : DateTime.now(),
    );
  }

  /// Compact JSON string representation suitable for network transport / Firebase relay
  String serialize() => jsonEncode(toJson());

  /// Parse from compact JSON string representation
  factory EncryptedPayload.deserialize(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return EncryptedPayload.fromJson(decoded);
  }

  @override
  String toString() =>
      'EncryptedPayload(v: $version, senderPub: ${senderPublicKey.substring(0, 8)}..., ctLength: ${ciphertext.length})';
}
