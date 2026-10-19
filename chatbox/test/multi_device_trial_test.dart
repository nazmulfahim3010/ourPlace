import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/love_connection.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/encrypted_payload.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/services/auth_service.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/love_connection_service.dart';
import 'package:chatbox/services/relay_service.dart';
import 'package:chatbox/services/sync_service.dart';
import 'package:chatbox/services/user_directory_service.dart';
import 'package:chatbox/core/utils/crypto_key_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalDatabase localDb;
  late InMemoryFirebaseRelayService relayService;
  late ChatService chatService;
  late InMemoryUserDirectoryService userDirectory;
  late StandardE2EEEncryptionService encryptionService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    localDb = LocalDatabase(database: db);
    relayService = InMemoryFirebaseRelayService.isolated();
    chatService = ChatService(relayService: relayService);
    userDirectory = InMemoryUserDirectoryService();
    DefaultUserDirectoryService().setDelegate(userDirectory);
    encryptionService = StandardE2EEEncryptionService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Stage 1 — Multi-Device Trial Bridges', () {
    test('Bridge 1: resolveRecipientPublicKey resolves partner public key from LoveConnection', () async {
      final chatRepo = LocalChatRepository(
        database: localDb,
        chatService: chatService,
        encryptionService: encryptionService,
      );

      // Device A has only @alex in userAccounts (simulating real Phone A)
      // Partner @twilight is NOT in localDb.userAccounts!
      // But @alex and @twilight formed a Love Connection
      final partnerKeyPair = await CryptoKeyUtils.generateX25519KeyPair();
      final partnerPubKey = await CryptoKeyUtils.encodePublicKey(partnerKeyPair);

      final loveConn = LoveConnection(
        id: 'love_conn_alex_twilight',
        userId: 'acc_alex_123',
        partnerUsername: '@twilight',
        partnerPublicKey: partnerPubKey,
        status: LoveConnectionStatus.connected,
        createdAt: DateTime.now(),
      );
      await localDb.saveLoveConnection(loveConn);

      // Verify resolveRecipientPublicKey successfully resolves @twilight from LoveConnection
      final resolvedKey = await chatRepo.resolveRecipientPublicKey('@twilight');
      expect(resolvedKey, equals(partnerPubKey));

      // Also verify sendMessage succeeds without throwing SecurityException
      await encryptionService.initializeUserKeys('acc_alex_123');
      final message = ChatMessage(
        id: 'msg_trial_001',
        senderId: '@alex',
        recipientId: '@twilight',
        text: 'Hello my love, this is encrypted!',
        timestamp: DateTime.now(),
      );

      await expectLater(chatRepo.sendMessage(message), completes);

      // Verify envelope in relay is properly encrypted
      final pending = await relayService.fetchPendingMessages('@twilight');
      expect(pending.length, equals(1));
      expect(pending.first.ciphertextPayload, isNot(contains('Hello my love')));
    });

    test('Bridge 1b: resolveRecipientPublicKey falls back to UserDirectoryService', () async {
      final chatRepo = LocalChatRepository(
        database: localDb,
        chatService: chatService,
        encryptionService: encryptionService,
      );

      // User @bob published their key in remote directory
      final bobKeyPair = await CryptoKeyUtils.generateX25519KeyPair();
      final bobPubKey = await CryptoKeyUtils.encodePublicKey(bobKeyPair);
      await userDirectory.publishProfile(
        DirectoryProfile(
          accountId: 'acc_bob_999',
          username: '@bob',
          publicIdentityKey: bobPubKey,
          lastSeen: DateTime.now(),
        ),
      );

      // Local phone has no @bob in accounts and no LoveConnection with @bob
      final resolvedKey = await chatRepo.resolveRecipientPublicKey('@bob');
      expect(resolvedKey, equals(bobPubKey));
    });

    test('Bridge 2: Reactive Inbound Relay Listener automatically triggers message ingestion', () async {
      final syncService = DefaultSyncService(
        database: localDb,
        chatService: chatService,
        encryptionService: encryptionService,
      );

      // Initialize recipient keys for @twilight
      await encryptionService.initializeUserKeys('acc_twilight_123');
      final twilightPub = await encryptionService.getPublicIdentityKey();

      // Alice encrypts a message for @twilight
      final aliceKeyPair = await CryptoKeyUtils.generateX25519KeyPair();
      final alicePub = await CryptoKeyUtils.encodePublicKey(aliceKeyPair);
      final secret = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: aliceKeyPair,
        remotePublicKey: CryptoKeyUtils.decodePublicKey(twilightPub),
      );
      final msgKey = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secret);
      final box = await CryptoKeyUtils.encryptAesGcm(
        plaintext: 'Surprise love message ❤️',
        secretKey: msgKey,
      );
      final envelopePayload = EncryptedPayload(
        version: 1,
        senderPublicKey: alicePub,
        nonce: CryptoKeyUtils.encodePublicKeyBytes(box.nonce),
        ciphertext: CryptoKeyUtils.encodePublicKeyBytes(box.cipherText),
        mac: CryptoKeyUtils.encodePublicKeyBytes(box.mac.bytes),
        createdAt: DateTime.now(),
      ).serialize();

      // Start reactive relay listener on @twilight's device
      syncService.startRelayListener(currentUserId: '@twilight');

      // Put envelope onto wire
      await relayService.enqueueMessage(
        EphemeralRelayEnvelope(
          id: 'env_realtime_001',
          senderId: '@alex',
          recipientId: '@twilight',
          ciphertextPayload: envelopePayload,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          envelopeType: 'message',
        ),
      );

      // Allow stream cycle to execute
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify message was automatically pulled from relay into local SQLite
      final storedMessages = await localDb.getMessagesForPartner('@alex', currentUserId: '@twilight');
      expect(storedMessages.length, equals(1));
      expect(storedMessages.first.text, equals('Surprise love message ❤️'));

      // Verify relay was purged (ACKed)
      final remainingInRelay = await relayService.fetchPendingMessages('@twilight');
      expect(remainingInRelay.isEmpty, isTrue);

      syncService.stopRelayListener();
    });

    test('Bridge 3: Remote Directory Publishing on Registration & Partner Discovery', () async {
      final authService = LocalAuthService(
        database: localDb,
        encryptionService: encryptionService,
      );

      // Register new user @twilight
      final registered = await authService.register(
        username: 'twilight',
        password: 'password123',
      );
      expect(registered.username, equals('@twilight'));

      // Verify profile was published to UserDirectoryService
      final remoteProfile = await userDirectory.lookupProfile('@twilight');
      expect(remoteProfile, isNotNull);
      expect(remoteProfile!.username, equals('@twilight'));
      expect(remoteProfile.publicIdentityKey.isNotEmpty, isTrue);

      // Another phone searching for @twilight finds them from directory
      final loveService = DefaultLoveConnectionService(
        database: localDb,
        relayService: relayService,
        conversationRepository: LocalConversationRepository(database: localDb),
      );

      final discoveredPartner = await loveService.searchPartnerByUsername('twilight');
      expect(discoveredPartner, isNotNull);
      expect(discoveredPartner!.username, equals('@twilight'));
      expect(discoveredPartner.publicIdentityKey, equals(remoteProfile.publicIdentityKey));
    });
  });

  group('Stage 2 — Multi-User Messaging & Username Tracking', () {
    test('User can converse with multiple distinct users (@bob, @charlie, @dana) tracked by username', () async {
      final chatRepo = LocalChatRepository(
        database: localDb,
        chatService: chatService,
        encryptionService: encryptionService,
      );
      final convRepo = LocalConversationRepository(database: localDb);

      // Register Alice
      await encryptionService.initializeUserKeys('acc_alice_1');

      // Publish 3 distinct users in UserDirectoryService with X25519 keys
      final users = ['@bob', '@charlie', '@dana'];
      final userKeys = <String, String>{};

      for (final username in users) {
        final keyPair = await CryptoKeyUtils.generateX25519KeyPair();
        final pubKey = await CryptoKeyUtils.encodePublicKey(keyPair);
        userKeys[username] = pubKey;
        await userDirectory.publishProfile(
          DirectoryProfile(
            accountId: 'acc_${username.replaceAll('@', '')}',
            username: username,
            publicIdentityKey: pubKey,
            lastSeen: DateTime.now(),
          ),
        );
      }

      // Alice sends messages to Bob, Charlie, and Dana
      for (final username in users) {
        final message = ChatMessage(
          id: 'msg_to_${username.replaceAll('@', '')}',
          senderId: '@alice',
          recipientId: username,
          text: 'Hello $username from Alice!',
          timestamp: DateTime.now(),
        );
        await chatRepo.sendMessage(message);

        // Verify relay has encrypted envelope for this recipient
        final pending = await relayService.fetchPendingMessages(username);
        expect(pending.length, equals(1));
        expect(pending.first.recipientId, equals(username));
      }

      // Verify LocalConversationRepository discovers all distinct partners from SQLite
      final conversations = await convRepo.getConversations(currentUserId: '@alice');
      final convUsernames = conversations.map((c) => c.partner.username.toLowerCase()).toList();

      for (final username in users) {
        expect(convUsernames, contains(username.toLowerCase()));
      }
    });

    test('Inbound messages from new usernames dynamically create inbox conversations', () async {
      final syncService = DefaultSyncService(
        database: localDb,
        chatService: chatService,
        encryptionService: encryptionService,
      );
      final convRepo = LocalConversationRepository(database: localDb);

      // Current user is @alice
      await encryptionService.initializeUserKeys('acc_alice_1');
      final alicePub = await encryptionService.getPublicIdentityKey();

      // Incoming message from a completely new user @frank
      final frankKeyPair = await CryptoKeyUtils.generateX25519KeyPair();
      final frankPub = await CryptoKeyUtils.encodePublicKey(frankKeyPair);
      final secret = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: frankKeyPair,
        remotePublicKey: CryptoKeyUtils.decodePublicKey(alicePub),
      );
      final msgKey = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secret);
      final box = await CryptoKeyUtils.encryptAesGcm(
        plaintext: 'Hi Alice, this is Frank!',
        secretKey: msgKey,
      );
      final payload = EncryptedPayload(
        version: 1,
        senderPublicKey: frankPub,
        nonce: CryptoKeyUtils.encodePublicKeyBytes(box.nonce),
        ciphertext: CryptoKeyUtils.encodePublicKeyBytes(box.cipherText),
        mac: CryptoKeyUtils.encodePublicKeyBytes(box.mac.bytes),
        createdAt: DateTime.now(),
      ).serialize();

      await relayService.enqueueMessage(
        EphemeralRelayEnvelope(
          id: 'env_frank_001',
          senderId: '@frank',
          recipientId: '@alice',
          ciphertextPayload: payload,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          envelopeType: 'message',
        ),
      );

      // Process inbound
      final processed = await syncService.processInboundEnvelopes(currentUserId: '@alice');
      expect(processed.length, equals(1));
      expect(processed.first.text, equals('Hi Alice, this is Frank!'));

      // Check that @frank now appears in conversations automatically
      final conversations = await convRepo.getConversations(currentUserId: '@alice');
      final frankConv = conversations.firstWhere(
        (c) => c.partner.username.toLowerCase() == '@frank',
      );
      expect(frankConv, isNotNull);
      expect(frankConv.lastMessage?.text, equals('Hi Alice, this is Frank!'));
      expect(frankConv.unreadCount, equals(1));
    });
  });
}
