import 'dart:convert';

/// Domain model representing a user's real-time presence and connectivity state (Phase 13).
///
/// In strict accordance with zero-knowledge and zero-telemetry principles:
/// - Presence is an ephemeral volatile state (not permanently logged to disk or server databases).
/// - If stealth mode is active, presence is masked to protect user privacy.
class UserPresence {
  /// Normalized username of the user (e.g. '@alex')
  final String userId;

  /// Whether the user currently has the app open in the active foreground
  final bool isOnline;

  /// UTC timestamp of the user's last recorded heartbeat or active session
  final DateTime? lastSeen;

  const UserPresence({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
  });

  /// Human-friendly presence text for UI display (e.g., "online", "last seen 5m ago")
  String get statusText {
    if (isOnline) {
      return 'online';
    }
    if (lastSeen == null) {
      return 'offline';
    }

    final diff = DateTime.now().toUtc().difference(lastSeen!);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'last seen just now';
    }
    if (diff.inMinutes < 60) {
      return 'last seen ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return 'last seen ${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'last seen yesterday';
    }
    if (diff.inDays < 7) {
      return 'last seen ${diff.inDays}d ago';
    }
    return 'last seen recently';
  }

  /// Copy with updated attributes
  UserPresence copyWith({
    String? userId,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserPresence(
      userId: userId ?? this.userId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
    };
  }

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['userId'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)?.toUtc()
          : null,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory UserPresence.deserialize(String jsonString) =>
      UserPresence.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPresence &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isOnline == other.isOnline &&
          lastSeen == other.lastSeen;

  @override
  int get hashCode => userId.hashCode ^ isOnline.hashCode ^ lastSeen.hashCode;

  @override
  String toString() =>
      'UserPresence(userId: $userId, isOnline: $isOnline, lastSeen: $lastSeen)';
}
