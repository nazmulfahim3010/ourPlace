import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';

/// Conversation domain model representing the chat thread between the couple
class Conversation {
  final String id;
  final User partner;
  final ChatMessage? lastMessage;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.partner,
    this.lastMessage,
    this.unreadCount = 0,
  });

  Conversation copyWith({
    String? id,
    User? partner,
    ChatMessage? lastMessage,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      partner: partner ?? this.partner,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  String toString() =>
      'Conversation(id: $id, partner: ${partner.displayName}, unreadCount: $unreadCount)';
}
