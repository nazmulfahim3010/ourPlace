import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/main.dart';

void main() {
  group('LocalDatabase CRUD and Persistence Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
    });

    tearDown(() async {
      await localDb.close();
    });

    test('Save and retrieve message from local database', () async {
      final msg = ChatMessage(
        id: 'test_001',
        senderId: 'current_user',
        recipientId: 'Twilight',
        text: 'Hello from SQLite test',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await localDb.saveMessage(msg);
      final messages = await localDb.getMessagesForPartner('Twilight');

      expect(messages.length, 1);
      expect(messages.first.id, 'test_001');
      expect(messages.first.text, 'Hello from SQLite test');
      expect(messages.first.status, MessageStatus.sending);
    });

    test('Update message status in local database', () async {
      final msg = ChatMessage(
        id: 'test_002',
        senderId: 'current_user',
        recipientId: 'Twilight',
        text: 'Status update test',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await localDb.saveMessage(msg);
      await localDb.updateMessageStatus('test_002', MessageStatus.delivered);

      final messages = await localDb.getMessagesForPartner('Twilight');
      expect(messages.first.status, MessageStatus.delivered);
    });

    test('Search and delete message from local database', () async {
      final msg1 = ChatMessage(
        id: 'test_003',
        senderId: 'current_user',
        recipientId: 'Twilight',
        text: 'Special secret keyword',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sent,
      );
      final msg2 = ChatMessage(
        id: 'test_004',
        senderId: 'current_user',
        recipientId: 'Twilight',
        text: 'Another normal note',
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
        type: MessageType.text,
        status: MessageStatus.sent,
      );

      await localDb.saveMessage(msg1);
      await localDb.saveMessage(msg2);

      final searchResults = await localDb.searchMessages(
        partnerId: 'Twilight',
        query: 'secret',
      );
      expect(searchResults.length, 1);
      expect(searchResults.first.id, 'test_003');

      final deleted = await localDb.deleteMessage('test_003');
      expect(deleted, isTrue);

      final remaining = await localDb.getMessagesForPartner('Twilight');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'test_004');
    });
  });

  group('ChatRepository Layer Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;
    late ChatRepository chatRepository;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
      chatRepository = LocalChatRepository(database: localDb);
    });

    tearDown(() async {
      await localDb.close();
    });

    test('ChatRepository delegates message sending and retrieval', () async {
      final msg = ChatMessage(
        id: 'repo_001',
        senderId: 'current_user',
        recipientId: 'Twilight',
        text: 'Hello via ChatRepository',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await chatRepository.sendMessage(msg);
      final messages = await chatRepository.getMessages('Twilight');

      expect(messages.length, 1);
      expect(messages.first.text, 'Hello via ChatRepository');

      await chatRepository.updateMessageStatus(
        'repo_001',
        MessageStatus.delivered,
      );
      final updated = await chatRepository.getMessages('Twilight');
      expect(updated.first.status, MessageStatus.delivered);
    });
  });

  group('ChatScreen UI & Interaction Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
    });

    tearDown(() async {
      await localDb.close();
    });

    testWidgets('ChatScreen smoke test and message sending verification',
        (WidgetTester tester) async {
      // Build our app and trigger frame
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify header components
      expect(find.text('Twilight'), findsOneWidget);
      expect(find.text('💕 Send luv'), findsOneWidget);

      // Verify input field exists
      expect(find.text('Type a message...'), findsOneWidget);

      // Verify date grouping
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // Test sending a new message
      const testMessage = 'Hello from automated test!';
      await tester.enterText(find.byType(TextField), testMessage);
      await tester.pump();

      // Tap the send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the new message appears in the chat list
      expect(find.text(testMessage), findsOneWidget);

      // Verify the input field was cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);

      // Test "Send luv" button interaction
      await tester.tap(find.text('💕 Send luv'));
      await tester.pump(); // Start SnackBar animation
      expect(find.text('💕 Love sent!'), findsOneWidget);

      // Let animations and timers finish
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
