/// Domain model representing a private couple love letter or "Open When..." note
class LoveNote {
  /// Unique identifier of the note
  final String id;

  /// Username of the author/sender (e.g. "@alex")
  final String senderUsername;

  /// Username of the recipient (e.g. "@twilight")
  final String recipientUsername;

  /// Title of the love letter
  final String title;

  /// Body content of the love letter
  final String body;

  /// Creation timestamp
  final DateTime createdAt;

  /// Optional unlock / "Open when" timestamp
  final DateTime? openAt;

  /// Whether the letter has been unsealed by the recipient
  final bool isOpened;

  /// Optional romantic category or tag (e.g., "Open when you miss me", "Anniversary")
  final String? tag;

  const LoveNote({
    required this.id,
    required this.senderUsername,
    required this.recipientUsername,
    required this.title,
    required this.body,
    required this.createdAt,
    this.openAt,
    this.isOpened = false,
    this.tag,
  });

  /// Whether this letter can be opened at the current time
  bool get canOpen {
    if (openAt == null) return true;
    return DateTime.now().isAfter(openAt!);
  }

  /// Whether this letter is still sealed
  bool get isSealed => !isOpened;

  /// Create a copy with modified fields
  LoveNote copyWith({
    String? id,
    String? senderUsername,
    String? recipientUsername,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? openAt,
    bool? isOpened,
    String? tag,
  }) {
    return LoveNote(
      id: id ?? this.id,
      senderUsername: senderUsername ?? this.senderUsername,
      recipientUsername: recipientUsername ?? this.recipientUsername,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      openAt: openAt ?? this.openAt,
      isOpened: isOpened ?? this.isOpened,
      tag: tag ?? this.tag,
    );
  }

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUsername': senderUsername,
      'recipientUsername': recipientUsername,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      if (openAt != null) 'openAt': openAt!.toIso8601String(),
      'isOpened': isOpened,
      if (tag != null) 'tag': tag,
    };
  }

  /// Deserialize from JSON map
  factory LoveNote.fromJson(Map<String, dynamic> json) {
    return LoveNote(
      id: json['id'] as String,
      senderUsername: json['senderUsername'] as String,
      recipientUsername: json['recipientUsername'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      openAt: json['openAt'] != null
          ? DateTime.parse(json['openAt'] as String)
          : null,
      isOpened: json['isOpened'] as bool? ?? false,
      tag: json['tag'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoveNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderUsername == other.senderUsername &&
          recipientUsername == other.recipientUsername &&
          title == other.title &&
          body == other.body &&
          createdAt == other.createdAt &&
          openAt == other.openAt &&
          isOpened == other.isOpened &&
          tag == other.tag;

  @override
  int get hashCode =>
      id.hashCode ^
      senderUsername.hashCode ^
      recipientUsername.hashCode ^
      title.hashCode ^
      body.hashCode ^
      createdAt.hashCode ^
      openAt.hashCode ^
      isOpened.hashCode ^
      tag.hashCode;

  @override
  String toString() {
    return 'LoveNote(id: $id, from: $senderUsername, to: $recipientUsername, '
        'title: $title, isOpened: $isOpened, tag: $tag)';
  }
}
