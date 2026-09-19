import 'dart:async';
import 'dart:convert';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/love_note.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/relay_service.dart';

/// Representation of couple milestone achievements
class MilestoneBadge {
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;

  const MilestoneBadge({
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

/// Computed relationship statistics and milestone metrics
class RelationshipMilestones {
  final int daysTogether;
  final int monthsTogether;
  final int yearsTogether;
  final String durationText;
  final int totalMessages;
  final int mediaCount;
  final DateTime? firstMessageDate;
  final int daysUntilNextAnniversary;
  final List<MilestoneBadge> badges;

  const RelationshipMilestones({
    required this.daysTogether,
    required this.monthsTogether,
    required this.yearsTogether,
    required this.durationText,
    required this.totalMessages,
    required this.mediaCount,
    this.firstMessageDate,
    required this.daysUntilNextAnniversary,
    required this.badges,
  });
}

/// Abstract contract for couple-exclusive interactions and features (Phase 18)
abstract class CoupleFeaturesService {
  /// Stream emitting sender usernames when an inbound "Send luv" burst is received
  Stream<String> get luvBurstStream;

  /// Trigger a local luv burst event
  void emitLuvBurst(String senderUsername);

  /// Send an ephemeral "Send luv" heart burst to the connected partner
  Future<void> sendLuvBurst({
    required String partnerUsername,
    required String currentUsername,
  });

  /// Toggle an emoji reaction on a message locally and notify partner
  Future<void> toggleReaction({
    required String messageId,
    required String partnerUsername,
    required String currentUsername,
    required String emoji,
  });

  /// Handle an inbound reaction from partner
  Future<void> handleInboundReaction({
    required String messageId,
    required String senderUsername,
    required String emoji,
    required bool isRemove,
  });

  /// Compute anniversary, "Together Since" duration, and milestone badges
  RelationshipMilestones calculateMilestones({
    required DateTime? connectedAt,
    required List<ChatMessage> messages,
    DateTime? relativeNow,
  });

  /// Create and send a private Love Note / Letter
  Future<LoveNote> sendLoveNote({
    required String partnerUsername,
    required String currentUsername,
    required String title,
    required String body,
    String? tag,
    DateTime? openAt,
  });

  /// Handle inbound Love Note decrypted from relay
  Future<void> handleInboundLoveNote(LoveNote note);

  /// Get list of Love Notes exchanged with partner
  Future<List<LoveNote>> getLoveNotes(String partnerUsername);

  /// Watch reactive stream of Love Notes
  Stream<List<LoveNote>> watchLoveNotes(String partnerUsername);

  /// Mark a Love Note as unsealed / opened
  Future<void> markLoveNoteOpened(String noteId);

  /// Dispose any active streams/tickers
  void dispose();
}

/// Default production implementation of CoupleFeaturesService
class DefaultCoupleFeaturesService implements CoupleFeaturesService {
  final LocalDatabase _localDatabase;
  final RelayService _relayService;
  final EncryptionService? _encryptionService;

  final StreamController<String> _luvBurstController =
      StreamController<String>.broadcast();

  DefaultCoupleFeaturesService({
    required LocalDatabase localDatabase,
    required RelayService relayService,
    EncryptionService? encryptionService,
  })  : _localDatabase = localDatabase,
        _relayService = relayService,
        _encryptionService = encryptionService;

  EncryptionService? get encryptionService => _encryptionService;

  @override
  Stream<String> get luvBurstStream => _luvBurstController.stream;

  @override
  void emitLuvBurst(String senderUsername) {
    if (!_luvBurstController.isClosed) {
      _luvBurstController.add(senderUsername);
    }
  }

  @override
  Future<void> sendLuvBurst({
    required String partnerUsername,
    required String currentUsername,
  }) async {
    final cleanPartner = partnerUsername.startsWith('@')
        ? partnerUsername.substring(1)
        : partnerUsername;
    final cleanCurrent = currentUsername.startsWith('@')
        ? currentUsername.substring(1)
        : currentUsername;

    final envelope = EphemeralRelayEnvelope.loveLuvBurst(
      senderId: cleanCurrent,
      recipientId: cleanPartner,
    );

    await _relayService.enqueueMessage(envelope);
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String partnerUsername,
    required String currentUsername,
    required String emoji,
  }) async {
    final cleanCurrent = currentUsername.startsWith('@')
        ? currentUsername
        : '@$currentUsername';
    final cleanPartner = partnerUsername.startsWith('@')
        ? partnerUsername.substring(1)
        : partnerUsername;

    // Retrieve existing message to check previous reaction
    final messages = await _localDatabase.getMessagesForPartner(cleanPartner);
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final targetMsg = messages[msgIndex];
    final updatedMsg = targetMsg.withToggledReaction(cleanCurrent, emoji);
    final isRemove = updatedMsg.reactions?[cleanCurrent] == null;

    // Persist reaction update locally
    await _localDatabase.updateMessageReactions(
      messageId,
      updatedMsg.reactions,
    );

    // Notify partner over wire
    final envelope = EphemeralRelayEnvelope.messageReaction(
      senderId: cleanCurrent,
      recipientId: cleanPartner,
      messageId: messageId,
      emoji: emoji,
      isRemove: isRemove,
    );

    await _relayService.enqueueMessage(envelope);
  }

  @override
  Future<void> handleInboundReaction({
    required String messageId,
    required String senderUsername,
    required String emoji,
    required bool isRemove,
  }) async {
    final cleanSender = senderUsername.startsWith('@')
        ? senderUsername
        : '@$senderUsername';

    // Query messages by partner
    final cleanPartner = senderUsername.startsWith('@')
        ? senderUsername.substring(1)
        : senderUsername;
    final messages = await _localDatabase.getMessagesForPartner(cleanPartner);
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final targetMsg = messages[msgIndex];
    final currentReactions = Map<String, String>.from(targetMsg.reactions ?? {});

    if (isRemove) {
      currentReactions.remove(cleanSender);
    } else {
      currentReactions[cleanSender] = emoji;
    }

    await _localDatabase.updateMessageReactions(
      messageId,
      currentReactions.isEmpty ? null : currentReactions,
    );
  }

  @override
  RelationshipMilestones calculateMilestones({
    required DateTime? connectedAt,
    required List<ChatMessage> messages,
    DateTime? relativeNow,
  }) {
    final now = relativeNow ?? DateTime.now();
    final start = connectedAt ?? now;

    final diff = now.difference(start);
    final daysTogether = diff.inDays < 0 ? 0 : diff.inDays;
    final yearsTogether = daysTogether ~/ 365;
    final monthsTogether = (daysTogether % 365) ~/ 30;

    String durationText;
    if (daysTogether == 0) {
      durationText = 'Starting today ❤️';
    } else if (yearsTogether > 0) {
      durationText = '$yearsTogether yr, $monthsTogether mo together';
    } else if (monthsTogether > 0) {
      durationText = '$monthsTogether months together';
    } else {
      durationText = '$daysTogether days together';
    }

    // Next anniversary countdown (day of month milestone)
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysUntilNextAnniversary = start.day >= now.day
        ? start.day - now.day
        : (daysInMonth - now.day) + start.day;

    final totalMessages = messages.length;
    final mediaCount = messages.where((m) => m.mediaAttachment != null).length;
    final firstMessageDate = messages.isNotEmpty
        ? messages.map((m) => m.timestamp).reduce((a, b) => a.isBefore(b) ? a : b)
        : null;

    final badges = [
      MilestoneBadge(
        title: 'First Spark',
        description: 'Connected your Love Connection',
        icon: '✨',
        isUnlocked: connectedAt != null,
      ),
      MilestoneBadge(
        title: 'Sweet Talkers',
        description: 'Sent 10 or more private messages',
        icon: '💬',
        isUnlocked: totalMessages >= 10,
      ),
      MilestoneBadge(
        title: 'Chatterbox',
        description: 'Sent 100 or more messages',
        icon: '🔥',
        isUnlocked: totalMessages >= 100,
      ),
      MilestoneBadge(
        title: 'Memory Keeper',
        description: 'Shared 5 or more photos/voice notes',
        icon: '📸',
        isUnlocked: mediaCount >= 5,
      ),
      MilestoneBadge(
        title: 'Month of Love',
        description: 'Connected for 30 or more days',
        icon: '🌹',
        isUnlocked: daysTogether >= 30,
      ),
      MilestoneBadge(
        title: 'Golden Bond',
        description: 'Connected for 1 year or more',
        icon: '💎',
        isUnlocked: yearsTogether >= 1,
      ),
    ];

    return RelationshipMilestones(
      daysTogether: daysTogether,
      monthsTogether: monthsTogether,
      yearsTogether: yearsTogether,
      durationText: durationText,
      totalMessages: totalMessages,
      mediaCount: mediaCount,
      firstMessageDate: firstMessageDate,
      daysUntilNextAnniversary: daysUntilNextAnniversary,
      badges: badges,
    );
  }

  @override
  Future<LoveNote> sendLoveNote({
    required String partnerUsername,
    required String currentUsername,
    required String title,
    required String body,
    String? tag,
    DateTime? openAt,
  }) async {
    final noteId = 'note_${DateTime.now().millisecondsSinceEpoch}';
    final note = LoveNote(
      id: noteId,
      senderUsername: currentUsername,
      recipientUsername: partnerUsername,
      title: title,
      body: body,
      createdAt: DateTime.now().toUtc(),
      openAt: openAt,
      isOpened: false,
      tag: tag,
    );

    // Save locally
    await _localDatabase.saveLoveNote(note);

    // Encode note JSON
    final noteJson = jsonEncode(note.toJson());

    // Send across wire
    final cleanPartner = partnerUsername.startsWith('@')
        ? partnerUsername.substring(1)
        : partnerUsername;
    final cleanCurrent = currentUsername.startsWith('@')
        ? currentUsername.substring(1)
        : currentUsername;

    final envelope = EphemeralRelayEnvelope.loveNoteBundle(
      senderId: cleanCurrent,
      recipientId: cleanPartner,
      encryptedPayload: noteJson,
      noteId: noteId,
    );

    await _relayService.enqueueMessage(envelope);
    return note;
  }

  @override
  Future<void> handleInboundLoveNote(LoveNote note) async {
    await _localDatabase.saveLoveNote(note);
  }

  @override
  Future<List<LoveNote>> getLoveNotes(String partnerUsername) {
    return _localDatabase.getLoveNotes(partnerUsername);
  }

  @override
  Stream<List<LoveNote>> watchLoveNotes(String partnerUsername) {
    return _localDatabase.watchLoveNotes(partnerUsername);
  }

  @override
  Future<void> markLoveNoteOpened(String noteId) {
    return _localDatabase.markLoveNoteOpened(noteId);
  }

  @override
  void dispose() {
    _luvBurstController.close();
  }
}

/// In-memory mock implementation for hermetic unit and widget testing
class InMemoryCoupleFeaturesService implements CoupleFeaturesService {
  final List<LoveNote> _notes = [];
  final Map<String, Map<String, String>> _reactions = {};
  final StreamController<String> _luvBurstController =
      StreamController<String>.broadcast();
  final StreamController<List<LoveNote>> _notesStreamController =
      StreamController<List<LoveNote>>.broadcast();

  int luvBurstSentCount = 0;

  @override
  Stream<String> get luvBurstStream => _luvBurstController.stream;

  @override
  void emitLuvBurst(String senderUsername) {
    if (!_luvBurstController.isClosed) {
      _luvBurstController.add(senderUsername);
    }
  }

  @override
  Future<void> sendLuvBurst({
    required String partnerUsername,
    required String currentUsername,
  }) async {
    luvBurstSentCount++;
    emitLuvBurst(currentUsername);
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String partnerUsername,
    required String currentUsername,
    required String emoji,
  }) async {
    final current = _reactions[messageId] ?? {};
    if (current[currentUsername] == emoji) {
      current.remove(currentUsername);
    } else {
      current[currentUsername] = emoji;
    }
    _reactions[messageId] = current;
  }

  @override
  Future<void> handleInboundReaction({
    required String messageId,
    required String senderUsername,
    required String emoji,
    required bool isRemove,
  }) async {
    final current = _reactions[messageId] ?? {};
    if (isRemove) {
      current.remove(senderUsername);
    } else {
      current[senderUsername] = emoji;
    }
    _reactions[messageId] = current;
  }

  Map<String, String>? getReactions(String messageId) => _reactions[messageId];

  @override
  RelationshipMilestones calculateMilestones({
    required DateTime? connectedAt,
    required List<ChatMessage> messages,
    DateTime? relativeNow,
  }) {
    final now = relativeNow ?? DateTime.now();
    final start = connectedAt ?? now;
    final diff = now.difference(start);
    final daysTogether = diff.inDays < 0 ? 0 : diff.inDays;
    final yearsTogether = daysTogether ~/ 365;
    final monthsTogether = (daysTogether % 365) ~/ 30;

    String durationText = daysTogether == 0
        ? 'Starting today ❤️'
        : '$daysTogether days together';

    final totalMessages = messages.length;
    final mediaCount = messages.where((m) => m.mediaAttachment != null).length;

    return RelationshipMilestones(
      daysTogether: daysTogether,
      monthsTogether: monthsTogether,
      yearsTogether: yearsTogether,
      durationText: durationText,
      totalMessages: totalMessages,
      mediaCount: mediaCount,
      daysUntilNextAnniversary: 15,
      badges: [
        MilestoneBadge(
          title: 'First Spark',
          description: 'Connected',
          icon: '✨',
          isUnlocked: connectedAt != null,
        ),
        MilestoneBadge(
          title: 'Sweet Talkers',
          description: '10 messages',
          icon: '💬',
          isUnlocked: totalMessages >= 10,
        ),
      ],
    );
  }

  @override
  Future<LoveNote> sendLoveNote({
    required String partnerUsername,
    required String currentUsername,
    required String title,
    required String body,
    String? tag,
    DateTime? openAt,
  }) async {
    final note = LoveNote(
      id: 'mock_note_${_notes.length + 1}',
      senderUsername: currentUsername,
      recipientUsername: partnerUsername,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      openAt: openAt,
      isOpened: false,
      tag: tag,
    );
    _notes.insert(0, note);
    _notesStreamController.add(List.unmodifiable(_notes));
    return note;
  }

  @override
  Future<void> handleInboundLoveNote(LoveNote note) async {
    _notes.insert(0, note);
    _notesStreamController.add(List.unmodifiable(_notes));
  }

  @override
  Future<List<LoveNote>> getLoveNotes(String partnerUsername) async {
    return List.unmodifiable(_notes);
  }

  @override
  Stream<List<LoveNote>> watchLoveNotes(String partnerUsername) {
    return _notesStreamController.stream;
  }

  @override
  Future<void> markLoveNoteOpened(String noteId) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isOpened: true);
      _notesStreamController.add(List.unmodifiable(_notes));
    }
  }

  @override
  void dispose() {
    _luvBurstController.close();
    _notesStreamController.close();
  }
}
