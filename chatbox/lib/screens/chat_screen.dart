import 'package:flutter/material.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/chat_header.dart';
import 'package:chatbox/widgets/date_divider.dart';
import 'package:chatbox/widgets/message_bubble.dart';
import 'package:chatbox/widgets/chat_input_field.dart';

/// Main Chat Screen Widget (Phase 4 - Persistent Local Database with Drift)
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
  final LocalDatabase _localDb = LocalDatabase();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessagesFromDatabase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load persisted messages from Drift / SQLite database
  Future<void> _loadMessagesFromDatabase() async {
    try {
      final storedMessages =
          await _localDb.getMessagesForPartner(widget.partnerId);

      if (storedMessages.isEmpty) {
        // Seed initial history into the permanent database on first launch
        final seedMessages = _generateInitialSeedMessages();
        await _localDb.saveMessages(seedMessages);
        if (mounted) {
          setState(() {
            _messages = seedMessages;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _messages = storedMessages;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback to memory list if database read encounters an issue
      if (mounted) {
        setState(() {
          _messages = _generateInitialSeedMessages();
          _isLoading = false;
        });
      }
    }
  }

  /// Initial seed messages to populate on first run
  List<ChatMessage> _generateInitialSeedMessages() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return [
      ChatMessage(
        id: 'seed_005',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: "Let's get dinner together soon! 🍕",
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_004',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: "Pretty good! Can't wait to celebrate with you 🎉",
        timestamp: now.subtract(const Duration(minutes: 2)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_003',
        senderId: 'current_user',
        recipientId: widget.partnerId,
        text: 'How about yours?',
        timestamp: now.subtract(const Duration(minutes: 3, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_002',
        senderId: 'current_user',
        recipientId: widget.partnerId,
        text: 'It was great! Just finished the project.',
        timestamp: now.subtract(const Duration(minutes: 4)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_001',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Hey! How was your day? 😊',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_000',
        senderId: widget.partnerId,
        recipientId: 'current_user',
        text: 'Good night, sleep well! ❤️',
        timestamp: yesterday,
        type: MessageType.text,
        status: MessageStatus.read,
      ),
    ];
  }

  /// Handle sending a message: save to SQLite, update UI, and auto-scroll
  Future<void> _sendMessage() async {
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

    // Optimistically update UI
    setState(() {
      _messages.insert(0, newMessage);
    });

    _messageController.clear();

    // Auto-scroll to newest message
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    // Persist to local SQLite database
    await _localDb.saveMessage(newMessage);

    // Transition status to 'sent' and update local database
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWithStatus(MessageStatus.sent);
        });
        await _localDb.updateMessageStatus(newMessage.id, MessageStatus.sent);
      }
    });

    // TODO: Phase 9 - Temporary Firebase Relay dispatch
    // TODO: Phase 8 - End-to-end payload encryption
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

          /// Chat Messages Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white38,
                    ),
                  )
                : GestureDetector(
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

        final isOldestOverall = index == messages.length - 1;
        final hasPrecedingMessage = index + 1 < messages.length;
        final isFirstMessageOfDay = isOldestOverall ||
            (hasPrecedingMessage &&
                !_isSameDay(
                    message.timestamp, messages[index + 1].timestamp));

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
