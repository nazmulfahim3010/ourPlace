import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/models/user_presence.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/widgets/chat_header.dart';
import 'package:chatbox/widgets/date_divider.dart';
import 'package:chatbox/widgets/message_bubble.dart';
import 'package:chatbox/widgets/chat_input_field.dart';

/// Main Chat Screen Widget (Phase 6 - Supporting Anonymous User Context & Sign Out)
class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String partnerId;
  final User? currentUser;
  final ChatRepository? repository;
  final AuthRepository? authRepository;

  const ChatScreen({
    super.key,
    this.partnerName = AppConstants.defaultPartnerName,
    this.partnerId = AppConstants.defaultPartnerId,
    this.currentUser,
    this.repository,
    this.authRepository,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final ChatRepository _chatRepository;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  // Phase 13: Real-Time state & subscriptions
  bool _isPartnerTyping = false;
  UserPresence? _partnerPresence;
  StreamSubscription<bool>? _typingSubscription;
  StreamSubscription<UserPresence>? _presenceSubscription;
  StreamSubscription<List<ChatMessage>>? _messageSubscription;

  String get _currentUserId => widget.currentUser?.id ?? AppConstants.currentUserId;
  String get _currentUsername => widget.currentUser?.username ?? 'You';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatRepository = widget.repository ?? LocalChatRepository();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessagesFromRepository();
    _initRealtimeSubscriptions();
  }

  void _initRealtimeSubscriptions() {
    // 1. Reactive messages stream from local SQLite
    _messageSubscription = _chatRepository
        .watchMessages(widget.partnerId)
        .listen((updatedList) {
      if (mounted && updatedList.isNotEmpty) {
        setState(() {
          _messages = updatedList;
        });
      }
    });

    // 2. Typing indicator stream
    _typingSubscription = _chatRepository.realtimeService
        .watchTyping(
          currentUserId: _currentUserId,
          partnerId: widget.partnerId,
        )
        .listen((isTyping) {
      if (mounted) {
        setState(() {
          _isPartnerTyping = isTyping;
        });
      }
    });

    // 3. Presence stream
    _presenceSubscription = _chatRepository.realtimeService
        .watchPresence(
          currentUserId: _currentUserId,
          partnerId: widget.partnerId,
        )
        .listen((presence) {
      if (mounted) {
        setState(() {
          _partnerPresence = presence;
        });
      }
    });

    // 4. Update own presence to online
    _chatRepository.realtimeService.updatePresence(
      currentUserId: _currentUserId,
      partnerId: widget.partnerId,
      isOnline: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _chatRepository.realtimeService.pause();
    } else if (state == AppLifecycleState.resumed) {
      _chatRepository.realtimeService.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
    _messageSubscription?.cancel();
    _chatRepository.realtimeService.pause();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load persisted messages via ChatRepository
  Future<void> _loadMessagesFromRepository() async {
    try {
      final storedMessages =
          await _chatRepository.getMessages(widget.partnerId);

      if (storedMessages.isEmpty) {
        final seedMessages = _generateInitialSeedMessages();
        await _chatRepository.seedInitialMessages(seedMessages);
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
      // Phase 12: Mark conversation as read and emit read receipts
      await _chatRepository.markConversationAsRead(
        widget.partnerId,
        currentUserId: _currentUserId,
      );
    } catch (e) {
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
        recipientId: _currentUserId,
        text: "Let's get dinner together soon! 🍕",
        timestamp: now.subtract(const Duration(minutes: 1, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_004',
        senderId: widget.partnerId,
        recipientId: _currentUserId,
        text: "Pretty good! Can't wait to celebrate with you 🎉",
        timestamp: now.subtract(const Duration(minutes: 2)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_003',
        senderId: _currentUserId,
        recipientId: widget.partnerId,
        text: 'How about yours?',
        timestamp: now.subtract(const Duration(minutes: 3, seconds: 30)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_002',
        senderId: _currentUserId,
        recipientId: widget.partnerId,
        text: 'It was great! Just finished the project.',
        timestamp: now.subtract(const Duration(minutes: 4)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_001',
        senderId: widget.partnerId,
        recipientId: _currentUserId,
        text: 'Hey! How was your day? 😊',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: MessageType.text,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'seed_000',
        senderId: widget.partnerId,
        recipientId: _currentUserId,
        text: 'Good night, sleep well! ❤️',
        timestamp: yesterday,
        type: MessageType.text,
        status: MessageStatus.read,
      ),
    ];
  }

  /// Send message: update UI, delegate persistence and dispatch to ChatRepository
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUserId,
      recipientId: widget.partnerId,
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.sending,
    );

    // Optimistic UI update
    setState(() {
      _messages.insert(0, newMessage);
    });

    _messageController.clear();

    // Auto-scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    // Save and dispatch through ChatRepository
    await _chatRepository.sendMessage(newMessage);

    // Immediately clear typing state
    _chatRepository.realtimeService.sendTyping(
      currentUserId: _currentUserId,
      partnerId: widget.partnerId,
      isTyping: false,
    );

    // Simulate transition to 'sent'
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWithStatus(MessageStatus.sent);
        });
        await _chatRepository.updateMessageStatus(
          newMessage.id,
          MessageStatus.sent,
        );
      }
    });
  }

  void _onInputChanged(String text) {
    _chatRepository.realtimeService.sendTyping(
      currentUserId: _currentUserId,
      partnerId: widget.partnerId,
      isTyping: text.trim().isNotEmpty,
    );
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
            currentUsername: _currentUsername,
            isTyping: _isPartnerTyping,
            presenceText: _partnerPresence?.statusText,
            onSendLuv: _sendLuv,
            onSignOut: widget.authRepository != null
                ? () async {
                    await widget.authRepository!.signOut();
                  }
                : null,
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
                      currentUserId: _currentUserId,
                    ),
                  ),
          ),

          /// Bottom Input Bar
          ChatInputField(
            controller: _messageController,
            onChanged: _onInputChanged,
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
  final String currentUserId;

  const _ChatMessageArea({
    required this.messages,
    required this.scrollController,
    this.currentUserId = AppConstants.currentUserId,
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
                isSent: message.isSentBy(currentUserId),
                showTimestamp: showTimestamp,
              ),
            ),
          ],
        );
      },
    );
  }
}
