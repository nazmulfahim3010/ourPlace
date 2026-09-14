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
}

/// Helper mock implementation for AppLockService during widget/unit tests
class MockAppLockService implements AppLockService {
  final SecureStorageService storage;
  bool _isAppUnlocked;
  bool mockBiometricsAvailable;
  bool mockBiometricsAuthenticateSuccess;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

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
  void lockApp() {
    _isAppUnlocked = false;
    _controller.add(false);
  }

  @override
  void unlockApp() {
    _isAppUnlocked = true;
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
  }

  @override
  Future<bool> verifyPasscode(String candidate) async {
    final salt = await storage.read('app_lock_passcode_salt');
    final verifier = await storage.read('app_lock_passcode_verifier');
    if (salt == null || verifier == null) return false;
    final valid = HashUtils.hashPassword(candidate, salt) == verifier;
    if (valid) unlockApp();
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
    lockApp();
  }
}

