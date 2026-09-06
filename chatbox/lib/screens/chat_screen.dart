import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/chat_header.dart';
import 'package:chatbox/widgets/date_divider.dart';
import 'package:chatbox/widgets/message_bubble.dart';
import 'package:chatbox/widgets/chat_input_field.dart';

/// Main Chat Screen Widget (Phase 3 - Functional Local Chat)
class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String partnerId;

  const ChatScreen({
    super.key,
    this.partnerName = "Twilight",
    this.partnerId = "partner_user_id",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _messages = _generateMockMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Generate mock messages for preview with varied timestamps and statuses
  List<ChatMessage> _generateMockMessages() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return [
      // Today's messages (newest first for reverse list)
      ChatMessage(
        id: 'msg_005',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: "Let's get dinner together soon! 🍕",
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'msg_004',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: "Pretty good! Can't wait to celebrate with you 🎉",
        timestamp: now.subtract(const Duration(minutes: 2)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'msg_003',
        senderId: 'current_user',
        recipientId: widget.partnerId,
        text: 'How about yours?',
        timestamp: now.subtract(const Duration(minutes: 3, seconds: 30)),
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
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'msg_001',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Hey! How was your day? 😊',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      // Yesterday's message to showcase date grouping
      ChatMessage(
        id: 'msg_000',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Good night, sleep well! ❤️',
        timestamp: yesterday,
        type: MessageType.text,
        status: MessageStatus.read,
      ),
    ];
  }

  /// Handle sending a message with local state update and auto-scroll
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'current_user',
      recipientId: widget.partnerId,
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.insert(0, newMessage);
    });

    _messageController.clear();

    // Auto-scroll to the newest message at the bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    // Simulate message transitioning from sending -> sent
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWithStatus(MessageStatus.sent);
        });
      }
    });

    // TODO: Phase 4 - Save to Drift/SQLite local database
    // TODO: Phase 9 - Dispatch to Firebase temporary relay
    // TODO: Phase 8 - End-to-end encrypt payload before transmission
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
          /// Floating Pill-Shaped Header
          ChatHeader(
            partnerName: widget.partnerName,
            onSendLuv: _sendLuv,
          ),

          /// Chat Messages Area with dismiss-on-tap gesture
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: _ChatMessageArea(
                messages: _messages,
                scrollController: _scrollController,
              ),
            ),
          ),

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

/// Chat message area with reverse scrolling, date grouping, and status tracking
class _ChatMessageArea extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;

  const _ChatMessageArea({
    required this.messages,
    required this.scrollController,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        // In a reversed list:
        // index + 1 is the previous message chronologically (older)
        final isOldestOverall = index == messages.length - 1;
        final hasPrecedingMessage = index + 1 < messages.length;
        final isFirstMessageOfDay = isOldestOverall ||
            (hasPrecedingMessage &&
                !_isSameDay(
                    message.timestamp, messages[index + 1].timestamp));

        // Grouping: hide redundant timestamp if sent by the same user within 2 minutes
        bool showTimestamp = true;
        if (!isFirstMessageOfDay && hasPrecedingMessage) {
          final prevMessage = messages[index + 1];
          final sameSender = prevMessage.senderId == message.senderId;
          final timeDiff = message.timestamp
              .difference(prevMessage.timestamp)
              .inMinutes
              .abs();
          if (sameSender && timeDiff < 2) {
            showTimestamp = false;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Divider appears above the first message of each day
            if (isFirstMessageOfDay) DateDivider(dateTime: message.timestamp),
            Padding(
              padding: EdgeInsets.only(
                bottom: showTimestamp ? 6.0 : 3.0,
                top: 2.0,
              ),
              child: MessageBubble(
                message: message,
                showTimestamp: showTimestamp,
              ),
            ),
          ],
        );
      },
    );
  }
}
