import 'package:flutter_test/flutter_test.dart';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:drift/native.dart';

void main() {
  group('Security: Fail-Closed E2EE Tests', () {
    late AppDatabase appDb;
    late LocalDatabase localDb;
    late StandardE2EEEncryptionService encryptionService;
    late LocalChatRepository chatRepository;

    setUp(() async {
      appDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: appDb);
      encryptionService = StandardE2EEEncryptionService();
      await encryptionService.initializeUserKeys('test_user_alice');

      chatRepository = LocalChatRepository(
        database: localDb,
        encryptionService: encryptionService,
      );
    });

    tearDown(() async {
      await appDb.close();
    });

    test('Throws SecurityException and marks message failed when recipient public key is missing', () async {
      final message = ChatMessage(
        id: 'msg_fail_closed_1',
        senderId: 'current_user',
        recipientId: 'bob_without_key',
        text: 'Top secret plan',
        timestamp: DateTime.now(),
      );

      // Attempting to send message without bob having an account with a public key
      await expectLater(
        () => chatRepository.sendMessage(message),
        throwsA(isA<SecurityException>()),
      );

      // Verify the message in local database is marked as failed, never dispatched in cleartext
      final messages = await chatRepository.getMessages('bob_without_key');
      expect(messages.length, 1);
      expect(messages.first.status, MessageStatus.failed);
      expect(messages.first.text, 'Top secret plan');
    });
  });
}
