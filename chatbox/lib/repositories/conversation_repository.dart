import 'dart:async';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/conversation.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';

/// Abstract contract for managing conversations in the Inbox
abstract class ConversationRepository {
  Future<List<Conversation>> getConversations({String? currentUserId});
  Future<Conversation?> getLoveConnectionConversation({String? currentUserId});
  Stream<List<Conversation>> watchConversations({String? currentUserId});
  Future<void> markAsRead(String conversationId);
  Future<Conversation> startOrGetConversation({
    required User partner,
    bool isLoveConnection = false,
  });
  Future<void> demoteLoveConnection({String? partnerUsername});
}

/// Local-first implementation backed by local storage and in-memory synchronization
class LocalConversationRepository implements ConversationRepository {
  static final LocalConversationRepository _instance =
      LocalConversationRepository._internal();

  factory LocalConversationRepository({LocalDatabase? database}) {
    if (database != null) {
      _instance._database = database;
    }
    return _instance;
  }

  LocalConversationRepository._internal();

  LocalDatabase? _database;
  // Reserved for Phase 10 / message syncing
  LocalDatabase get database => _database ?? LocalDatabase();

  List<Conversation>? _cachedConversations;
  final StreamController<List<Conversation>> _conversationsStreamController =
      StreamController<List<Conversation>>.broadcast();

  List<Conversation> _createInitialSeedConversations() {
    final now = DateTime.now();

    return [
      Conversation(
        id: 'conv_love_01',
        partner: User(
          id: AppConstants.defaultPartnerId,
          username: '@twilight',
          displayName: 'Twilight',
          loveConnectionId: 'love_conn_01',
          isCurrentUser: false,
        ),
        lastMessage: ChatMessage(
          id: 'msg_love_01',
          senderId: AppConstants.defaultPartnerId,
          recipientId: AppConstants.currentUserId,
          text: "Can't wait to see you tonight ❤️",
          timestamp: now.subtract(const Duration(minutes: 2)),
          status: MessageStatus.delivered,
        ),
        unreadCount: 1,
        isLoveConnection: true,
        lastMessageAt: now.subtract(const Duration(minutes: 2)),
      ),
      Conversation(
        id: 'conv_sarah_02',
        partner: User(
          id: 'user_sarah_02',
          username: '@sarah',
          displayName: 'Sarah',
          isCurrentUser: false,
        ),
        lastMessage: ChatMessage(
          id: 'msg_sarah_02',
          senderId: 'user_sarah_02',
          recipientId: AppConstants.currentUserId,
          text: "Okay, I'll send it over soon",
          timestamp: now.subtract(const Duration(minutes: 38)),
          status: MessageStatus.read,
        ),
        unreadCount: 0,
        isLoveConnection: false,
        lastMessageAt: now.subtract(const Duration(minutes: 38)),
      ),
      Conversation(
        id: 'conv_rahim_03',
        partner: User(
          id: 'user_rahim_03',
          username: '@rahim',
          displayName: 'Rahim',
          isCurrentUser: false,
        ),
        lastMessage: ChatMessage(
          id: 'msg_rahim_03',
          senderId: 'user_rahim_03',
          recipientId: AppConstants.currentUserId,
          text: 'Thanks for your help earlier!',
          timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
          status: MessageStatus.read,
        ),
        unreadCount: 0,
        isLoveConnection: false,
        lastMessageAt: now.subtract(const Duration(hours: 1, minutes: 20)),
      ),
      Conversation(
        id: 'conv_elena_04',
        partner: User(
          id: 'user_elena_04',
          username: '@elena',
          displayName: 'Elena',
          isCurrentUser: false,
        ),
        lastMessage: ChatMessage(
          id: 'msg_elena_04',
          senderId: 'user_elena_04',
          recipientId: AppConstants.currentUserId,
          text: "Let's catch up this weekend!",
          timestamp: now.subtract(const Duration(days: 1)),
          status: MessageStatus.delivered,
        ),
        unreadCount: 2,
        isLoveConnection: false,
        lastMessageAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Future<List<Conversation>> getConversations({String? currentUserId}) async {
    _cachedConversations ??= _createInitialSeedConversations();
    return List.unmodifiable(_cachedConversations!);
  }

  @override
  Future<Conversation?> getLoveConnectionConversation({
    String? currentUserId,
  }) async {
    final list = await getConversations(currentUserId: currentUserId);
    try {
      return list.firstWhere((c) => c.isLoveConnection);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Conversation>> watchConversations({String? currentUserId}) async* {
    final list = await getConversations(currentUserId: currentUserId);
    yield list;
    yield* _conversationsStreamController.stream;
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    _cachedConversations ??= _createInitialSeedConversations();
    final index = _cachedConversations!.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _cachedConversations![index] =
          _cachedConversations![index].copyWith(unreadCount: 0);
      _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
    }
  }

  @override
  Future<void> demoteLoveConnection({String? partnerUsername}) async {
    _cachedConversations ??= _createInitialSeedConversations();
    for (int i = 0; i < _cachedConversations!.length; i++) {
      if (_cachedConversations![i].isLoveConnection) {
        if (partnerUsername == null ||
            _cachedConversations![i].partner.username.toLowerCase() == partnerUsername.toLowerCase()) {
          _cachedConversations![i] = _cachedConversations![i].copyWith(isLoveConnection: false);
        }
      }
    }
    _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
  }

  @override
  Future<Conversation> startOrGetConversation({
    required User partner,
    bool isLoveConnection = false,
  }) async {
    _cachedConversations ??= _createInitialSeedConversations();
    final existingIndex = _cachedConversations!
        .indexWhere((c) => c.partner.username.toLowerCase() == partner.username.toLowerCase());

    if (existingIndex != -1) {
      if (isLoveConnection && !_cachedConversations![existingIndex].isLoveConnection) {
        final updated = _cachedConversations![existingIndex].copyWith(
          isLoveConnection: true,
          partner: partner,
        );
        _cachedConversations!.removeAt(existingIndex);
        _cachedConversations!.insert(0, updated);
        _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
        return updated;
      }
      return _cachedConversations![existingIndex];
    }

    final newConversation = Conversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      partner: partner,
      isLoveConnection: isLoveConnection,
      lastMessageAt: DateTime.now(),
    );

    _cachedConversations!.insert(isLoveConnection ? 0 : 1, newConversation);
    _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
    return newConversation;
  }
}
