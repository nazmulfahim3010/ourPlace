import 'package:flutter/material.dart';
import 'package:chatbox/models/conversation.dart';
import 'package:chatbox/models/message.dart';

/// Reusable tile component representing a single conversation item in the Inbox
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final String currentUserId;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.currentUserId = 'current_user',
  });

  @override
  Widget build(BuildContext context) {
    final partner = conversation.partner;
    final lastMsg = conversation.lastMessage;
    final isLove = conversation.isLoveConnection;

    final trimmedName = partner.displayName.trim();
    final cleanName = trimmedName.replaceFirst(RegExp(r'^@+'), '').trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?';

    // Preview snippet
    String messageSnippet = 'No messages yet';
    if (lastMsg != null) {
      final isSentByMe = lastMsg.isSentBy(currentUserId);
      final prefix = isSentByMe ? 'You: ' : '';
      if (lastMsg.type == MessageType.image) {
        messageSnippet = '$prefix📷 Photo';
      } else if (lastMsg.type == MessageType.audio) {
        messageSnippet = '$prefix🎙️ Voice note';
      } else if (lastMsg.type == MessageType.video) {
        messageSnippet = '$prefix🎥 Video';
      } else if (lastMsg.text.isNotEmpty) {
        messageSnippet = '$prefix${lastMsg.text}';
      } else if (lastMsg.mediaAttachment != null) {
        messageSnippet = '$prefix📎 Attachment';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: isLove ? const Color(0xFF2E2428) : const Color(0xFF383838),
              borderRadius: BorderRadius.circular(20),
              border: isLove
                  ? Border.all(color: const Color(0xFFFF6B81).withValues(alpha: 0.35), width: 1.2)
                  : Border.all(color: const Color(0xFF444444), width: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                /// Avatar with Love Connection indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isLove ? const Color(0xFFFF6B81) : Colors.white,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isLove ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (isLove)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFFF6B81),
                            size: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                /// Name and Last Message Preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (isLove) ...[
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFFF6B81),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              partner.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.formattedTimestamp.isNotEmpty)
                            Text(
                              conversation.formattedTimestamp,
                              style: TextStyle(
                                color: conversation.hasUnread
                                    ? (isLove ? const Color(0xFFFF6B81) : Colors.white)
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: conversation.hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              messageSnippet,
                              style: TextStyle(
                                color: conversation.hasUnread
                                    ? Colors.white
                                    : const Color(0xFFAAAAAA),
                                fontSize: 13.5,
                                fontWeight: conversation.hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isLove
                                    ? const Color(0xFFFF6B81)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: TextStyle(
                                  color: isLove ? Colors.white : Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
