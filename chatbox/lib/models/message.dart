/// Message type enumeration
enum MessageType { text, image, audio, video, system }

/// Message delivery status enumeration
enum MessageStatus { sending, sent, delivered, read, failed }

/// Message model following the architecture requirements from Phase 2
class ChatMessage {
  /// Unique message identifier
  final String id;

  /// ID of the user who sent the message
  final String senderId;

  /// ID of the user who receives the message
  final String recipientId;

  /// Message text content
  final String text;

  /// Message timestamp
  final DateTime timestamp;

  /// Message type (text, image, audio, video, system)
  final MessageType type;

  /// Message delivery status
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
  });

  /// Convenience getter: Check if message was sent by default current user
  bool get isSent => senderId == 'current_user';

  /// Check if message was sent by a specific user ID
  bool isSentBy(String currentUserId) =>
      senderId == currentUserId || (senderId == 'current_user' && currentUserId.isNotEmpty);

  /// Get sender display name (for UI compatibility)
  String getSenderName([String partnerName = '@twilight', String currentUserName = 'You']) {
    return isSent ? currentUserName : partnerName;
  }

  /// Get message content (for UI compatibility)
  String getContent() => text;

  /// Convert ChatMessage to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
    };
  }

  /// Create ChatMessage from JSON (database retrieval)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  /// Create a copy of ChatMessage with some fields replaced
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? text,
    DateTime? timestamp,
    MessageType? type,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }

  /// Update only the message status (common operation)
  ChatMessage copyWithStatus(MessageStatus newStatus) {
    return copyWith(status: newStatus);
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, senderId: $senderId, recipientId: $recipientId, '
        'text: $text, timestamp: $timestamp, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          recipientId == other.recipientId &&
          text == other.text &&
          timestamp == other.timestamp &&
          type == other.type &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      senderId.hashCode ^
      recipientId.hashCode ^
      text.hashCode ^
      timestamp.hashCode ^
      type.hashCode ^
      status.hashCode;
}
