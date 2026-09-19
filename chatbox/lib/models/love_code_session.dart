import 'dart:math';

/// Domain model representing an ephemeral One-Time Love Code (OTC) session (Phase 17).
///
/// Designed with strict privacy and security constraints:
/// - 60-second strict expiration
/// - Single-use replay protection
/// - Explicit authorization limited to the connected Love Partner
class LoveCodeSession {
  /// 6-digit numeric authorization code (e.g. "849201")
  final String code;

  /// Target third-party conversation whose messages are authorized to be shared (e.g. "@sarah")
  final String conversationPartner;

  /// Username of the account holder generating the code (e.g. "@alex")
  final String ownerUsername;

  /// The only partner authorized to claim this code (e.g. "@twilight")
  final String targetLovePartner;

  /// Timestamp when the code was generated
  final DateTime createdAt;

  /// Timestamp when the code expires (strictly 60 seconds after createdAt)
  final DateTime expiresAt;

  /// Single-use tracking: true once redeemed
  final bool isUsed;

  const LoveCodeSession({
    required this.code,
    required this.conversationPartner,
    required this.ownerUsername,
    required this.targetLovePartner,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  /// Factory creating a fresh 60-second session
  factory LoveCodeSession.create({
    required String code,
    required String conversationPartner,
    required String ownerUsername,
    required String targetLovePartner,
    Duration ttl = const Duration(seconds: 60),
    DateTime? now,
  }) {
    final created = now ?? DateTime.now().toUtc();
    return LoveCodeSession(
      code: code,
      conversationPartner: conversationPartner,
      ownerUsername: ownerUsername,
      targetLovePartner: targetLovePartner,
      createdAt: created,
      expiresAt: created.add(ttl),
      isUsed: false,
    );
  }

  /// Whether the code has passed its expiration timestamp
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Whether the code is currently redeemable (not used and not expired)
  bool get isValid => !isUsed && !isExpired;

  /// Remaining seconds until expiration (clamped to 0)
  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    return max(0, diff);
  }

  /// Create a copy with optional updated fields
  LoveCodeSession copyWith({
    String? code,
    String? conversationPartner,
    String? ownerUsername,
    String? targetLovePartner,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
  }) {
    return LoveCodeSession(
      code: code ?? this.code,
      conversationPartner: conversationPartner ?? this.conversationPartner,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      targetLovePartner: targetLovePartner ?? this.targetLovePartner,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  /// Serialize to JSON map
  Map<String, dynamic> toJson() => {
        'code': code,
        'conversationPartner': conversationPartner,
        'ownerUsername': ownerUsername,
        'targetLovePartner': targetLovePartner,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'isUsed': isUsed,
      };

  /// Deserialize from JSON map
  factory LoveCodeSession.fromJson(Map<String, dynamic> json) {
    return LoveCodeSession(
      code: json['code'] as String,
      conversationPartner: json['conversationPartner'] as String,
      ownerUsername: json['ownerUsername'] as String,
      targetLovePartner: json['targetLovePartner'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isUsed: json['isUsed'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'LoveCodeSession(code: $code, for: $conversationPartner, to: $targetLovePartner, valid: $isValid, remaining: ${remainingSeconds}s)';
}
