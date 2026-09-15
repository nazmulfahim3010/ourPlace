import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:chatbox/core/utils/hash_utils.dart';

/// Cryptographic handshake payload exchanged during remote zero-knowledge authentication
class AuthChallenge {
  final String challengeId;
  final String username;
  final String serverNonce;
  final DateTime issuedAt;
  final Duration validDuration;

  AuthChallenge({
    required this.challengeId,
    required this.username,
    required this.serverNonce,
    required this.issuedAt,
    this.validDuration = const Duration(minutes: 2),
  });

  bool get isExpired => DateTime.now().isAfter(issuedAt.add(validDuration));

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'username': username,
        'serverNonce': serverNonce,
        'issuedAt': issuedAt.toIso8601String(),
      };

  factory AuthChallenge.fromJson(Map<String, dynamic> json) => AuthChallenge(
        challengeId: json['challengeId'] as String,
        username: json['username'] as String,
        serverNonce: json['serverNonce'] as String,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
      );
}

/// Mutual challenge-response zero-knowledge authentication handshake engine
///
/// Designed to prove account ownership without exposing plaintext passwords
/// or static salted hashes across the network wire.
class AuthSecurityService {
  static final Random _secureRandom = Random.secure();

  /// Generate a random nonce hex string
  static String generateNonce([int length = 32]) {
    final bytes = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Issue an ephemeral server authentication challenge for a username
  static AuthChallenge issueChallenge({required String username}) {
    final normalized = HashUtils.normalizeUsername(username);
    final challengeId = 'chal_${DateTime.now().millisecondsSinceEpoch}_${generateNonce(8)}';
    final serverNonce = generateNonce(32);

    return AuthChallenge(
      challengeId: challengeId,
      username: normalized,
      serverNonce: serverNonce,
      issuedAt: DateTime.now(),
    );
  }

  /// Compute client proof token using HMAC-SHA256 over ephemeral nonces
  ///
  /// Proof = HMAC_SHA256(Key: saltedPasswordHash, Message: "$serverNonce:$clientNonce:$username")
  static String computeClientProof({
    required String passwordHash,
    required String serverNonce,
    required String clientNonce,
    required String username,
  }) {
    final key = utf8.encode(passwordHash);
    final message = utf8.encode('$serverNonce:$clientNonce:$username');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).toString();
  }

  /// Verify client proof token against expected credentials
  static bool verifyClientProof({
    required String clientProof,
    required String expectedPasswordHash,
    required String serverNonce,
    required String clientNonce,
    required String username,
  }) {
    final expectedProof = computeClientProof(
      passwordHash: expectedPasswordHash,
      serverNonce: serverNonce,
      clientNonce: clientNonce,
      username: username,
    );
    return clientProof == expectedProof;
  }

  /// Compute mutual server proof to prove server identity back to client
  ///
  /// ServerProof = HMAC_SHA256(Key: saltedPasswordHash, Message: "$clientProof:$serverNonce")
  static String computeServerProof({
    required String passwordHash,
    required String clientProof,
    required String serverNonce,
  }) {
    final key = utf8.encode(passwordHash);
    final message = utf8.encode('$clientProof:$serverNonce:MUTUAL_ACK');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).toString();
  }

  /// Client verifies server response proof
  static bool verifyServerProof({
    required String serverProof,
    required String passwordHash,
    required String clientProof,
    required String serverNonce,
  }) {
    final expectedProof = computeServerProof(
      passwordHash: passwordHash,
      clientProof: clientProof,
      serverNonce: serverNonce,
    );
    return serverProof == expectedProof;
  }
}
