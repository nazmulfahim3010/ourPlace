/// User domain model representing an authorized chat participant
class User {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;

  const User({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  User copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isCurrentUser,
  }) {
    return User(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  String toString() =>
      'User(id: $id, displayName: $displayName, isCurrentUser: $isCurrentUser)';
}
