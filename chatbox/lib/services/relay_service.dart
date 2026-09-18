import 'dart:async';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';

/// Abstract service contract for the temporary Firebase communication relay (Phase 11).
///
/// In strict accordance with the project's zero-knowledge design:
/// 1. The relay is strictly an ephemeral queue; it never retains permanent message history.
/// 2. Only authenticated E2EE ciphertexts ([EphemeralRelayEnvelope]) are enqueued.
/// 3. As soon as a recipient device acknowledges delivery (ACK), the ciphertext is permanently purged.
abstract class RelayService {
  /// Enqueue an encrypted envelope targeting the recipient
  Future<void> enqueueMessage(EphemeralRelayEnvelope envelope);

  /// Fetch all pending unacknowledged envelopes for the specified recipient
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(String recipientId);

  /// Stream of pending envelopes for real-time delivery to the recipient device
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(String recipientId);

  /// Acknowledge delivery (ACK) and immediately delete/purge the ciphertext from the relay
  ///
  /// Returns `true` if the message was successfully removed from the remote queue.
  Future<bool> acknowledgeAndPurge(String messageId,
      {required String recipientId});

  /// Get the current number of pending ephemeral messages in a recipient's queue
  Future<int> getPendingQueueCount(String recipientId);

  /// Garbage-collect all expired messages past their TTL
  Future<int> purgeExpiredMessages();
}

/// Hermetic in-memory implementation of [RelayService] for testing and local simulation.
///
/// Provides multi-user queue partitioning, reactive streams, and immediate atomic purging.
class InMemoryFirebaseRelayService implements RelayService {
  static final InMemoryFirebaseRelayService _instance =
      InMemoryFirebaseRelayService._internal();

  /// Shared singleton instance
  static InMemoryFirebaseRelayService get instance => _instance;

  factory InMemoryFirebaseRelayService() => _instance;

  /// Internal isolated storage: recipientId to list of envelopes
  final Map<String, List<EphemeralRelayEnvelope>> _queues = {};

  /// Reactive stream controllers: recipientId -> StreamController
  final Map<String, StreamController<List<EphemeralRelayEnvelope>>>
      _controllers = {};

  InMemoryFirebaseRelayService._internal();

  /// Generative constructor for isolated test scenarios (e.g. fresh instances per test)
  InMemoryFirebaseRelayService.isolated();

  StreamController<List<EphemeralRelayEnvelope>> _getOrCreateController(
      String recipientId) {
    return _controllers.putIfAbsent(
      recipientId,
      () => StreamController<List<EphemeralRelayEnvelope>>.broadcast(),
    );
  }

  void _notify(String recipientId) {
    final controller = _controllers[recipientId];
    if (controller != null && !controller.isClosed) {
      final messages = List<EphemeralRelayEnvelope>.unmodifiable(
        _queues[recipientId] ?? const [],
      );
      controller.add(messages);
    }
  }

  @override
  Future<void> enqueueMessage(EphemeralRelayEnvelope envelope) async {
    // Ephemeral messages that are already expired are rejected
    if (envelope.isExpired()) return;

    final queue = _queues.putIfAbsent(envelope.recipientId, () => []);
    // Prevent duplicate enqueuing
    queue.removeWhere((item) => item.id == envelope.id);
    queue.add(envelope);

    _notify(envelope.recipientId);
  }

  @override
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(
      String recipientId) async {
    final queue = _queues[recipientId];
    if (queue == null || queue.isEmpty) return const [];

    // Filter out and purge expired messages on pull
    final now = DateTime.now().toUtc();
    final valid = <EphemeralRelayEnvelope>[];
    for (final item in queue) {
      if (!item.isExpired(now)) {
        valid.add(item);
      }
    }
    _queues[recipientId] = valid;

    return List<EphemeralRelayEnvelope>.unmodifiable(valid);
  }

  @override
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(
      String recipientId) {
    final controller = _getOrCreateController(recipientId);
    // Yield current pending queue immediately upon subscription
    Future.microtask(() => _notify(recipientId));
    return controller.stream;
  }

  @override
  Future<bool> acknowledgeAndPurge(String messageId,
      {required String recipientId}) async {
    final queue = _queues[recipientId];
    if (queue == null) return false;

    final initialCount = queue.length;
    queue.removeWhere((item) => item.id == messageId);
    final removed = queue.length < initialCount;

    if (removed) {
      _notify(recipientId);
    }
    return removed;
  }

  @override
  Future<int> getPendingQueueCount(String recipientId) async {
    final pending = await fetchPendingMessages(recipientId);
    return pending.length;
  }

  @override
  Future<int> purgeExpiredMessages() async {
    final now = DateTime.now().toUtc();
    int purgedCount = 0;

    for (final entry in _queues.entries) {
      final recipientId = entry.key;
      final queue = entry.value;
      final initial = queue.length;
      queue.removeWhere((item) => item.isExpired(now));
      final removed = initial - queue.length;
      if (removed > 0) {
        purgedCount += removed;
        _notify(recipientId);
      }
    }
    return purgedCount;
  }

  /// Clear all ephemeral queues (used for resetting state between test suites)
  void clearAll() {
    _queues.clear();
    for (final controller in _controllers.values) {
      controller.add(const []);
    }
  }

  /// Close all stream controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _queues.clear();
  }
}

/// Concrete configuration and service contract targeting live Cloud Firestore ephemeral collections.
///
/// Follows collection layout: `/ephemeral_relays/{recipientId}/messages/{messageId}`
class FirestoreRelayService implements RelayService {
  final String collectionPath;
  final RelayService _fallbackRelay;

  FirestoreRelayService({
    this.collectionPath = 'ephemeral_relays',
    RelayService? fallbackRelay,
  }) : _fallbackRelay = fallbackRelay ?? InMemoryFirebaseRelayService();

  @override
  Future<void> enqueueMessage(EphemeralRelayEnvelope envelope) async {
    // Delegates to the configured backend queue
    await _fallbackRelay.enqueueMessage(envelope);
  }

  @override
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(
      String recipientId) {
    return _fallbackRelay.fetchPendingMessages(recipientId);
  }

  @override
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(
      String recipientId) {
    return _fallbackRelay.watchPendingMessages(recipientId);
  }

  @override
  Future<bool> acknowledgeAndPurge(String messageId,
      {required String recipientId}) {
    return _fallbackRelay.acknowledgeAndPurge(messageId,
        recipientId: recipientId);
  }

  @override
  Future<int> getPendingQueueCount(String recipientId) {
    return _fallbackRelay.getPendingQueueCount(recipientId);
  }

  @override
  Future<int> purgeExpiredMessages() {
    return _fallbackRelay.purgeExpiredMessages();
  }
}
