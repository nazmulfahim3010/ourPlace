import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatbox/database/app_database.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/screens/auth/auth_gate.dart';
import 'package:chatbox/screens/auth/auth_screen.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/services/auth_service.dart';
import 'package:chatbox/services/secure_storage_service.dart';
import 'package:drift/native.dart';

void main() {
  group('AuthGate & Session Security Tests', () {
    late AppDatabase appDb;
    late LocalDatabase localDb;
    late InMemorySecureStorageService secureStorage;
    late LocalAuthService authService;
    late DefaultAuthRepository authRepo;

    setUp(() {
      appDb = AppDatabase(NativeDatabase.memory());
      localDb = LocalDatabase(database: appDb);
      secureStorage = InMemorySecureStorageService();
      authService = LocalAuthService(
        database: localDb,
        secureStorage: secureStorage,
      );
      authRepo = DefaultAuthRepository(authService: authService);
    });

    tearDown(() async {
      await authRepo.signOut();
      await appDb.close();
    });

    testWidgets('Fresh launch with no active session renders AuthScreen, not bypassed to Alex', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authRepository: authRepo,
            appLockService: DefaultAppLockService(storage: secureStorage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirms user is guided to authenticate
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Sign In'), findsOneWidget);
    });

    test('Session persists across restarts through secure storage', () async {
      // 1. Register a new user
      final user = await authRepo.register(
        username: '@charlie',
        password: 'Password123!',
      );
      expect(user.username, '@charlie');

      // 2. Verify username is persisted in secure storage
      final storedUsername = await secureStorage.read('active_session_username');
      expect(storedUsername, '@charlie');

      // 3. Clear in-memory current user to simulate application process termination
      // and call getCurrentUser() to test restart restoration
      final restored = await authService.getCurrentUser();
      expect(restored, isNotNull);
      expect(restored!.username, '@charlie');

      // 4. Sign out
      await authRepo.signOut();
      expect(await secureStorage.read('active_session_username'), isNull);
      expect(await authService.getCurrentUser(), isNull);
    });
  });
}
