import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/relay_service.dart';
import 'package:chatbox/services/sync_service.dart';

/// Relay wrapper whose purge always fails for the envelope IDs in [failPurgeFor].
class _FlakyPurgeRelay implements RelayService {
  final InMemoryFirebaseRelayService inner;
  final Set<String> failPurgeFor;
  final Map<String, int> enqueuedTypes = {};

  _FlakyPurgeRelay(this.inner, this.failPurgeFor);

  @override
  Future<void> enqueueMessage(EphemeralRelayEnvelope envelope) {
    enqueuedTypes[envelope.envelopeType] =
        (enqueuedTypes[envelope.envelopeType] ?? 0) + 1;
    return inner.enqueueMessage(envelope);
  }

  @override
  Future<List<EphemeralRelayEnvelope>> fetchPendingMessages(String recipientId) =>
      inner.fetchPendingMessages(recipientId);

  @override
  Stream<List<EphemeralRelayEnvelope>> watchPendingMessages(String recipientId) =>
      inner.watchPendingMessages(recipientId);

  @override
  Future<bool> acknowledgeAndPurge(String messageId, {required String recipientId}) {
    if (failPurgeFor.contains(messageId)) {
      throw Exception('simulated purge failure');
    }
    return inner.acknowledgeAndPurge(messageId, recipientId: recipientId);
  }

  @override
  Future<int> getPendingQueueCount(String recipientId) =>
      inner.getPendingQueueCount(recipientId);

  @override
  Future<int> purgeExpiredMessages() => inner.purgeExpiredMessages();
}

EphemeralRelayEnvelope _message(String id, String text, {int offsetMs = 0}) {
  return EphemeralRelayEnvelope.create(
    id: id,
    senderId: '@alice',
    recipientId: '@bob',
    ciphertextPayload: text,
    timestamp: DateTime.now().toUtc().add(Duration(milliseconds: offsetMs)),
  );
}

void main() {
  late AppDatabase db;
  late LocalDatabase localDb;
  late _FlakyPurgeRelay relay;
  late DefaultSyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    localDb = LocalDatabase(database: db);
    relay = _FlakyPurgeRelay(InMemoryFirebaseRelayService.isolated(), {});
    sync = DefaultSyncService(
      database: localDb,
      chatService: ChatService(relayService: relay),
      encryptionService: NoOpEncryptionService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('typing and presence signals are not stored as chat messages', () async {
    await relay.enqueueMessage(EphemeralRelayEnvelope.typing(
      senderId: '@alice',
      recipientId: '@bob',
      isTyping: true,
    ));
    await relay.enqueueMessage(EphemeralRelayEnvelope.presence(
      senderId: '@alice',
      recipientId: '@bob',
      isOnline: true,
    ));

    final processed = await sync.processInboundEnvelopes(currentUserId: '@bob');

    expect(processed, isEmpty);
    expect(await localDb.getMessagesForPartner('@alice', currentUserId: '@bob'), isEmpty);
    // Left in the relay for RealtimeService to consume
    expect(await relay.getPendingQueueCount('@bob'), 2);
    expect(relay.enqueuedTypes['delivery_receipt'], isNull);
  });

  test('concurrent drains process each envelope once', () async {
    await relay.enqueueMessage(_message('m1', 'hello'));

    final results = await Future.wait([
      sync.processInboundEnvelopes(currentUserId: '@bob'),
      sync.processInboundEnvelopes(currentUserId: '@bob'),
      sync.processInboundEnvelopes(currentUserId: '@bob'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(results.expand((r) => r).map((m) => m.id).toSet(), {'m1'});
    expect(relay.enqueuedTypes['delivery_receipt'], 1);
    expect(await relay.getPendingQueueCount('@bob'), 0);
  });

  test('a failing envelope does not block the ones behind it', () async {
    relay.failPurgeFor.add('bad');
    await relay.enqueueMessage(_message('bad', 'first', offsetMs: -1000));
    await relay.enqueueMessage(_message('good', 'second'));

    final processed = await sync.processInboundEnvelopes(currentUserId: '@bob');

    expect(processed.map((m) => m.id), ['good']);
    final stored = await localDb.getMessageById('good');
    expect(stored?.text, 'second');
  });

  test('a poison envelope is given up on after repeated failures', () async {
    relay.failPurgeFor.add('bad');
    await relay.enqueueMessage(_message('bad', 'poison'));

    for (var i = 0; i < 5; i++) {
      await sync.processInboundEnvelopes(currentUserId: '@bob');
    }
    relay.enqueuedTypes.clear();

    // Further drains skip it instead of re-running the handler
    final processed = await sync.processInboundEnvelopes(currentUserId: '@bob');
    expect(processed, isEmpty);
    expect(relay.enqueuedTypes['delivery_receipt'], isNull);
  });

  test('LocalChatRepository shares its couple services with the sync service', () {
    final repo = LocalChatRepository(
      database: localDb,
      chatService: ChatService(relayService: relay),
      encryptionService: NoOpEncryptionService(),
    );
    final repoSync = repo.syncService as DefaultSyncService;

    expect(repoSync.loveConnectionService, same(repo.loveConnectionService));
    expect(repoSync.conversationSharingService, same(repo.conversationSharingService));
    expect(repoSync.coupleFeaturesService, same(repo.coupleFeaturesService));
  });
}
