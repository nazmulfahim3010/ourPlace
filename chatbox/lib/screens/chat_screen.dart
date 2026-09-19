import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/models/media_attachment.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/models/user_presence.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/media/private_media_viewer_screen.dart';
import 'package:chatbox/widgets/chat_header.dart';
import 'package:chatbox/widgets/date_divider.dart';
import 'package:chatbox/widgets/floating_hearts_overlay.dart';
import 'package:chatbox/widgets/message_bubble.dart';
import 'package:chatbox/widgets/message_reaction_picker.dart';
import 'package:chatbox/widgets/chat_input_field.dart';
import 'package:chatbox/widgets/love_code_sheet.dart';
import 'package:chatbox/screens/couple/couple_milestones_screen.dart';
import 'package:chatbox/screens/memories/shared_memories_screen.dart';

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
  StreamSubscription<String>? _luvBurstSubscription;

  // Phase 15: Media Messaging state
  MediaAttachment? _pendingAttachment;
  List<int>? _pendingAttachmentBytes;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

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

    // 5. Phase 18: Luv burst stream
    _luvBurstSubscription = _chatRepository.coupleFeaturesService.luvBurstStream.listen((sender) {
      if (mounted) {
        FloatingHeartsOverlay.burst(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❤️ $sender sent you luv!'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2E2428),
          ),
        );
      }
    });
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
    _luvBurstSubscription?.cancel();
    _recordingTimer?.cancel();
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
    final att = _pendingAttachment;
    final attBytes = _pendingAttachmentBytes;

    if (text.isEmpty && att == null) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUserId,
      recipientId: widget.partnerId,
      text: text,
      timestamp: DateTime.now(),
      type: att?.type ?? MessageType.text,
      status: MessageStatus.sending,
      mediaAttachment: att,
    );

    // Optimistic UI update
    setState(() {
      _messages.insert(0, newMessage);
      _pendingAttachment = null;
      _pendingAttachmentBytes = null;
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
    if (att != null && attBytes != null) {
      await _chatRepository.sendMediaMessage(newMessage, attBytes);
    } else {
      await _chatRepository.sendMessage(newMessage);
    }

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

  void _openAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A4A4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.pinkAccent),
                title: const Text('Send Romantic Sunset Photo', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Encrypted client-side with AES-256-GCM', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final sampleBytes = await _chatRepository.mediaStorageService
                      .generateSampleMediaBytes(MessageType.image);
                  setState(() {
                    _pendingAttachment = MediaAttachment(
                      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
                      type: MessageType.image,
                      fileName: 'Sunset_Memory_${DateTime.now().hour}${DateTime.now().minute}.png',
                      mimeType: 'image/png',
                      fileSizeBytes: sampleBytes.length,
                    );
                    _pendingAttachmentBytes = sampleBytes;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_none_rounded, color: Colors.amberAccent),
                title: const Text('Record Voice Note', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Record voice clip with waveform scrubber', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startVoiceRecording();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  void _cancelVoiceRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _sendVoiceRecording() async {
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 3;
    _cancelVoiceRecording();
    final sampleAudio = await _chatRepository.mediaStorageService
        .generateSampleMediaBytes(MessageType.audio);

    final att = MediaAttachment(
      id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
      type: MessageType.audio,
      fileName: 'Voice_Note_${DateTime.now().hour}${DateTime.now().minute}.m4a',
      mimeType: 'audio/m4a',
      fileSizeBytes: sampleAudio.length,
      durationMs: duration * 1000,
    );

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUserId,
      recipientId: widget.partnerId,
      text: '',
      timestamp: DateTime.now(),
      type: MessageType.audio,
      status: MessageStatus.sending,
      mediaAttachment: att,
    );

    setState(() {
      _messages.insert(0, newMsg);
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    await _chatRepository.sendMediaMessage(newMsg, sampleAudio);
  }

  void _openMediaViewer(ChatMessage message) {
    if (message.mediaAttachment == null && message.type == MessageType.text) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateMediaViewerScreen(
          message: message,
          storageService: _chatRepository.mediaStorageService,
        ),
      ),
    );
  }

  /// Handle "Send luv" quick action with floating hearts (Phase 18)
  void _sendLuv() {
    FloatingHeartsOverlay.burst(context);
    _chatRepository.coupleFeaturesService.sendLuvBurst(
      partnerUsername: widget.partnerName,
      currentUsername: _currentUsername,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💕 Love sent!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF383838),
      ),
    );
  }

  void _handleMessageReaction(ChatMessage message) async {
    final emoji = await MessageReactionPicker.show(context);
    if (emoji != null) {
      await _chatRepository.coupleFeaturesService.toggleReaction(
        messageId: message.id,
        partnerUsername: widget.partnerName,
        currentUsername: _currentUsername,
        emoji: emoji,
      );
      final updated = await _chatRepository.getMessages(widget.partnerId);
      if (mounted) {
        setState(() {
          _messages = updated;
        });
      }
    }
  }

  void _openMemories() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedMemoriesScreen(
          partnerUsername: widget.partnerName,
          chatRepository: _chatRepository,
        ),
      ),
    );
  }

  void _openCoupleSpace() async {
    final conn = await _chatRepository.loveConnectionService.getLoveConnection(
      currentUserId: _currentUserId,
    );
    if (!mounted) return;
    if (conn == null || !conn.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couple Space requires an active Love Connection ❤️ Connect in Profile.'),
          backgroundColor: Color(0xFF383838),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoupleMilestonesScreen(
          loveConnection: conn,
          chatRepository: _chatRepository,
          currentUsername: _currentUsername,
        ),
      ),
    );
  }

  Future<void> _handleShareConversation() async {
    try {
      final conn = await _chatRepository.loveConnectionService.getLoveConnection(
        currentUserId: _currentUserId,
      );
      if (!mounted) return;

      if (conn == null || !conn.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need an active Love Connection to share conversations. Connect with your partner in Profile ❤️'),
            backgroundColor: Color(0xFF383838),
          ),
        );
        return;
      }

      await LoveCodeSheet.show(
        context,
        conversationPartner: widget.partnerName,
        currentUserId: _currentUserId,
        currentUsername: _currentUsername,
        lovePartnerUsername: conn.partnerUsername,
        sharingService: _chatRepository.conversationSharingService,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to share: $e'),
          backgroundColor: const Color(0xFF2E1A1A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingHeartsOverlay(
      child: Scaffold(
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
              onShareConversation: _handleShareConversation,
              onOpenMemories: _openMemories,
              onOpenCoupleSpace: _openCoupleSpace,
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
                        onMediaTap: _openMediaViewer,
                        onMessageReaction: _handleMessageReaction,
                      ),
                    ),
            ),

          /// Bottom Input Bar
          ChatInputField(
            controller: _messageController,
            onChanged: _onInputChanged,
            onSendPressed: _sendMessage,
            onAttachmentPressed: _openAttachmentOptions,
            onVoiceRecordPressed: _startVoiceRecording,
            isRecording: _isRecordingVoice,
            recordingDurationSeconds: _recordingSeconds,
            onCancelRecording: _cancelVoiceRecording,
            onSendRecording: _sendVoiceRecording,
            pendingAttachment: _pendingAttachment,
            onRemovePendingAttachment: () {
              setState(() {
                _pendingAttachment = null;
                _pendingAttachmentBytes = null;
              });
            },
          ),
        ],
      ),
    ),
  );
}
}

/// Chat message area with reverse scrolling, date grouping, and status tracking
class _ChatMessageArea extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String currentUserId;
  final Function(ChatMessage)? onMediaTap;
  final Function(ChatMessage)? onMessageReaction;

  const _ChatMessageArea({
    required this.messages,
    required this.scrollController,
    this.currentUserId = AppConstants.currentUserId,
    this.onMediaTap,
    this.onMessageReaction,
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
                onMediaTap: onMediaTap != null ? () => onMediaTap!(message) : null,
                onLongPress: onMessageReaction != null ? () => onMessageReaction!(message) : null,
                onReactionTap: onMessageReaction != null ? () => onMessageReaction!(message) : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
