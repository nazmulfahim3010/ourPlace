import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/conversation.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/models/user_account.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/screens/auth/auth_gate.dart';
import 'package:chatbox/screens/auth/auth_screen.dart';
import 'package:chatbox/screens/chat_screen.dart';
import 'package:chatbox/screens/home_screen.dart';
import 'package:chatbox/screens/inbox/inbox_screen.dart';
import 'package:chatbox/services/auth_service.dart';
import 'package:chatbox/widgets/conversation_tile.dart';
import 'package:chatbox/main.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Cryptographic Hashing and Username Utilities Tests', () {
    test('generateSalt generates distinct non-empty random salts', () {
      final salt1 = HashUtils.generateSalt();
      final salt2 = HashUtils.generateSalt();

      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPassword produces consistent SHA-256 digests for same salt and password', () {
      const salt = 'fixed_salt_for_test';
      const password = 'mySecretPassword123';

      final hash1 = HashUtils.hashPassword(password, salt);
      final hash2 = HashUtils.hashPassword(password, salt);
      expect(hash1, equals(hash2));

      final differentSaltHash = HashUtils.hashPassword(password, 'other_salt');
      expect(hash1, isNot(equals(differentSaltHash)));
    });

    test('normalizeUsername handles leading @, whitespace, and uppercase', () {
      expect(HashUtils.normalizeUsername('  @Alex  '), '@alex');
      expect(HashUtils.normalizeUsername('NazmulFahim'), '@nazmulfahim');
      expect(HashUtils.normalizeUsername('@Moonlight_99'), '@moonlight_99');
    });

    test('validateUsername enforces 3 to 20 alphanumeric characters or underscores', () {
      expect(HashUtils.validateUsername('al'), isNotNull);
      expect(HashUtils.validateUsername('alex'), isNull);
      expect(HashUtils.validateUsername('alex_99'), isNull);
      expect(HashUtils.validateUsername('alex!'), isNotNull);
      expect(HashUtils.validateUsername('alex with spaces'), isNotNull);
      expect(HashUtils.validateUsername('a' * 21), isNotNull);
    });

    test('UserAccount.create salts and correctly verifies password', () {
      final account = UserAccount.create(
        accountId: 'acc_001',
        username: '@alex',
        plaintextPassword: 'correctPassword',
      );

      expect(account.username, '@alex');
      expect(account.passwordHash, isNot(equals('correctPassword')));
      expect(account.verifyPassword('correctPassword'), isTrue);
      expect(account.verifyPassword('wrongPassword'), isFalse);
    });
  });

  group('LocalDatabase Account & Message Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
    });

    tearDown(() async {
      await localDb.close();
    });

    test('Save and retrieve anonymous account from database', () async {
      final account = UserAccount.create(
        accountId: 'acc_db_1',
        username: '@twilight',
        plaintextPassword: 'password123',
      );

      await localDb.saveAccount(account);

      final retrieved = await localDb.getAccountByUsername('@twilight');
      expect(retrieved, isNotNull);
      expect(retrieved!.accountId, 'acc_db_1');
      expect(retrieved.username, '@twilight');
      expect(retrieved.verifyPassword('password123'), isTrue);

      final isTaken = await localDb.isUsernameTaken('twilight');
      expect(isTaken, isTrue);

      final isAvailable = await localDb.isUsernameTaken('unknown_user');
      expect(isAvailable, isFalse);
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

  group('Conversation Model & Repository Tests', () {
    late ConversationRepository convRepo;

    setUp(() {
      convRepo = LocalConversationRepository();
    });

    test('getConversations loads seed conversations with Love Connection', () async {
      final conversations = await convRepo.getConversations();
      expect(conversations.length, greaterThanOrEqualTo(4));

      final love = await convRepo.getLoveConnectionConversation();
      expect(love, isNotNull);
      expect(love!.isLoveConnection, isTrue);
      expect(love.partner.username, '@twilight');
    });

    test('startOrGetConversation retrieves existing or creates new conversation', () async {
      final newUser = User(
        id: 'user_david_99',
        username: '@david',
        displayName: 'David',
        isCurrentUser: false,
      );

      final conv = await convRepo.startOrGetConversation(partner: newUser);
      expect(conv.partner.username, '@david');

      final all = await convRepo.getConversations();
      expect(all.any((c) => c.partner.username == '@david'), isTrue);
    });

    test('markAsRead resets unread count for conversation', () async {
      final love = await convRepo.getLoveConnectionConversation();
      expect(love, isNotNull);

      await convRepo.markAsRead(love!.id);
      final updated = await convRepo.getLoveConnectionConversation();
      expect(updated!.unreadCount, 0);
    });
  });

  group('AuthService & AuthRepository Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;
    late AuthService authService;
    late AuthRepository authRepository;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
      authService = LocalAuthService(database: localDb);
      authRepository = DefaultAuthRepository(authService: authService);
    });

    tearDown(() async {
      await authRepository.signOut();
      await localDb.close();
    });

    test('Register new anonymous user, duplicate detection, and login flow', () async {
      // 1. Register
      final user = await authRepository.register(
        username: 'alex',
        password: 'password123',
      );

      expect(user.username, '@alex');
      expect(user.isCurrentUser, isTrue);

      final current = await authRepository.getCurrentUser();
      expect(current?.username, '@alex');

      // 2. Duplicate registration attempt should throw AuthException
      expect(
        () => authRepository.register(username: 'Alex', password: 'password456'),
        throwsA(isA<AuthException>()),
      );

      // 3. Sign out
      await authRepository.signOut();
      final afterSignOut = await authRepository.getCurrentUser();
      expect(afterSignOut, isNull);

      // 4. Incorrect password fails
      expect(
        () => authRepository.login(username: 'alex', password: 'wrongPassword'),
        throwsA(isA<AuthException>()),
      );

      // 5. Correct login succeeds
      final loggedIn = await authRepository.login(
        username: 'alex',
        password: 'password123',
      );
      expect(loggedIn.username, '@alex');
      expect(loggedIn.isCurrentUser, isTrue);
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

  group('Inbox & Multi-Conversation UI Tests', () {
    late ConversationRepository convRepo;

    setUp(() {
      convRepo = LocalConversationRepository();
    });

    testWidgets('ConversationTile renders correctly for Love Connection and regular chats',
        (WidgetTester tester) async {
      final loveConv = Conversation(
        id: 'c1',
        partner: User(id: 'p1', username: '@twilight', displayName: 'Twilight'),
        lastMessage: ChatMessage(
          id: 'm1',
          senderId: 'p1',
          recipientId: 'current_user',
          text: 'Love you!',
          timestamp: DateTime.now(),
        ),
        unreadCount: 1,
        isLoveConnection: true,
      );

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationTile(
              conversation: loveConv,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Twilight'), findsOneWidget);
      expect(find.text('Love you!'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // unread count
      expect(find.byIcon(Icons.favorite), findsNWidgets(2)); // avatar badge + row icon

      await tester.tap(find.byType(ConversationTile));
      expect(tapped, isTrue);
    });

    testWidgets('InboxScreen displays header, search bar, Love Connection, and conversations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InboxScreen(
            conversationRepository: convRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and branding
      expect(find.text('ourPlace'), findsOneWidget);
      expect(find.text('Search conversations or @username...'), findsOneWidget);

      // Verify sections
      expect(find.text('❤️ LOVE CONNECTION'), findsOneWidget);
      expect(find.textContaining('CONVERSATIONS'), findsOneWidget);

      // Verify partners are listed
      expect(find.text('Twilight'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.text('Rahim'), findsOneWidget);

      // Test searching/filtering
      await tester.enterText(find.byType(TextField), 'Sarah');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.widgetWithText(ConversationTile, 'Sarah'), findsOneWidget);
      expect(find.widgetWithText(ConversationTile, 'Rahim'), findsNothing);
    });

    testWidgets('Tapping conversation in Inbox opens ChatScreen and back button returns to Inbox',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            conversationRepository: convRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the Twilight conversation
      await tester.tap(find.text('Twilight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ChatScreen is now open
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byTooltip('Back to Inbox'), findsOneWidget);

      // Tap back button in ChatHeader
      await tester.tap(find.byTooltip('Back to Inbox'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Returned to InboxScreen
      expect(find.byType(InboxScreen), findsOneWidget);
    });
  });

  group('AuthScreen & AuthGate UI Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;
    late AuthService authService;
    late AuthRepository authRepository;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
      authService = LocalAuthService(database: localDb, resetSession: true);
      authRepository = DefaultAuthRepository(authService: authService);
    });

    tearDown(() async {
      await authRepository.signOut();
      await localDb.close();
    });

    testWidgets('AuthScreen switches between Sign In and Create Account tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(authRepository: authRepository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'Sign In'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Create Account'), findsOneWidget);
      expect(find.text('ourPlace'), findsOneWidget);

      // Switch to Create Account tab
      await tester.tap(find.widgetWithText(Tab, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Username'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('AuthGate presents HomeScreen when authenticated and AuthScreen when signed out',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(authRepository: authRepository),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially signed in with default local user -> HomeScreen (Inbox) is shown
      expect(find.byType(HomeScreen), findsOneWidget);

      // Sign out programmatically
      await authRepository.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Returns to AuthScreen
      expect(find.byType(AuthScreen), findsOneWidget);

      // Re-register or login
      await authRepository.register(
        username: 'alice',
        password: 'password123',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // HomeScreen is shown again
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('@alice'), findsOneWidget);
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
      // Build our app with direct ChatScreen
      await tester.pumpWidget(
        const MyApp(
          home: ChatScreen(partnerName: 'Twilight'),
        ),
      );
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
