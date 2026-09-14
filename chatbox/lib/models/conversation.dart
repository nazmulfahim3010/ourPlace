import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';

/// Conversation domain model representing a chat thread between the user and another participant
class Conversation {
  final String id;
  final User partner;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isLoveConnection;
  final DateTime? lastMessageAt;

  const Conversation({
    required this.id,
    required this.partner,
    this.lastMessage,
    this.unreadCount = 0,
    this.isLoveConnection = false,
    this.lastMessageAt,
  });

  /// Check if the conversation has unread messages
  bool get hasUnread => unreadCount > 0;

  /// Effective timestamp for sorting and display
  DateTime get effectiveTimestamp =>
      lastMessage?.timestamp ?? lastMessageAt ?? partner.createdAt;

  /// Human-friendly timestamp string (e.g. "10:42 PM", "Yesterday", "Mon")
  String get formattedTimestamp {
    final now = DateTime.now();
    final time = effectiveTimestamp;

    final isSameDay = now.year == time.year &&
        now.month == time.month &&
        now.day == time.day;

    if (isSameDay) {
      final hour = time.hour == 0
          ? 12
          : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == time.year &&
        yesterday.month == time.month &&
        yesterday.day == time.day;

    if (isYesterday) {
      return 'Yesterday';
    }

    return '${time.month}/${time.day}';
  }

  Conversation copyWith({
    String? id,
    User? partner,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isLoveConnection,
    DateTime? lastMessageAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      partner: partner ?? this.partner,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoveConnection: isLoveConnection ?? this.isLoveConnection,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  @override
  String toString() =>
      'Conversation(id: $id, partner: ${partner.displayName}, unreadCount: $unreadCount, isLoveConnection: $isLoveConnection)';
}
