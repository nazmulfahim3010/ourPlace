import 'dart:convert';
import 'package:chatbox/models/message.dart';

/// Domain model representing an end-to-end encrypted transfer bundle of conversation messages (Phase 17).
///
/// Bundles a set of chat messages from an existing conversation thread for explicit
/// one-time sharing with an authorized Love Partner.
class SharedConversationBundle {
  /// Unique identifier for this transfer bundle
  final String shareId;

  /// Username of the account sharing the conversation (e.g. "@alex")
  final String senderUsername;

  /// Partner username whose conversation history is contained in this bundle (e.g. "@sarah")
  final String conversationPartner;

  /// List of messages in the shared conversation
  final List<ChatMessage> messages;

  /// Timestamp when the bundle was packaged
  final DateTime sharedAt;

  /// Total count of messages packaged
  final int totalCount;

  const SharedConversationBundle({
    required this.shareId,
    required this.senderUsername,
    required this.conversationPartner,
    required this.messages,
    required this.sharedAt,
    required this.totalCount,
  });

  /// Factory creating a bundle from a list of messages
  factory SharedConversationBundle.create({
    required String shareId,
    required String senderUsername,
    required String conversationPartner,
    required List<ChatMessage> messages,
    DateTime? sharedAt,
  }) {
    return SharedConversationBundle(
      shareId: shareId,
      senderUsername: senderUsername,
      conversationPartner: conversationPartner,
      messages: List.unmodifiable(messages),
      sharedAt: sharedAt ?? DateTime.now().toUtc(),
      totalCount: messages.length,
    );
  }

  /// Serialize bundle to JSON map
  Map<String, dynamic> toJson() => {
        'shareId': shareId,
        'senderUsername': senderUsername,
        'conversationPartner': conversationPartner,
        'messages': messages.map((m) => m.toJson()).toList(),
        'sharedAt': sharedAt.toIso8601String(),
        'totalCount': totalCount,
      };

  /// Deserialize bundle from JSON map
  factory SharedConversationBundle.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    final parsedMessages = rawMessages
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return SharedConversationBundle(
      shareId: json['shareId'] as String,
      senderUsername: json['senderUsername'] as String,
      conversationPartner: json['conversationPartner'] as String,
      messages: parsedMessages,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      totalCount: json['totalCount'] as int? ?? parsedMessages.length,
    );
  }

  /// Convert bundle to JSON string for E2EE payload encryption
  String toJsonString() => jsonEncode(toJson());

  /// Parse bundle from JSON string
  factory SharedConversationBundle.fromJsonString(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    return SharedConversationBundle.fromJson(json);
  }

  @override
  String toString() =>
      'SharedConversationBundle(shareId: $shareId, sender: $senderUsername, conversation: $conversationPartner, messages: $totalCount, sharedAt: $sharedAt)';
}
