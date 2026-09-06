import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/timestamp_indicator.dart';

/// Individual message bubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.isSent
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        /// Timestamp indicator above message
        TimestampIndicator(
          timestamp: message.timestamp,
          isSent: message.isSent,
        ),
        const SizedBox(height: 4),

        /// Message bubble
        Align(
          alignment: message.isSent
              ? Alignment.centerRight
              : Alignment.centerLeft,
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
