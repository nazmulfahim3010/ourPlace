import 'dart:async';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/conversation.dart';
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
  Future<void> refreshConversations({String? currentUserId});
}

/// Local-first implementation backed by local storage and in-memory synchronization
class LocalConversationRepository implements ConversationRepository {
  static final LocalConversationRepository _instance =
      LocalConversationRepository._internal();

  static LocalConversationRepository get instance => _instance;

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

  void resetForTesting() {
    _cachedConversations = null;
  }

  void _sortConversations() {
    if (_cachedConversations == null) return;
    _cachedConversations!.sort((a, b) {
      if (a.isLoveConnection && !b.isLoveConnection) return -1;
      if (!a.isLoveConnection && b.isLoveConnection) return 1;

      final aTime = a.lastMessageAt ?? a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  @override
  Future<List<Conversation>> getConversations({String? currentUserId}) async {
    _cachedConversations ??= [];
    final effectiveUserId = currentUserId ?? AppConstants.currentUserId;

    // Dynamically discover all chat partners who have exchanged messages in SQLite
    try {
      final partners = await database.getDistinctChatPartners(currentUserId: effectiveUserId);
      for (final partnerUsername in partners) {
        final normPartner = partnerUsername.trim().toLowerCase();
        final cleanPartner = normPartner.replaceFirst(RegExp(r'^@+'), '');
        final formattedUsername = '@$cleanPartner';
        final existingIdx = _cachedConversations!.indexWhere(
          (c) => c.partner.username.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '') == cleanPartner,
        );

        final latestMsg = await database.getLatestMessageForPartner(
          partnerUsername,
          currentUserId: effectiveUserId,
        );
        final unreadCount = await database.getUnreadCountForPartner(
          partnerUsername,
          currentUserId: effectiveUserId,
        );

        if (existingIdx != -1) {
          // Update existing conversation with real message data
          _cachedConversations![existingIdx] =
              _cachedConversations![existingIdx].copyWith(
            lastMessage: latestMsg ?? _cachedConversations![existingIdx].lastMessage,
            lastMessageAt: latestMsg?.timestamp ?? _cachedConversations![existingIdx].lastMessageAt,
            unreadCount: unreadCount,
          );
        } else {
          // New partner discovered in SQLite messages: add conversation dynamically!
          final clean = cleanPartner;
          final displayName = clean.isNotEmpty
              ? clean[0].toUpperCase() + clean.substring(1)
              : clean;
          final newConv = Conversation(
            id: 'conv_$clean',
            partner: User(
              id: 'user_$clean',
              username: formattedUsername,
              displayName: displayName,
              isCurrentUser: false,
            ),
            lastMessage: latestMsg,
            lastMessageAt: latestMsg?.timestamp,
            unreadCount: unreadCount,
            isLoveConnection: false,
          );
          _cachedConversations!.add(newConv);
        }
      }
    } catch (_) {}

    _sortConversations();
    return List.unmodifiable(_cachedConversations!);
  }

  @override
  Future<void> refreshConversations({String? currentUserId}) async {
    final list = await getConversations(currentUserId: currentUserId);
    _conversationsStreamController.add(list);
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
    _cachedConversations ??= [];
    final index = _cachedConversations!.indexWhere(
      (c) => c.id == conversationId || c.partner.id == conversationId,
    );
    if (index != -1) {
      _cachedConversations![index] =
          _cachedConversations![index].copyWith(unreadCount: 0);
      _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
    }
  }

  @override
  Future<void> demoteLoveConnection({String? partnerUsername}) async {
    _cachedConversations ??= [];
    for (int i = 0; i < _cachedConversations!.length; i++) {
      if (_cachedConversations![i].isLoveConnection) {
        if (partnerUsername == null ||
            _cachedConversations![i].partner.username.toLowerCase() == partnerUsername.toLowerCase()) {
          _cachedConversations![i] = _cachedConversations![i].copyWith(isLoveConnection: false);
        }
      }
    }
    _sortConversations();
    _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
  }

  @override
  Future<Conversation> startOrGetConversation({
    required User partner,
    bool isLoveConnection = false,
  }) async {
    _cachedConversations ??= [];
    final cleanPartner = partner.username.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
    final existingIndex = _cachedConversations!.indexWhere(
      (c) => c.partner.username.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '') == cleanPartner,
    );

    if (existingIndex != -1) {
      var existing = _cachedConversations![existingIndex];
      if (isLoveConnection && !existing.isLoveConnection) {
        existing = existing.copyWith(
          isLoveConnection: true,
          partner: partner,
        );
      } else {
        existing = existing.copyWith(partner: partner);
      }
      _cachedConversations!.removeAt(existingIndex);
      _cachedConversations!.insert(0, existing);
      _sortConversations();
      _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
      return existing;
    }

    final newConversation = Conversation(
      id: 'conv_$cleanPartner',
      partner: partner,
      isLoveConnection: isLoveConnection,
      lastMessage: null,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
    );

    _cachedConversations!.insert(0, newConversation);
    _sortConversations();
    _conversationsStreamController.add(List.unmodifiable(_cachedConversations!));
    return newConversation;
  }
}
