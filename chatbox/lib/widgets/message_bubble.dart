import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/timestamp_indicator.dart';

/// Individual message bubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final bool? isSent;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.isSent,
  });

  bool get _effectiveIsSent => isSent ?? message.isSent;

  @override
  Widget build(BuildContext context) {
    final sent = _effectiveIsSent;

    return Column(
      crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        /// Timestamp and delivery status indicator above message
        if (showTimestamp) ...[
          TimestampIndicator(
            timestamp: message.timestamp,
            isSent: sent,
            status: sent ? message.status : null,
          ),
          const SizedBox(height: 4),
        ],

        /// Message bubble container
        Align(
          alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            child: Text(
              message.getContent(),
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
