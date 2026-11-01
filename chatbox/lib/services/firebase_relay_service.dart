import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/services/firebase_rest_client.dart';
import 'package:chatbox/services/relay_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Live production implementation of [RelayService] backed by Firebase Realtime Database
/// with direct REST HTTP fallback for cross-platform resilience.
///
/// In strict accordance with zero-knowledge, ephemeral messaging principles:
/// - Envelopes are stored only temporarily under `/relays/{recipientId}/{messageId}`.
/// - The payload is encrypted with authenticated E2EE before reaching Firebase.
/// - Immediate atomic purge (`.remove()`) occurs upon recipient delivery acknowledgement (ACK).
/// - Envelopes exceeding 24h TTL are automatically discarded and purged.
class FirebaseRelayService implements RelayService {
  final FirebaseDatabase _database;
  final FirebaseRestDatabaseClient _restClient;

  FirebaseRelayService({
    FirebaseDatabase? database,
    FirebaseRestDatabaseClient? restClient,
  })  : _database = database ?? _defaultDatabase(),
        _restClient = restClient ?? FirebaseRestDatabaseClient();

  static FirebaseDatabase _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: AppConstants.firebaseDatabaseUrl,
      );
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

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

    final cleanRecipient = _sanitizeKey(envelope.recipientId);
    final cleanMsgId = envelope.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final json = envelope.toJson();

    // 1. Direct REST write
    final restSuccess = await _restClient.put('relays/$cleanRecipient/$cleanMsgId', json);

    // 2. Native SDK write
    try {
      await _messageRef(envelope.recipientId, envelope.id).set(json);
    } catch (e) {
      debugPrint('FirebaseRelayService native enqueue notice: $e');
      if (!restSuccess) {
        rethrow;
      }
    }
  }

  @override
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(String recipientId) async {
    final cleanRecipient = _sanitizeKey(recipientId);
    final now = DateTime.now().toUtc();
    Map? rawMap;

    // 1. Try native Firebase SDK
    try {
      final snapshot = await _recipientRef(recipientId).get();
      if (snapshot.exists && snapshot.value is Map) {
        rawMap = snapshot.value as Map;
      }
    } catch (e) {
      debugPrint('FirebaseRelayService native fetch notice: $e');
    }

    // 2. Fallback to direct REST HTTP
    if (rawMap == null) {
      try {
        final data = await _restClient.get('relays/$cleanRecipient');
        if (data is Map) {
          rawMap = data;
        }
      } catch (e) {
        debugPrint('FirebaseRelayService REST fetch error: $e');
      }
    }

    if (rawMap == null) return const [];

    final List<EphemeralRelayEnvelope> valid = [];
    for (final entry in rawMap.entries) {
      try {
        if (entry.value is Map) {
          final envelope = EphemeralRelayEnvelope.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (envelope.isExpired(now)) {
            acknowledgeAndPurge(envelope.id, recipientId: recipientId).ignore();
          } else {
            valid.add(envelope);
          }
        }
      } catch (_) {}
    }

    valid.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return valid;
  }

  @override
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(String recipientId) {
    try {
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
      }).handleError((_) => <EphemeralRelayEnvelope>[]);
    } catch (_) {
      return const Stream<List<EphemeralRelayEnvelope>>.empty();
    }
  }

  @override
  Future<bool> acknowledgeAndPurge(
    String messageId, {
    required String recipientId,
  }) async {
    final cleanRecipient = _sanitizeKey(recipientId);
    final cleanMsgId = messageId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

    // 1. REST delete
    final restOk = await _restClient.delete('relays/$cleanRecipient/$cleanMsgId');

    // 2. Native delete
    try {
      await _messageRef(recipientId, messageId).remove();
    } catch (e) {
      debugPrint('FirebaseRelayService native purge notice: $e');
    }

    return restOk;
  }

  @override
  Future<int> getPendingQueueCount(String recipientId) async {
    final cleanRecipient = _sanitizeKey(recipientId);
    try {
      final snapshot = await _recipientRef(recipientId).get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).length;
      }
    } catch (_) {}

    try {
      final data = await _restClient.get('relays/$cleanRecipient');
      if (data is Map) return data.length;
    } catch (_) {}

    return 0;
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
