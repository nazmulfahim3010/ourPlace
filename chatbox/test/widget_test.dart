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
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/services/secure_storage_service.dart';
import 'package:chatbox/screens/auth/app_lock_screen.dart';
import 'package:chatbox/screens/auth/passcode_setup_screen.dart';
import 'package:chatbox/screens/profile/profile_screen.dart';
import 'package:chatbox/widgets/conversation_tile.dart';
import 'package:chatbox/widgets/numeric_keypad.dart';
import 'package:chatbox/widgets/passcode_dots.dart';
import 'package:chatbox/core/utils/recovery_key_utils.dart';
import 'package:chatbox/core/utils/crypto_key_utils.dart';
import 'package:chatbox/models/encrypted_payload.dart';
import 'package:chatbox/services/access_throttling_service.dart';
import 'package:chatbox/services/auth_security_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/services/relay_service.dart';
import 'package:chatbox/main.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'dart:async';


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
      final mockLock = MockAppLockService(isAppUnlocked: true);
      await mockLock.setPasscode('1234');
      mockLock.unlockApp();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authRepository: authRepository,
            appLockService: mockLock,
          ),
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

      // Unlock device
      mockLock.unlockApp();
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

  group('AppLockService & SecureStorage Tests', () {
    late InMemorySecureStorageService storage;
    late MockAppLockService lockService;

    setUp(() {
      storage = InMemorySecureStorageService();
      lockService = MockAppLockService(storage: storage);
    });

    test('Setting passcode salts and hashes candidate without storing plaintext', () async {
      const passcode = '1234';
      await lockService.setPasscode(passcode);

      final isConfigured = await lockService.isPasscodeConfigured();
      expect(isConfigured, isTrue);

      final salt = await storage.read('app_lock_passcode_salt');
      final verifier = await storage.read('app_lock_passcode_verifier');

      expect(salt, isNotNull);
      expect(verifier, isNotNull);
      expect(salt, isNot(equals(passcode)));
      expect(verifier, isNot(equals(passcode)));
    });

    test('verifyPasscode correctly unlocks on match and rejects mismatch', () async {
      await lockService.setPasscode('4321');

      expect(lockService.isAppUnlocked, isFalse);

      final wrongResult = await lockService.verifyPasscode('9999');
      expect(wrongResult, isFalse);
      expect(lockService.isAppUnlocked, isFalse);

      final correctResult = await lockService.verifyPasscode('4321');
      expect(correctResult, isTrue);
      expect(lockService.isAppUnlocked, isTrue);
    });

    test('Biometric setting toggle and clearPasscode lifecycle', () async {
      expect(await lockService.isBiometricsEnabled(), isFalse);

      await lockService.setBiometricsEnabled(true);
      expect(await lockService.isBiometricsEnabled(), isTrue);

      await lockService.setPasscode('7777');
      await lockService.clearPasscode();

      expect(await lockService.isPasscodeConfigured(), isFalse);
      expect(await lockService.isBiometricsEnabled(), isFalse);
      expect(lockService.isAppUnlocked, isFalse);
    });
  });

  group('App Lock UI & Screen Widget Tests', () {
    late InMemorySecureStorageService storage;
    late MockAppLockService lockService;

    setUp(() {
      storage = InMemorySecureStorageService();
      lockService = MockAppLockService(storage: storage);
    });

    testWidgets('PasscodeDots renders specified length and filled dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasscodeDots(
              length: 4,
              filledCount: 2,
            ),
          ),
        ),
      );

      expect(find.byType(PasscodeDots), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('NumericKeypad handles digit, backspace, and biometric taps', (WidgetTester tester) async {
      int? tappedDigit;
      var backspaceTapped = false;
      var biometricTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeypad(
              onDigit: (d) => tappedDigit = d,
              onBackspace: () => backspaceTapped = true,
              onBiometric: () => biometricTapped = true,
              showBiometric: true,
            ),
          ),
        ),
      );

      // Tap 5
      await tester.tap(find.text('5'));
      expect(tappedDigit, equals(5));

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(backspaceTapped, isTrue);

      // Tap fingerprint
      await tester.tap(find.byIcon(Icons.fingerprint));
      expect(biometricTapped, isTrue);
    });

    testWidgets('PasscodeSetupScreen creates and confirms passcode, then completes', (WidgetTester tester) async {
      var setupDone = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PasscodeSetupScreen(
            appLockService: lockService,
            onSetupComplete: () => setupDone = true,
          ),
        ),
      );

      expect(find.text('Create App Passcode'), findsOneWidget);

      // Step 1: Enter 1234
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should advance to step 2: Confirm Passcode
      expect(find.text('Confirm Passcode'), findsOneWidget);

      // Step 2: Enter matching 1234
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify biometric sheet appears or setupDone triggers
      if (find.text('Enable Biometric Unlock?').evaluate().isNotEmpty) {
        await tester.tap(find.text('Enable Biometrics'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(setupDone, isTrue);
      expect(await lockService.isPasscodeConfigured(), isTrue);
    });

    testWidgets('AppLockScreen displays lock prompt and unlocks on correct passcode', (WidgetTester tester) async {
      await lockService.setPasscode('8888');
      var unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockScreen(
            appLockService: lockService,
            autoPromptBiometrics: false,
            onUnlocked: () => unlocked = true,
          ),
        ),
      );

      expect(find.text('ourPlace'), findsOneWidget);
      expect(find.text('Enter your 4-digit passcode to unlock'), findsOneWidget);

      // Enter incorrect code 1234
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Incorrect passcode'), findsOneWidget);
      expect(unlocked, isFalse);

      // Enter correct code 8888
      await tester.tap(find.text('8'));
      await tester.tap(find.text('8'));
      await tester.tap(find.text('8'));
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(unlocked, isTrue);
    });

    testWidgets('AuthGate routes to PasscodeSetupScreen when passcode not configured', (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final localDb = LocalDatabase(database: db);
      final authService = LocalAuthService(database: localDb, resetSession: true);
      final authRepo = DefaultAuthRepository(authService: authService);

      final freshLockService = MockAppLockService(storage: InMemorySecureStorageService());

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authRepository: authRepo,
            appLockService: freshLockService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Create App Passcode'), findsOneWidget);
      await localDb.close();
    });

    testWidgets('ProfileScreen displays Security & App Lock card and allows Lock App Now', (WidgetTester tester) async {
      await lockService.setPasscode('5555');
      lockService.unlockApp();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            currentUser: User(id: 'alex', username: '@alex'),
            appLockService: lockService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Security & App Lock'), findsOneWidget);
      expect(find.text('Active • Protected locally'), findsOneWidget);

      // Tap "Lock App Now"
      await tester.tap(find.text('Lock App Now'));
      await tester.pump();

      expect(lockService.isAppUnlocked, isFalse);
    });
  });

  group('Phase 9: RecoveryKeyUtils Mnemonic Tests', () {
    test('generateMnemonic generates valid 12-word phrase from BIP-39 dictionary', () {
      final mnemonic = RecoveryKeyUtils.generateMnemonic();
      final words = mnemonic.split(' ');
      expect(words.length, 12);
      for (final word in words) {
        expect(RecoveryKeyUtils.bip39EnglishWordSet.contains(word), isTrue);
      }
    });

    test('validateMnemonic validates count and dictionary existence', () {
      final validMnemonic = RecoveryKeyUtils.generateMnemonic();
      expect(RecoveryKeyUtils.validateMnemonic(validMnemonic), isNull);

      expect(RecoveryKeyUtils.validateMnemonic(''), isNotNull);
      expect(RecoveryKeyUtils.validateMnemonic('word1 word2 word3'), isNotNull);
      expect(RecoveryKeyUtils.validateMnemonic('notabipword ' * 12), isNotNull);
    });

    test('hashRecoveryKey and verifyRecoveryKey correctly verifies candidate phrase', () {
      final phrase = RecoveryKeyUtils.generateMnemonic();
      final salt = HashUtils.generateSalt();
      final hash = RecoveryKeyUtils.hashRecoveryKey(phrase, salt);

      expect(
        RecoveryKeyUtils.verifyRecoveryKey(
          candidatePhrase: phrase,
          storedHash: hash,
          salt: salt,
        ),
        isTrue,
      );

      expect(
        RecoveryKeyUtils.verifyRecoveryKey(
          candidatePhrase: RecoveryKeyUtils.generateMnemonic(),
          storedHash: hash,
          salt: salt,
        ),
        isFalse,
      );
    });
  });

  group('Phase 9: AccessThrottlingService & Rate Limiting Tests', () {
    late AccessThrottlingService throttling;

    setUp(() {
      throttling = AccessThrottlingService();
      throttling.clearAll();
    });

    test('cooldown duration escalates based on consecutive failed attempts', () {
      expect(throttling.calculateCooldown(0), Duration.zero);
      expect(throttling.calculateCooldown(2), Duration.zero);
      expect(throttling.calculateCooldown(3), const Duration(seconds: 10));
      expect(throttling.calculateCooldown(5), const Duration(seconds: 30));
      expect(throttling.calculateCooldown(8), const Duration(minutes: 2));
      expect(throttling.calculateCooldown(10), const Duration(minutes: 5));
    });

    test('recordFailedLogin sets lockout and canAttemptLogin enforces cooldown', () {
      const username = '@bad_actor';
      expect(throttling.canAttemptLogin(username), isTrue);

      throttling.recordFailedLogin(username);
      throttling.recordFailedLogin(username);
      expect(throttling.canAttemptLogin(username), isTrue);

      // 3rd attempt triggers 10s cooldown
      throttling.recordFailedLogin(username);
      expect(throttling.canAttemptLogin(username), isFalse);
      expect(throttling.getRemainingCooldown(username).inSeconds, greaterThan(0));

      // Successful login resets throttling
      throttling.recordSuccessfulLogin(username);
      expect(throttling.canAttemptLogin(username), isTrue);
      expect(throttling.getFailedAttempts(username), 0);
    });
  });

  group('Phase 9: AuthSecurityService Challenge-Response Protocol Tests', () {
    test('issueChallenge generates unique nonces with valid timestamp', () {
      final challenge1 = AuthSecurityService.issueChallenge(username: '@alex');
      final challenge2 = AuthSecurityService.issueChallenge(username: '@alex');

      expect(challenge1.challengeId, isNotEmpty);
      expect(challenge1.serverNonce, isNot(equals(challenge2.serverNonce)));
      expect(challenge1.isExpired, isFalse);
    });

    test('computeClientProof and verifyClientProof perform zero-knowledge verification', () {
      const passwordHash = 'salted_hash_verifier_123';
      const username = '@alex';
      final challenge = AuthSecurityService.issueChallenge(username: username);
      final clientNonce = AuthSecurityService.generateNonce();

      final proof = AuthSecurityService.computeClientProof(
        passwordHash: passwordHash,
        serverNonce: challenge.serverNonce,
        clientNonce: clientNonce,
        username: username,
      );

      expect(
        AuthSecurityService.verifyClientProof(
          clientProof: proof,
          expectedPasswordHash: passwordHash,
          serverNonce: challenge.serverNonce,
          clientNonce: clientNonce,
          username: username,
        ),
        isTrue,
      );

      expect(
        AuthSecurityService.verifyClientProof(
          clientProof: proof,
          expectedPasswordHash: 'wrong_password_hash',
          serverNonce: challenge.serverNonce,
          clientNonce: clientNonce,
          username: username,
        ),
        isFalse,
      );
    });

    test('mutual server proof proves server identity back to client', () {
      const passwordHash = 'salted_hash_verifier_123';
      const serverNonce = 'server_nonce_abc';
      const clientProof = 'client_proof_xyz';

      final serverProof = AuthSecurityService.computeServerProof(
        passwordHash: passwordHash,
        clientProof: clientProof,
        serverNonce: serverNonce,
      );

      expect(
        AuthSecurityService.verifyServerProof(
          serverProof: serverProof,
          passwordHash: passwordHash,
          clientProof: clientProof,
          serverNonce: serverNonce,
        ),
        isTrue,
      );
    });
  });

  group('Phase 9: LocalDatabase Schema v3 & SecurityLogs Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;

    setUp(() {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
    });

    tearDown(() async {
      await localDb.close();
    });

    test('UserAccount saves and verifies recovery key hash and salt', () async {
      final phrase = RecoveryKeyUtils.generateMnemonic();
      final recoverySalt = HashUtils.generateSalt();
      final recoveryHash = RecoveryKeyUtils.hashRecoveryKey(phrase, recoverySalt);

      final account = UserAccount.create(
        accountId: 'acc_test_rec',
        username: '@recovery_user',
        plaintextPassword: 'initialPassword123',
        recoveryKeyHash: recoveryHash,
        recoveryKeySalt: recoverySalt,
      );

      await localDb.saveAccount(account);
      final retrieved = await localDb.getAccountByUsername('@recovery_user');

      expect(retrieved, isNotNull);
      expect(retrieved!.recoveryKeyHash, recoveryHash);
      expect(retrieved.verifyRecoveryKey(phrase), isTrue);
      expect(retrieved.verifyRecoveryKey(RecoveryKeyUtils.generateMnemonic()), isFalse);
    });

    test('resetPasswordWithRecoveryKey resets password with valid phrase', () async {
      final phrase = RecoveryKeyUtils.generateMnemonic();
      final recoverySalt = HashUtils.generateSalt();
      final recoveryHash = RecoveryKeyUtils.hashRecoveryKey(phrase, recoverySalt);

      final account = UserAccount.create(
        accountId: 'acc_test_reset',
        username: '@reset_user',
        plaintextPassword: 'oldPassword123',
        recoveryKeyHash: recoveryHash,
        recoveryKeySalt: recoverySalt,
      );

      await localDb.saveAccount(account);

      // Attempt reset with invalid phrase
      final badReset = await localDb.resetPasswordWithRecoveryKey(
        username: '@reset_user',
        recoveryPhrase: RecoveryKeyUtils.generateMnemonic(),
        newPlaintextPassword: 'brandNewPassword456',
      );
      expect(badReset, isFalse);

      // Attempt reset with valid phrase
      final goodReset = await localDb.resetPasswordWithRecoveryKey(
        username: '@reset_user',
        recoveryPhrase: phrase,
        newPlaintextPassword: 'brandNewPassword456',
      );
      expect(goodReset, isTrue);

      final updated = await localDb.getAccountByUsername('@reset_user');
      expect(updated!.verifyPassword('brandNewPassword456'), isTrue);
      expect(updated.verifyPassword('oldPassword123'), isFalse);
    });

    test('logSecurityEvent and getSecurityLogs records and retrieves local events', () async {
      await localDb.logSecurityEvent('login_attempt', 'Attempt 1 failed', severity: 'warning');
      await Future.delayed(const Duration(milliseconds: 20));
      await localDb.logSecurityEvent('lock_app', 'App locked', severity: 'info');

      final logs = await localDb.getSecurityLogs();
      expect(logs.length, 2);
      expect(logs.first.eventType, 'lock_app'); // newest first
      expect(logs.first.formattedTime, isNotEmpty);

      await localDb.clearSecurityLogs();
      final clearedLogs = await localDb.getSecurityLogs();
      expect(clearedLogs, isEmpty);
    });

  });

  group('Phase 9: AppLock Throttling & Lockout Tests', () {
    test('DefaultAppLockService triggers lockout after 5 consecutive failed attempts', () async {
      final storage = InMemorySecureStorageService();
      final lockService = DefaultAppLockService(storage: storage);
      await lockService.setPasscode('1234');
      lockService.lockApp();

      expect(lockService.isLockedOut(), isFalse);

      for (int i = 0; i < 4; i++) {
        final res = await lockService.verifyPasscode('0000');
        expect(res, isFalse);
        expect(lockService.isLockedOut(), isFalse);
      }

      // 5th failed attempt triggers 60s lockout
      final res5 = await lockService.verifyPasscode('0000');
      expect(res5, isFalse);
      expect(lockService.isLockedOut(), isTrue);
      expect(lockService.remainingLockoutSeconds(), greaterThan(0));

      // Attempt during lockout is immediately rejected
      final blocked = await lockService.verifyPasscode('1234');
      expect(blocked, isFalse);
      expect(lockService.isAppUnlocked, isFalse);

      // Reset allows unlock
      lockService.resetFailedAttempts();
      expect(lockService.isLockedOut(), isFalse);
      final unlocked = await lockService.verifyPasscode('1234');
      expect(unlocked, isTrue);
      expect(lockService.isAppUnlocked, isTrue);
    });
  });

  group('Phase 9: UI Widget Tests', () {
    testWidgets('AppLockScreen displays lockout warning banner when locked out', (tester) async {
      final storage = InMemorySecureStorageService();
      final lockService = MockAppLockService(storage: storage);
      await lockService.setPasscode('1234');
      lockService.lockApp();

      // Trigger lockout
      for (int i = 0; i < 5; i++) {
        await lockService.verifyPasscode('0000');
      }
      expect(lockService.isLockedOut(), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockScreen(
            appLockService: lockService,
            autoPromptBiometrics: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Lockout Active:'), findsOneWidget);
    });

    testWidgets('AuthScreen displays Reset with Recovery Key button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Forgot Password? Reset with Recovery Key'), findsOneWidget);
    });

    testWidgets('ProfileScreen displays Account Recovery Key and Security Audit Log options', (tester) async {
      final storage = InMemorySecureStorageService();
      final lockService = MockAppLockService(storage: storage, isAppUnlocked: true);
      await lockService.setPasscode('1234');

      final user = User(
        id: 'user_1',
        username: '@alex',
        displayName: 'Alex',
        isCurrentUser: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            currentUser: user,
            appLockService: lockService,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Account Recovery Key'), findsOneWidget);
      expect(find.text('Security Audit Log'), findsOneWidget);
    });
  });

  group('Phase 10: EncryptedPayload Domain Model Tests', () {
    test('serialize and deserialize preserves all envelope attributes', () {
      final now = DateTime.now();
      final payload = EncryptedPayload(
        version: 1,
        senderPublicKey: 'c2VuZGVyX3B1YmxpY19rZXlfMTIz',
        nonce: 'bm9uY2VfMTIzNDU2Nzg5MA==',
        ciphertext: 'Y2lwaGVydGV4dF9kYXRhX2FiY2RlZg==',
        mac: 'bWFjX3RhZ18xMjM0NTY3OA==',
        createdAt: now,
      );

      final serialized = payload.serialize();
      final deserialized = EncryptedPayload.deserialize(serialized);

      expect(deserialized.version, equals(1));
      expect(deserialized.senderPublicKey, equals(payload.senderPublicKey));
      expect(deserialized.nonce, equals(payload.nonce));
      expect(deserialized.ciphertext, equals(payload.ciphertext));
      expect(deserialized.mac, equals(payload.mac));
      expect(
        deserialized.createdAt.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });

    test('fromJson defaults version to 1 and parses successfully', () {
      final json = {
        'sender_pub': 'pub_key',
        'nonce': 'nonce_val',
        'ct': 'ct_val',
        'mac': 'mac_val',
      };

      final payload = EncryptedPayload.fromJson(json);
      expect(payload.version, equals(1));
      expect(payload.senderPublicKey, equals('pub_key'));
      expect(payload.createdAt, isNotNull);
    });
  });

  group('Phase 10: CryptoKeyUtils Cryptographic Primitives Tests', () {
    test('generateX25519KeyPair creates valid distinct keypairs', () async {
      final pair1 = await CryptoKeyUtils.generateX25519KeyPair();
      final pair2 = await CryptoKeyUtils.generateX25519KeyPair();

      final pub1 = await CryptoKeyUtils.encodePublicKey(pair1);
      final pub2 = await CryptoKeyUtils.encodePublicKey(pair2);

      expect(pub1, isNotEmpty);
      expect(pub2, isNotEmpty);
      expect(pub1, isNot(equals(pub2)));
    });

    test('encodePublicKey and decodePublicKey round-trip preserves key', () async {
      final pair = await CryptoKeyUtils.generateX25519KeyPair();
      final pubBase64 = await CryptoKeyUtils.encodePublicKey(pair);

      final decoded = CryptoKeyUtils.decodePublicKey(pubBase64);
      final reEncoded = CryptoKeyUtils.encodePublicKeyBytes(decoded.bytes);

      expect(reEncoded, equals(pubBase64));
    });

    test('encodePrivateKey and reconstructKeyPair restores keypair', () async {
      final originalPair = await CryptoKeyUtils.generateX25519KeyPair();
      final privBase64 = await CryptoKeyUtils.encodePrivateKey(originalPair);
      final pubBase64 = await CryptoKeyUtils.encodePublicKey(originalPair);

      final restored = CryptoKeyUtils.reconstructKeyPair(
        base64PrivateKey: privBase64,
        base64PublicKey: pubBase64,
      );

      final restoredPubBase64 = await CryptoKeyUtils.encodePublicKey(restored);
      final restoredPrivBase64 = await CryptoKeyUtils.encodePrivateKey(restored);

      expect(restoredPubBase64, equals(pubBase64));
      expect(restoredPrivBase64, equals(privBase64));
    });

    test('ECDH Shared Secret Agreement: Alice and Bob compute identical shared secret', () async {
      final alicePair = await CryptoKeyUtils.generateX25519KeyPair();
      final bobPair = await CryptoKeyUtils.generateX25519KeyPair();

      final alicePub = await alicePair.extractPublicKey();
      final bobPub = await bobPair.extractPublicKey();

      final secretAlice = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: alicePair,
        remotePublicKey: bobPub,
      );

      final secretBob = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: bobPair,
        remotePublicKey: alicePub,
      );

      final aliceSecretBytes = await secretAlice.extractBytes();
      final bobSecretBytes = await secretBob.extractBytes();

      expect(aliceSecretBytes, equals(bobSecretBytes));
    });

    test('deriveMessageKey derives identical 256-bit symmetric key from shared secret', () async {
      final alicePair = await CryptoKeyUtils.generateX25519KeyPair();
      final bobPair = await CryptoKeyUtils.generateX25519KeyPair();

      final secretAlice = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: alicePair,
        remotePublicKey: await bobPair.extractPublicKey(),
      );
      final secretBob = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: bobPair,
        remotePublicKey: await alicePair.extractPublicKey(),
      );

      final keyAlice = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secretAlice);
      final keyBob = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secretBob);

      final bytesAlice = await keyAlice.extractBytes();
      final bytesBob = await keyBob.extractBytes();

      expect(bytesAlice.length, equals(32)); // 256 bits
      expect(bytesAlice, equals(bytesBob));
    });

    test('encryptAesGcm and decryptAesGcm round-trips plaintext correctly', () async {
      final pair = await CryptoKeyUtils.generateX25519KeyPair();
      final secret = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: pair,
        remotePublicKey: await pair.extractPublicKey(),
      );
      final key = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secret);

      const plaintext = 'Secret love letter for ourPlace 💌';
      final secretBox = await CryptoKeyUtils.encryptAesGcm(
        plaintext: plaintext,
        secretKey: key,
      );

      expect(secretBox.cipherText, isNotEmpty);
      expect(secretBox.nonce.length, equals(12));
      expect(secretBox.mac.bytes.length, equals(16));

      final decrypted = await CryptoKeyUtils.decryptAesGcm(
        ciphertext: secretBox.cipherText,
        nonce: secretBox.nonce,
        mac: secretBox.mac.bytes,
        secretKey: key,
      );

      expect(decrypted, equals(plaintext));
    });

    test('Tamper Resistance: Decryption throws SecurityException when ciphertext is modified', () async {
      final pair = await CryptoKeyUtils.generateX25519KeyPair();
      final secret = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: pair,
        remotePublicKey: await pair.extractPublicKey(),
      );
      final key = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secret);

      final secretBox = await CryptoKeyUtils.encryptAesGcm(
        plaintext: 'Authentic message',
        secretKey: key,
      );

      // Corrupt one byte of ciphertext
      final tamperedCiphertext = List<int>.from(secretBox.cipherText);
      tamperedCiphertext[0] ^= 0xFF;

      expect(
        () async => await CryptoKeyUtils.decryptAesGcm(
          ciphertext: tamperedCiphertext,
          nonce: secretBox.nonce,
          mac: secretBox.mac.bytes,
          secretKey: key,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Tamper Resistance: Decryption throws SecurityException when MAC tag is corrupted', () async {
      final pair = await CryptoKeyUtils.generateX25519KeyPair();
      final secret = await CryptoKeyUtils.computeSharedSecret(
        localKeyPair: pair,
        remotePublicKey: await pair.extractPublicKey(),
      );
      final key = await CryptoKeyUtils.deriveMessageKey(sharedSecret: secret);

      final secretBox = await CryptoKeyUtils.encryptAesGcm(
        plaintext: 'Protected message',
        secretKey: key,
      );

      final tamperedMac = List<int>.from(secretBox.mac.bytes);
      tamperedMac[tamperedMac.length - 1] ^= 0x01;

      expect(
        () async => await CryptoKeyUtils.decryptAesGcm(
          ciphertext: secretBox.cipherText,
          nonce: secretBox.nonce,
          mac: tamperedMac,
          secretKey: key,
        ),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('Phase 10: StandardE2EEEncryptionService Tests', () {
    late InMemorySecureStorageService storageAlice;
    late InMemorySecureStorageService storageBob;
    late InMemorySecureStorageService storageCharlie;
    late StandardE2EEEncryptionService aliceService;
    late StandardE2EEEncryptionService bobService;
    late StandardE2EEEncryptionService charlieService;

    setUp(() {
      storageAlice = InMemorySecureStorageService();
      storageBob = InMemorySecureStorageService();
      storageCharlie = InMemorySecureStorageService();

      aliceService = StandardE2EEEncryptionService(secureStorage: storageAlice);
      bobService = StandardE2EEEncryptionService(secureStorage: storageBob);
      charlieService = StandardE2EEEncryptionService(secureStorage: storageCharlie);
    });

    test('initializeUserKeys stores keypair in hardware secure storage', () async {
      await aliceService.initializeUserKeys('alice_user');
      expect(await aliceService.hasKeysConfigured(), isTrue);

      final pubKey = await aliceService.getPublicIdentityKey();
      expect(pubKey, isNotEmpty);

      final storedPriv = await storageAlice.read('e2ee_priv_key_alice_user');
      final storedPub = await storageAlice.read('e2ee_pub_key_alice_user');

      expect(storedPriv, isNotNull);
      expect(storedPub, equals(pubKey));
    });

    test('Re-initialization restores existing keypair without regeneration', () async {
      await aliceService.initializeUserKeys('persistent_user');
      final firstPubKey = await aliceService.getPublicIdentityKey();

      // Second init
      await aliceService.initializeUserKeys('persistent_user');
      final secondPubKey = await aliceService.getPublicIdentityKey();

      expect(secondPubKey, equals(firstPubKey));
    });

    test('Alice and Bob E2EE Message Flow: Encrypt and Decrypt successfully', () async {
      await aliceService.initializeUserKeys('alice');
      final alicePub = await aliceService.getPublicIdentityKey();

      await bobService.initializeUserKeys('bob');
      final bobPub = await bobService.getPublicIdentityKey();

      const cleartext = "Hey Bob! This message is end-to-end encrypted 🔐❤️";

      // Alice encrypts for Bob
      final envelope = await aliceService.encryptPayload(cleartext, bobPub);
      expect(envelope, isNot(contains(cleartext)));

      // Bob decrypts Alice's envelope
      final decrypted = await bobService.decryptPayload(envelope, alicePub);
      expect(decrypted, equals(cleartext));
    });

    test('Unauthorized third party Charlie fails to decrypt Alice-Bob message', () async {
      await aliceService.initializeUserKeys('alice');
      final alicePub = await aliceService.getPublicIdentityKey();

      await bobService.initializeUserKeys('bob');
      final bobPub = await bobService.getPublicIdentityKey();

      await charlieService.initializeUserKeys('charlie');

      final envelope = await aliceService.encryptPayload('Secret plans', bobPub);

      // Charlie attempts to decrypt with Alice's public key
      expect(
        () async => await charlieService.decryptPayload(envelope, alicePub),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Malformed ciphertext envelope throws SecurityException', () async {
      await aliceService.initializeUserKeys('alice');
      expect(
        () async => await aliceService.decryptPayload('invalid_json_string', 'some_pub_key'),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('Phase 10: LocalChatRepository E2EE Integration Tests', () {
    late AppDatabase inMemoryDb;
    late LocalDatabase localDb;
    late InMemorySecureStorageService storage;
    late StandardE2EEEncryptionService encryptionService;
    late MockChatTransportService mockTransport;
    late LocalChatRepository chatRepository;

    setUp(() async {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: inMemoryDb);
      storage = InMemorySecureStorageService();
      encryptionService = StandardE2EEEncryptionService(secureStorage: storage);
      mockTransport = MockChatTransportService();

      chatRepository = LocalChatRepository(
        database: localDb,
        chatService: mockTransport,
        encryptionService: encryptionService,
      );

      // Initialize local user keys
      await encryptionService.initializeUserKeys('current_user');
    });

    tearDown(() async {
      await localDb.close();
    });

    test('sendMessage saves cleartext locally and sends ciphertext via transport', () async {
      // Setup partner with public key in database
      final bobKeypair = await CryptoKeyUtils.generateX25519KeyPair();
      final bobPubBase64 = await CryptoKeyUtils.encodePublicKey(bobKeypair);

      final bobAccount = UserAccount.create(
        accountId: 'acc_bob',
        username: '@bob',
        plaintextPassword: 'password123',
        publicIdentityKey: bobPubBase64,
      );
      await localDb.saveAccount(bobAccount);

      final message = ChatMessage(
        id: 'msg_e2ee_01',
        senderId: 'current_user',
        recipientId: '@bob',
        text: 'Top secret rendezvous at 9 PM',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await chatRepository.sendMessage(message);

      // 1. Local SQLite holds cleartext (local-first ownership)
      final storedMessages = await localDb.getMessagesForPartner('@bob');
      expect(storedMessages.length, equals(1));
      expect(storedMessages.first.text, equals('Top secret rendezvous at 9 PM'));

      // 2. Transport received encrypted ciphertext
      expect(mockTransport.lastDispatchedMessage, isNotNull);
      expect(mockTransport.lastDispatchedMessage!.text, isNot(equals('Top secret rendezvous at 9 PM')));
      expect(mockTransport.lastDispatchedMessage!.text, contains('"ct":'));
    });

    test('processIncomingMessage decrypts transport payload and persists cleartext', () async {
      // Setup Alice partner
      final aliceStorage = InMemorySecureStorageService();
      final aliceEncService = StandardE2EEEncryptionService(secureStorage: aliceStorage);
      await aliceEncService.initializeUserKeys('alice');
      final alicePub = await aliceEncService.getPublicIdentityKey();

      final aliceAccount = UserAccount.create(
        accountId: 'acc_alice',
        username: '@alice',
        plaintextPassword: 'password123',
        publicIdentityKey: alicePub,
      );
      await localDb.saveAccount(aliceAccount);

      final currentUserPub = await encryptionService.getPublicIdentityKey();
      const originalText = "Hello from Alice through E2EE!";
      final ciphertextEnvelope = await aliceEncService.encryptPayload(originalText, currentUserPub);

      final incomingMessage = ChatMessage(
        id: 'msg_incoming_01',
        senderId: '@alice',
        recipientId: 'current_user',
        text: ciphertextEnvelope,
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.delivered,
      );

      final processed = await chatRepository.processIncomingMessage(incomingMessage);

      expect(processed.text, equals(originalText));

      // Check stored in local database as cleartext
      final stored = await localDb.getMessagesForPartner('@alice');
      expect(stored.length, equals(1));
      expect(stored.first.text, equals(originalText));
    });
  });

  group('Phase 11: EphemeralRelayEnvelope Domain Model Tests', () {
    test('create establishes standard 48-hour TTL and valid attributes', () {
      final now = DateTime.now().toUtc();
      final envelope = EphemeralRelayEnvelope.create(
        id: 'env_001',
        senderId: '@alex',
        recipientId: '@twilight',
        ciphertextPayload: '{"ct":"testCiphertext"}',
        timestamp: now,
      );

      expect(envelope.id, equals('env_001'));
      expect(envelope.senderId, equals('@alex'));
      expect(envelope.recipientId, equals('@twilight'));
      expect(envelope.ciphertextPayload, equals('{"ct":"testCiphertext"}'));
      expect(envelope.timestamp, equals(now));
      expect(envelope.expiresAt.difference(now).inHours, equals(48));
      expect(envelope.isExpired(now), isFalse);
    });

    test('isExpired correctly detects active vs expired envelopes', () {
      final now = DateTime.now().toUtc();
      final past = now.subtract(const Duration(hours: 1));
      final expiredEnvelope = EphemeralRelayEnvelope(
        id: 'env_exp',
        senderId: '@alex',
        recipientId: '@twilight',
        ciphertextPayload: 'expired_payload',
        timestamp: now.subtract(const Duration(days: 3)),
        expiresAt: past,
      );

      expect(expiredEnvelope.isExpired(now), isTrue);
    });

    test('serialize and deserialize preserves all envelope properties', () {
      final envelope = EphemeralRelayEnvelope.create(
        id: 'env_ser_01',
        senderId: '@alex',
        recipientId: '@twilight',
        ciphertextPayload: '{"ct":"xyz123","mac":"abc"}',
      );

      final serialized = envelope.serialize();
      final restored = EphemeralRelayEnvelope.deserialize(serialized);

      expect(restored.id, equals(envelope.id));
      expect(restored.senderId, equals(envelope.senderId));
      expect(restored.recipientId, equals(envelope.recipientId));
      expect(restored.ciphertextPayload, equals(envelope.ciphertextPayload));
      expect(restored.timestamp.toIso8601String(),
          equals(envelope.timestamp.toIso8601String()));
      expect(restored.expiresAt.toIso8601String(),
          equals(envelope.expiresAt.toIso8601String()));
    });
  });

  group('Phase 11: InMemoryFirebaseRelayService Ephemeral Queue Tests', () {
    late InMemoryFirebaseRelayService relay;

    setUp(() {
      relay = InMemoryFirebaseRelayService.isolated();
    });

    tearDown(() {
      relay.dispose();
    });

    test('enqueueMessage isolates queues between different recipients', () async {
      final envBob = EphemeralRelayEnvelope.create(
        id: 'msg_bob_01',
        senderId: '@alex',
        recipientId: '@bob',
        ciphertextPayload: 'ct_for_bob',
      );

      final envCharlie = EphemeralRelayEnvelope.create(
        id: 'msg_charlie_01',
        senderId: '@alex',
        recipientId: '@charlie',
        ciphertextPayload: 'ct_for_charlie',
      );

      await relay.enqueueMessage(envBob);
      await relay.enqueueMessage(envCharlie);

      final bobQueue = await relay.fetchPendingMessages('@bob');
      final charlieQueue = await relay.fetchPendingMessages('@charlie');

      expect(bobQueue.length, equals(1));
      expect(bobQueue.first.id, equals('msg_bob_01'));

      expect(charlieQueue.length, equals(1));
      expect(charlieQueue.first.id, equals('msg_charlie_01'));
    });

    test('fetchPendingMessages prunes expired envelopes on read', () async {
      final now = DateTime.now().toUtc();
      final expired = EphemeralRelayEnvelope(
        id: 'exp_01',
        senderId: '@alex',
        recipientId: '@bob',
        ciphertextPayload: 'old_ct',
        timestamp: now.subtract(const Duration(days: 4)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
      );

      final valid = EphemeralRelayEnvelope.create(
        id: 'val_01',
        senderId: '@alex',
        recipientId: '@bob',
        ciphertextPayload: 'fresh_ct',
      );

      await relay.enqueueMessage(expired);
      await relay.enqueueMessage(valid);

      final pending = await relay.fetchPendingMessages('@bob');
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('val_01'));
    });

    test('watchPendingMessages emits pending messages reactively', () async {
      final stream = relay.watchPendingMessages('@bob');
      final expectation = expectLater(
        stream,
        emitsThrough(predicate<List<EphemeralRelayEnvelope>>(
            (list) => list.any((item) => item.id == 'stream_msg_01'))),
      );

      await relay.enqueueMessage(EphemeralRelayEnvelope.create(
        id: 'stream_msg_01',
        senderId: '@alex',
        recipientId: '@bob',
        ciphertextPayload: 'stream_payload',
      ));

      await expectation;
    });

    test('purgeExpiredMessages prunes all expired messages across all queues', () async {
      final now = DateTime.now().toUtc();
      final expiredBob = EphemeralRelayEnvelope(
        id: 'exp_bob',
        senderId: '@alex',
        recipientId: '@bob',
        ciphertextPayload: 'ct',
        timestamp: now,
        expiresAt: now.add(const Duration(milliseconds: 10)),
      );

      final expiredCharlie = EphemeralRelayEnvelope(
        id: 'exp_charlie',
        senderId: '@alex',
        recipientId: '@charlie',
        ciphertextPayload: 'ct',
        timestamp: now,
        expiresAt: now.add(const Duration(milliseconds: 10)),
      );

      await relay.enqueueMessage(expiredBob);
      await relay.enqueueMessage(expiredCharlie);

      // Allow message TTL to elapse
      await Future.delayed(const Duration(milliseconds: 25));

      final purged = await relay.purgeExpiredMessages();
      expect(purged, equals(2));

      expect(await relay.getPendingQueueCount('@bob'), equals(0));
      expect(await relay.getPendingQueueCount('@charlie'), equals(0));
    });
  });

  group('Phase 11: Delivery ACK & Purge Protocol Tests', () {
    late InMemoryFirebaseRelayService relay;

    setUp(() {
      relay = InMemoryFirebaseRelayService.isolated();
    });

    tearDown(() {
      relay.dispose();
    });

    test('acknowledgeAndPurge immediately and permanently deletes ciphertext from relay queue', () async {
      final envelope = EphemeralRelayEnvelope.create(
        id: 'ack_test_01',
        senderId: '@alex',
        recipientId: '@twilight',
        ciphertextPayload: 'secret_payload',
      );

      await relay.enqueueMessage(envelope);
      expect(await relay.getPendingQueueCount('@twilight'), equals(1));

      // Recipient issues delivery ACK
      final acknowledged = await relay.acknowledgeAndPurge(
        'ack_test_01',
        recipientId: '@twilight',
      );

      expect(acknowledged, isTrue);
      // Ciphertext must be completely erased from server queue
      expect(await relay.getPendingQueueCount('@twilight'), equals(0));
      final pending = await relay.fetchPendingMessages('@twilight');
      expect(pending, isEmpty);
    });

    test('acknowledgeAndPurge returns false for unknown messageId', () async {
      final result = await relay.acknowledgeAndPurge(
        'unknown_id',
        recipientId: '@twilight',
      );
      expect(result, isFalse);
    });
  });

  group('Phase 11: End-to-End Ephemeral Relay Integration (Alice -> Relay -> Bob)', () {
    late AppDatabase aliceDb;
    late LocalDatabase aliceLocalDb;
    late AppDatabase bobDb;
    late LocalDatabase bobLocalDb;
    late InMemoryFirebaseRelayService sharedRelay;
    late StandardE2EEEncryptionService aliceEnc;
    late StandardE2EEEncryptionService bobEnc;
    late LocalChatRepository aliceRepo;
    late LocalChatRepository bobRepo;

    setUp(() async {
      aliceDb = AppDatabase(NativeDatabase.memory());
      aliceLocalDb = LocalDatabase(database: aliceDb);

      bobDb = AppDatabase(NativeDatabase.memory());
      bobLocalDb = LocalDatabase(database: bobDb);

      sharedRelay = InMemoryFirebaseRelayService.isolated();

      final aliceStorage = InMemorySecureStorageService();
      aliceEnc = StandardE2EEEncryptionService(secureStorage: aliceStorage);
      await aliceEnc.initializeUserKeys('alice');
      final alicePub = await aliceEnc.getPublicIdentityKey();

      final bobStorage = InMemorySecureStorageService();
      bobEnc = StandardE2EEEncryptionService(secureStorage: bobStorage);
      await bobEnc.initializeUserKeys('bob');
      final bobPub = await bobEnc.getPublicIdentityKey();

      // Alice registers Bob's public key locally
      await aliceLocalDb.saveAccount(UserAccount.create(
        accountId: 'acc_bob',
        username: '@bob',
        plaintextPassword: 'pw',
        publicIdentityKey: bobPub,
      ));

      // Bob registers Alice's public key locally
      await bobLocalDb.saveAccount(UserAccount.create(
        accountId: 'acc_alice',
        username: '@alice',
        plaintextPassword: 'pw',
        publicIdentityKey: alicePub,
      ));

      final aliceChatService = ChatService(relayService: sharedRelay);
      final bobChatService = ChatService(relayService: sharedRelay);

      aliceRepo = LocalChatRepository(
        database: aliceLocalDb,
        chatService: aliceChatService,
        encryptionService: aliceEnc,
      );

      bobRepo = LocalChatRepository(
        database: bobLocalDb,
        chatService: bobChatService,
        encryptionService: bobEnc,
      );
    });

    tearDown(() async {
      await aliceLocalDb.close();
      await bobLocalDb.close();
      sharedRelay.dispose();
    });

    test('Full E2EE and Ephemeral Relay Flow with Delivery ACK Purge', () async {
      const cleartextMessage = 'Meet at our place at 8 PM sharp!';

      final message = ChatMessage(
        id: 'msg_flow_101',
        senderId: '@alice',
        recipientId: '@bob',
        text: cleartextMessage,
        timestamp: DateTime.now().toUtc(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      // 1. Alice sends message
      await aliceRepo.sendMessage(message);

      // 2. Local-first check: Alice's SQLite stores cleartext
      final aliceMessages = await aliceLocalDb.getMessagesForPartner('@bob', currentUserId: '@alice');
      expect(aliceMessages.length, equals(1));
      expect(aliceMessages.first.text, equals(cleartextMessage));

      // 3. Ephemeral Relay check: Relay queue for Bob has exactly 1 envelope
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(1));
      final pendingOnRelay = await sharedRelay.fetchPendingMessages('@bob');
      expect(pendingOnRelay.first.ciphertextPayload, isNot(contains(cleartextMessage)));
      expect(pendingOnRelay.first.ciphertextPayload, contains('"ct":'));

      // 4. Bob syncs pending messages from ephemeral relay
      final processedByBob = await bobRepo.syncPendingRelayMessages('@bob');
      expect(processedByBob.length, equals(1));
      expect(processedByBob.first.text, equals(cleartextMessage));
      expect(processedByBob.first.status, equals(MessageStatus.delivered));

      // 5. Zero Server Footprint: Relay ciphertext was permanently purged upon Bob's ACK!
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(0));
      final emptyRelayQueue = await sharedRelay.fetchPendingMessages('@bob');
      expect(emptyRelayQueue, isEmpty);

      // 6. Local-first check: Bob's device SQLite now permanently owns the cleartext message
      final bobMessages = await bobLocalDb.getMessagesForPartner('@alice', currentUserId: '@bob');
      expect(bobMessages.length, equals(1));
      expect(bobMessages.first.text, equals(cleartextMessage));
      expect(bobMessages.first.senderId, equals('@alice'));
    });
  });

  group('Phase 12: Message Lifecycle & Monotonic Status State Machine', () {
    test('ChatMessage canTransitionTo validates legal forward progression', () {
      final base = ChatMessage(
        id: 'msg_status_01',
        senderId: '@alice',
        recipientId: '@bob',
        text: 'Progressive status test',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );

      // sending -> sent, failed, or stay sending (cannot jump to delivered/read directly)
      expect(base.canTransitionTo(MessageStatus.sent), isTrue);
      expect(base.canTransitionTo(MessageStatus.failed), isTrue);
      expect(base.canTransitionTo(MessageStatus.sending), isTrue);
      expect(base.canTransitionTo(MessageStatus.delivered), isFalse);
      expect(base.canTransitionTo(MessageStatus.read), isFalse);

      final sentMsg = base.copyWithStatus(MessageStatus.sent);
      expect(sentMsg.canTransitionTo(MessageStatus.delivered), isTrue);
      expect(sentMsg.canTransitionTo(MessageStatus.read), isTrue);
      expect(sentMsg.canTransitionTo(MessageStatus.sending), isFalse); // cannot regress

      final deliveredMsg = base.copyWithStatus(MessageStatus.delivered);
      expect(deliveredMsg.canTransitionTo(MessageStatus.read), isTrue);
      expect(deliveredMsg.canTransitionTo(MessageStatus.sent), isFalse); // cannot regress
      expect(deliveredMsg.canTransitionTo(MessageStatus.sending), isFalse); // cannot regress

      final readMsg = base.copyWithStatus(MessageStatus.read);
      expect(readMsg.isTerminal, isTrue);
      expect(readMsg.canTransitionTo(MessageStatus.read), isTrue);
      expect(readMsg.canTransitionTo(MessageStatus.delivered), isFalse); // cannot regress
      expect(readMsg.canTransitionTo(MessageStatus.sent), isFalse); // cannot regress

      final failedMsg = base.copyWithStatus(MessageStatus.failed);
      expect(failedMsg.isPendingOutbound, isTrue);
      expect(failedMsg.canTransitionTo(MessageStatus.sending), isTrue); // can retry
    });
  });

  group('Phase 12: Offline Queueing, Reconciliation & Receipts Flow', () {
    late AppDatabase aliceDb;
    late LocalDatabase aliceLocalDb;
    late AppDatabase bobDb;
    late LocalDatabase bobLocalDb;
    late InMemoryFirebaseRelayService sharedRelay;
    late StandardE2EEEncryptionService aliceEnc;
    late StandardE2EEEncryptionService bobEnc;
    late LocalChatRepository aliceRepo;
    late LocalChatRepository bobRepo;

    setUp(() async {
      aliceDb = AppDatabase(NativeDatabase.memory());
      aliceLocalDb = LocalDatabase(database: aliceDb);

      bobDb = AppDatabase(NativeDatabase.memory());
      bobLocalDb = LocalDatabase(database: bobDb);

      sharedRelay = InMemoryFirebaseRelayService.isolated();

      final aliceStorage = InMemorySecureStorageService();
      aliceEnc = StandardE2EEEncryptionService(secureStorage: aliceStorage);
      await aliceEnc.initializeUserKeys('@alice');
      final alicePub = await aliceEnc.getPublicIdentityKey();

      final bobStorage = InMemorySecureStorageService();
      bobEnc = StandardE2EEEncryptionService(secureStorage: bobStorage);
      await bobEnc.initializeUserKeys('@bob');
      final bobPub = await bobEnc.getPublicIdentityKey();

      // Alice registers Bob's public key locally
      await aliceLocalDb.saveAccount(UserAccount.create(
        accountId: 'acc_bob_on_alice',
        username: '@bob',
        plaintextPassword: 'password123',
        publicIdentityKey: bobPub,
      ));

      // Bob registers Alice's public key locally
      await bobLocalDb.saveAccount(UserAccount.create(
        accountId: 'acc_alice_on_bob',
        username: '@alice',
        plaintextPassword: 'password123',
        publicIdentityKey: alicePub,
      ));

      aliceRepo = LocalChatRepository(
        database: aliceLocalDb,
        chatService: ChatService(relayService: sharedRelay),
        encryptionService: aliceEnc,
      );

      bobRepo = LocalChatRepository(
        database: bobLocalDb,
        chatService: ChatService(relayService: sharedRelay),
        encryptionService: bobEnc,
      );
    });

    tearDown(() async {
      sharedRelay.dispose();
      await aliceDb.close();
      await bobDb.close();
    });

    test('Offline sending queues message locally with failed status and flushOutboundQueue drains when online', () async {
      // 1. Simulate Alice offline
      aliceRepo.syncService.setOnline(false);
      expect(aliceRepo.syncService.isOnline, isFalse);

      final msg = ChatMessage(
        id: 'offline_msg_01',
        senderId: '@alice',
        recipientId: '@bob',
        text: 'Message typed in a tunnel 🚇',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await aliceRepo.sendMessage(msg);

      // Local database retains cleartext with status 'failed'
      final storedAlice = await aliceLocalDb.getMessageById('offline_msg_01');
      expect(storedAlice, isNotNull);
      expect(storedAlice!.text, equals('Message typed in a tunnel 🚇'));
      expect(storedAlice.status, equals(MessageStatus.failed));

      // Ephemeral relay received nothing because Alice was offline
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(0));

      // 2. Unsent messages query confirms it is queued
      final unsent = await aliceLocalDb.getUnsentMessages(currentUserId: '@alice');
      expect(unsent.length, equals(1));
      expect(unsent.first.id, equals('offline_msg_01'));

      // 3. Alice comes back online and flushes outbound queue
      aliceRepo.syncService.setOnline(true);
      final flushedCount = await aliceRepo.syncService.flushOutboundQueue(currentUserId: '@alice');
      expect(flushedCount, equals(1));

      // 4. Stored message status transitioned to 'sent'
      final updatedAlice = await aliceLocalDb.getMessageById('offline_msg_01');
      expect(updatedAlice!.status, equals(MessageStatus.sent));

      // 5. Ephemeral relay now holds the encrypted ciphertext for Bob
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(1));
    });

    test('retryMessage successfully resends failed message once connectivity is restored', () async {
      aliceRepo.syncService.setOnline(false);

      final msg = ChatMessage(
        id: 'retry_msg_01',
        senderId: '@alice',
        recipientId: '@bob',
        text: 'Will retry this later',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await aliceRepo.sendMessage(msg);
      expect((await aliceLocalDb.getMessageById('retry_msg_01'))!.status, equals(MessageStatus.failed));

      // Alice reconnects and triggers retry
      aliceRepo.syncService.setOnline(true);
      final retrySuccess = await aliceRepo.retryMessage('retry_msg_01', currentUserId: '@alice');
      expect(retrySuccess, isTrue);

      final retried = await aliceLocalDb.getMessageById('retry_msg_01');
      expect(retried!.status, equals(MessageStatus.sent));
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(1));
    });

    test('Full End-to-End Delivery and Read Receipt Synchronization (Alice <-> Bob)', () async {
      // 1. Alice sends message to Bob while online
      final message = ChatMessage(
        id: 'e2ee_receipt_msg',
        senderId: '@alice',
        recipientId: '@bob',
        text: 'Are you free tonight? 🍣',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );

      await aliceRepo.sendMessage(message);

      // Alice's local status is 'sent'
      final aliceMsgSent = await aliceLocalDb.getMessageById('e2ee_receipt_msg');
      expect(aliceMsgSent!.status, equals(MessageStatus.sent));

      // 2. Bob syncs inbound envelopes (message delivery)
      final receivedByBob = await bobRepo.syncPendingRelayMessages('@bob');
      expect(receivedByBob.length, equals(1));
      expect(receivedByBob.first.text, equals('Are you free tonight? 🍣'));
      expect(receivedByBob.first.status, equals(MessageStatus.delivered));

      // Bob's sync automatic delivery receipt dispatch puts a receipt envelope for Alice into relay
      expect(await sharedRelay.getPendingQueueCount('@alice'), equals(1));
      final aliceEnvelopes = await sharedRelay.fetchPendingMessages('@alice');
      expect(aliceEnvelopes.first.isDeliveryReceipt, isTrue);
      expect(aliceEnvelopes.first.targetMessageId, equals('e2ee_receipt_msg'));

      // 3. Alice syncs inbound envelopes -> processes delivery receipt
      await aliceRepo.syncPendingRelayMessages('@alice');

      // Alice's local message status has now progressed to 'delivered'!
      final aliceMsgDelivered = await aliceLocalDb.getMessageById('e2ee_receipt_msg');
      expect(aliceMsgDelivered!.status, equals(MessageStatus.delivered));

      // 4. Bob opens/reads conversation with Alice
      final markedCount = await bobRepo.markConversationAsRead('@alice', currentUserId: '@bob');
      expect(markedCount, equals(1));

      // Bob's message in local SQLite is now 'read'
      final bobStored = await bobLocalDb.getMessageById('e2ee_receipt_msg');
      expect(bobStored!.status, equals(MessageStatus.read));

      // Read receipt is dispatched into the ephemeral relay for Alice
      expect(await sharedRelay.getPendingQueueCount('@alice'), equals(1));
      final aliceReceipts = await sharedRelay.fetchPendingMessages('@alice');
      expect(aliceReceipts.first.isReadReceipt, isTrue);
      expect(aliceReceipts.first.targetMessageId, equals('e2ee_receipt_msg'));

      // 5. Alice syncs inbound envelopes -> processes read receipt
      await aliceRepo.syncPendingRelayMessages('@alice');

      // Alice's message status has now progressed to 'read' (double blue ticks)!
      final aliceMsgRead = await aliceLocalDb.getMessageById('e2ee_receipt_msg');
      expect(aliceMsgRead!.status, equals(MessageStatus.read));

      // 6. Zero server footprint: all queues are completely clean
      expect(await sharedRelay.getPendingQueueCount('@alice'), equals(0));
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(0));
    });

    test('reconcile performs bidirectional drain: syncs incoming receipts & flushes outgoing offline messages', () async {
      // Alice sends while offline
      aliceRepo.syncService.setOnline(false);
      final offlineMsg = ChatMessage(
        id: 'reconcile_out_01',
        senderId: '@alice',
        recipientId: '@bob',
        text: 'Sync on reconnect',
        timestamp: DateTime.now(),
        type: MessageType.text,
        status: MessageStatus.sending,
      );
      await aliceRepo.sendMessage(offlineMsg);
      expect((await aliceLocalDb.getMessageById('reconcile_out_01'))!.status, equals(MessageStatus.failed));

      // Reconnect and reconcile
      aliceRepo.syncService.setOnline(true);
      await aliceRepo.reconcile(currentUserId: '@alice');

      // Message dispatched and updated to sent
      expect((await aliceLocalDb.getMessageById('reconcile_out_01'))!.status, equals(MessageStatus.sent));
      expect(await sharedRelay.getPendingQueueCount('@bob'), equals(1));
    });
  });
}

/// Helper mock implementation for AppLockService during widget/unit tests
class MockAppLockService implements AppLockService {
  final SecureStorageService storage;
  bool _isAppUnlocked;
  bool mockBiometricsAvailable;
  bool mockBiometricsAuthenticateSuccess;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  MockAppLockService({
    SecureStorageService? storage,
    bool isAppUnlocked = false,
    this.mockBiometricsAvailable = true,
    this.mockBiometricsAuthenticateSuccess = true,
  })  : storage = storage ?? InMemorySecureStorageService(),
        _isAppUnlocked = isAppUnlocked;

  @override
  bool get isAppUnlocked => _isAppUnlocked;

  @override
  Stream<bool> get lockStateChanges => _controller.stream;

  @override
  int get failedAttempts => _failedAttempts;

  @override
  bool isLockedOut() {
    if (_lockoutUntil == null) return false;
    return DateTime.now().isBefore(_lockoutUntil!);
  }

  @override
  int remainingLockoutSeconds() {
    if (_lockoutUntil == null) return 0;
    final diff = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  @override
  void resetFailedAttempts() {
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  @override
  void lockApp() {
    _isAppUnlocked = false;
    _controller.add(false);
  }

  @override
  void unlockApp() {
    _isAppUnlocked = true;
    resetFailedAttempts();
    _controller.add(true);
  }

  @override
  Future<bool> isPasscodeConfigured() async {
    final v = await storage.read('app_lock_passcode_verifier');
    return v != null && v.isNotEmpty;
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    final e = await storage.read('app_lock_biometrics_enabled');
    return e == 'true';
  }

  @override
  Future<bool> isBiometricsAvailable() async => mockBiometricsAvailable;

  @override
  Future<void> setPasscode(String passcode) async {
    final salt = HashUtils.generateSalt();
    final verifier = HashUtils.hashPassword(passcode, salt);
    await storage.write('app_lock_passcode_salt', salt);
    await storage.write('app_lock_passcode_verifier', verifier);
    resetFailedAttempts();
  }

  @override
  Future<bool> verifyPasscode(String candidate) async {
    if (isLockedOut()) return false;
    final salt = await storage.read('app_lock_passcode_salt');
    final verifier = await storage.read('app_lock_passcode_verifier');
    if (salt == null || verifier == null) return false;
    final valid = HashUtils.hashPassword(candidate, salt) == verifier;
    if (valid) {
      resetFailedAttempts();
      unlockApp();
    } else {
      _failedAttempts += 1;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
      }
    }
    return valid;
  }

  @override
  Future<bool> authenticateWithBiometrics({String reason = ''}) async {
    if (mockBiometricsAuthenticateSuccess) {
      unlockApp();
      return true;
    }
    return false;
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    await storage.write('app_lock_biometrics_enabled', enabled ? 'true' : 'false');
  }

  @override
  Future<void> clearPasscode() async {
    await storage.delete('app_lock_passcode_verifier');
    await storage.delete('app_lock_passcode_salt');
    await storage.delete('app_lock_biometrics_enabled');
    resetFailedAttempts();
    lockApp();
  }
}

/// Mock chat transport capturing messages for E2EE testing
class MockChatTransportService extends ChatService {
  ChatMessage? lastDispatchedMessage;

  MockChatTransportService({RelayService? relayService})
      : super(relayService: relayService ?? InMemoryFirebaseRelayService.isolated());

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) async {
    lastDispatchedMessage = message;
    return super.sendMessage(message);
  }
}





