import 'dart:async';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/services/relay_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Live production implementation of [RelayService] backed by Firebase Realtime Database.
///
/// In strict accordance with zero-knowledge, ephemeral messaging principles:
/// - Envelopes are stored only temporarily under `/relays/{recipientId}/{messageId}`.
/// - The payload is encrypted with authenticated E2EE before reaching Firebase.
/// - Immediate atomic purge (`.remove()`) occurs upon recipient delivery acknowledgement (ACK).
/// - Envelopes exceeding 24h TTL are automatically discarded and purged.
class FirebaseRelayService implements RelayService {
  final FirebaseDatabase _database;

  FirebaseRelayService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  String _sanitizeKey(String id) {
    return HashUtils.normalizeUsername(id).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  DatabaseReference _recipientRef(String recipientId) {
    final cleanId = _sanitizeKey(recipientId);
    return _database.ref('relays').child(cleanId);
  }

  DatabaseReference _messageRef(String recipientId, String messageId) {
    final cleanMsgId = messageId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return _recipientRef(recipientId).child(cleanMsgId);
  }

  @override
  Future<void> enqueueMessage(EphemeralRelayEnvelope envelope) async {
    if (envelope.isExpired()) return;

    try {
      final json = envelope.toJson();
      await _messageRef(envelope.recipientId, envelope.id).set(json);
    } catch (e) {
      debugPrint('FirebaseRelayService: enqueueMessage error: $e');
      rethrow;
    }
  }

  @override
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(String recipientId) async {
    try {
      final snapshot = await _recipientRef(recipientId).get();
      if (!snapshot.exists || snapshot.value == null) {
        return const [];
      }

      final rawMap = snapshot.value;
      if (rawMap is! Map) return const [];

      final now = DateTime.now().toUtc();
      final List<EphemeralRelayEnvelope> valid = [];

      for (final entry in rawMap.entries) {
        try {
          if (entry.value is Map) {
            final envelope = EphemeralRelayEnvelope.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
            if (envelope.isExpired(now)) {
              // Asynchronously purge expired message
              _messageRef(recipientId, envelope.id).remove().ignore();
            } else {
              valid.add(envelope);
            }
          }
        } catch (_) {}
      }

      valid.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return valid;
    } catch (e) {
      debugPrint('FirebaseRelayService: fetchPendingMessages error: $e');
      return const [];
    }
  }

  @override
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(String recipientId) {
    return _recipientRef(recipientId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return <EphemeralRelayEnvelope>[];

      final now = DateTime.now().toUtc();
      final List<EphemeralRelayEnvelope> valid = [];

      for (final entry in raw.entries) {
        try {
          if (entry.value is Map) {
            final envelope = EphemeralRelayEnvelope.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
            if (envelope.isExpired(now)) {
              _messageRef(recipientId, envelope.id).remove().ignore();
            } else {
              valid.add(envelope);
            }
          }
        } catch (_) {}
      }

      valid.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return valid;
    });
  }

  @override
  Future<bool> acknowledgeAndPurge(
    String messageId, {
    required String recipientId,
  }) async {
    try {
      await _messageRef(recipientId, messageId).remove();
      return true;
    } catch (e) {
      debugPrint('FirebaseRelayService: acknowledgeAndPurge error: $e');
      return false;
    }
  }

  @override
  Future<int> getPendingQueueCount(String recipientId) async {
    try {
      final snapshot = await _recipientRef(recipientId).get();
      if (!snapshot.exists || snapshot.value == null) return 0;
      final raw = snapshot.value;
      if (raw is Map) return raw.length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> purgeExpiredMessages() async {
    int purgedCount = 0;
    try {
      final snapshot = await _database.ref('relays').get();
      if (!snapshot.exists || snapshot.value == null) return 0;
      final raw = snapshot.value;
      if (raw is! Map) return 0;

      final now = DateTime.now().toUtc();
      for (final queueEntry in raw.entries) {
        if (queueEntry.value is Map) {
          final recipientId = queueEntry.key.toString();
          final messages = queueEntry.value as Map;
          for (final msgEntry in messages.entries) {
            if (msgEntry.value is Map) {
              try {
                final env = EphemeralRelayEnvelope.fromJson(
                  Map<String, dynamic>.from(msgEntry.value as Map),
                );
                if (env.isExpired(now)) {
                  await _messageRef(recipientId, env.id).remove();
                  purgedCount++;
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('FirebaseRelayService: purgeExpiredMessages error: $e');
    }
    return purgedCount;
  }
}
