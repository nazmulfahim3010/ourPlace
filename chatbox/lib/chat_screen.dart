import 'package:flutter/material.dart';

/// Mock message model
class ChatMessage {
  final String id;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSent;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isSent,
  });
}

/// Main Chat Screen Widget
class ChatScreen extends StatefulWidget {
  final String partnerName;

  const ChatScreen({Key? key, this.partnerName = "Alex"}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController _messageController;
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messages = _generateMockMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Generate mock messages for preview
  List<ChatMessage> _generateMockMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: '1',
        senderName: widget.partnerName,
        content: 'Hey! How was your day? 😊',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isSent: false,
      ),
      ChatMessage(
        id: '2',
        senderName: 'You',
        content: 'It was great! Just finished the project.',
        timestamp: now.subtract(const Duration(minutes: 4)),
        isSent: true,
      ),
      ChatMessage(
        id: '3',
        senderName: 'You',
        content: 'How about yours?',
        timestamp: now.subtract(const Duration(minutes: 3, seconds: 30)),
        isSent: true,
      ),
      ChatMessage(
        id: '4',
        senderName: widget.partnerName,
        content: 'Pretty good! Can\'t wait to celebrate with you 🎉',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isSent: false,
      ),
      ChatMessage(
        id: '5',
        senderName: widget.partnerName,
        content: 'Let\'s get dinner together soon!',
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 30)),
        isSent: false,
      ),
    ];
  }

  /// Handle sending a message
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          id: DateTime.now().toString(),
          senderName: 'You',
          content: _messageController.text,
          timestamp: DateTime.now(),
          isSent: true,
        ),
      );
    });

    _messageController.clear();
  }

  /// Handle "Send luv" quick action
  void _sendLuv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💕 Love sent!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF383838),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          /// Custom Floating Pill-Shaped Header
          _ChatHeader(partnerName: widget.partnerName, onSendLuv: _sendLuv),

          /// Chat Messages Area
          Expanded(child: _ChatMessageArea(messages: _messages)),

          /// Bottom Input Bar
          _ChatInputField(
            controller: _messageController,
            onSendPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// Custom floating pill-shaped header widget
class _ChatHeader extends StatelessWidget {
  final String partnerName;
  final VoidCallback onSendLuv;

  const _ChatHeader({
    Key? key,
    required this.partnerName,
    required this.onSendLuv,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF383838),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              /// Leading Profile Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              /// Partner Name Title
              Expanded(
                child: Text(
                  partnerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              /// Send Luv Button
              TextButton(
                onPressed: onSendLuv,
                child: const Text(
                  '💕 Send luv',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat message area with scrollable messages
class _ChatMessageArea extends StatelessWidget {
  final List<ChatMessage> messages;

  const _ChatMessageArea({Key? key, required this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(message: message);
      },
    );
  }
}

/// Individual message bubble widget
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.isSent
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        /// Timestamp indicator above message
        _TimestampIndicator(
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
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Timestamp indicator widget
class _TimestampIndicator extends StatelessWidget {
  final DateTime timestamp;
  final bool isSent;

  const _TimestampIndicator({
    Key? key,
    required this.timestamp,
    required this.isSent,
  }) : super(key: key);

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          _formatTime(timestamp),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}

/// Bottom input bar widget
class _ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSendPressed;

  const _ChatInputField({
    Key? key,
    required this.controller,
    required this.onSendPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            /// Text input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF383838),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            /// Send button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSendPressed,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383838),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
