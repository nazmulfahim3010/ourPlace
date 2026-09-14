/// User domain model representing an anonymous chat participant in ourPlace
class User {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final String? publicIdentityKey;
  final String? loveConnectionId;
  final bool loveConnectionVisibility;
  final bool isCurrentUser;

  User({
    required this.id,
    required this.username,
    String? displayName,
    this.avatarUrl,
    DateTime? createdAt,
    this.publicIdentityKey,
    this.loveConnectionId,
    this.loveConnectionVisibility = true,
    this.isCurrentUser = false,
  })  : displayName = displayName ?? username,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'publicIdentityKey': publicIdentityKey,
      'loveConnectionId': loveConnectionId,
      'loveConnectionVisibility': loveConnectionVisibility,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String? ?? json['displayName'] as String? ?? 'anonymous',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      publicIdentityKey: json['publicIdentityKey'] as String?,
      loveConnectionId: json['loveConnectionId'] as String?,
      loveConnectionVisibility: json['loveConnectionVisibility'] as bool? ?? true,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    String? publicIdentityKey,
    String? loveConnectionId,
    bool? loveConnectionVisibility,
    bool? isCurrentUser,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      publicIdentityKey: publicIdentityKey ?? this.publicIdentityKey,
      loveConnectionId: loveConnectionId ?? this.loveConnectionId,
      loveConnectionVisibility:
          loveConnectionVisibility ?? this.loveConnectionVisibility,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  String toString() =>
      'User(id: $id, username: $username, isCurrentUser: $isCurrentUser)';
}
