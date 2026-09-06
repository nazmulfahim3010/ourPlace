import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/chat_header.dart';
import 'package:chatbox/widgets/message_bubble.dart';
import 'package:chatbox/widgets/chat_input_field.dart';

/// Main Chat Screen Widget
class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String partnerId;

  const ChatScreen({
    Key? key,
    this.partnerName = "Alex",
    this.partnerId = "partner_user_id",
  }) : super(key: key);

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

  /// Generate mock messages for preview using the new Message architecture
  List<ChatMessage> _generateMockMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'msg_001',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Hey! How was your day? 😊',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'msg_002',
        senderId: 'current_user',
        recipientId: widget.partnerId,
        text: 'It was great! Just finished the project.',
        timestamp: now.subtract(const Duration(minutes: 4)),
        type: MessageType.text,
        status: MessageStatus.delivered,
      ),
      ChatMessage(
        id: 'msg_003',
        senderId: 'current_user',
        recipientId: widget.partnerId,
        text: 'How about yours?',
        timestamp: now.subtract(const Duration(minutes: 3, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.delivered,
      ),
      ChatMessage(
        id: 'msg_004',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Pretty good! Can\'t wait to celebrate with you 🎉',
        timestamp: now.subtract(const Duration(minutes: 2)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'msg_005',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Let\'s get dinner together soon!',
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
    ];
  }

  /// Handle sending a message - Creates a ChatMessage with proper architecture
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'current_user',
          recipientId: widget.partnerId,
          text: _messageController.text,
          timestamp: DateTime.now(),
          type: MessageType.text,
          status: MessageStatus.sending,
        ),
      );
    });

    _messageController.clear();

    // TODO: Phase 3 - Save to local database
    // TODO: Phase 4 - Sync with Firebase relay
    // TODO: Phase 8 - Encrypt before transmission
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
          ChatHeader(partnerName: widget.partnerName, onSendLuv: _sendLuv),

          /// Chat Messages Area
          Expanded(child: _ChatMessageArea(messages: _messages)),

          /// Bottom Input Bar
          ChatInputField(
            controller: _messageController,
            onSendPressed: _sendMessage,
          ),
        ],
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
        return MessageBubble(message: message);
      },
    );
  }
}
