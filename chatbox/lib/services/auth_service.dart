import 'dart:async';
import 'dart:math';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/models/user_account.dart';

/// Abstract service contract for anonymous identity authentication (Phase 6)
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> register({required String username, required String password});
  Future<User> login({required String username, required String password});
  Future<void> signOut();
  Future<bool> isUsernameAvailable(String username);
  Stream<User?> get authStateChanges;
}

/// Local-first anonymous authentication service backed by Drift / SQLite
class LocalAuthService implements AuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();

  factory LocalAuthService({LocalDatabase? database, bool resetSession = false}) {
    if (database != null) {
      _instance._database = database;
    }
    if (resetSession) {
      _instance.resetDefaultSession();
    }
    return _instance;
  }

  LocalAuthService._internal();

  void resetDefaultSession() {
    _currentUser = User(
      id: 'current_user',
      username: '@alex',
      displayName: 'Alex',
      isCurrentUser: true,
    );
  }

  LocalDatabase? _database;
  LocalDatabase get _db => _database ?? LocalDatabase();

  User? _currentUser = User(
    id: 'current_user',
    username: '@alex',
    displayName: 'Alex',
    isCurrentUser: true,
  );
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Stream<User?> get authStateChanges async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final validationError = HashUtils.validateUsername(username);
    if (validationError != null) return false;
    final taken = await _db.isUsernameTaken(username);
    return !taken;
  }

  @override
  Future<User> register({
    required String username,
    required String password,
  }) async {
    // 1. Validate username format
    final usernameError = HashUtils.validateUsername(username);
    if (usernameError != null) {
      throw AuthException(usernameError, code: 'INVALID_USERNAME');
    }

    // 2. Validate password format
    final passwordError = HashUtils.validatePassword(password);
    if (passwordError != null) {
      throw AuthException(passwordError, code: 'INVALID_PASSWORD');
    }

    final normalized = HashUtils.normalizeUsername(username);

    // 3. Check username uniqueness
    final isTaken = await _db.isUsernameTaken(normalized);
    if (isTaken) {
      throw AuthException(
        'Username $normalized is already taken',
        code: 'USERNAME_TAKEN',
      );
    }

    // 4. Generate random account ID
    final randomSuffix = Random.secure().nextInt(90000) + 10000;
    final accountId = 'acc_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

    // 5. Create secure UserAccount (salted hash verifier, never plaintext)
    final account = UserAccount.create(
      accountId: accountId,
      username: normalized,
      plaintextPassword: password,
    );

    // 6. Persist locally
    await _db.saveAccount(account);

    // 7. Establish authenticated session
    _currentUser = account.toUser(isCurrentUser: true);
    _authStateController.add(_currentUser);

    return _currentUser!;
  }

  @override
  Future<User> login({
    required String username,
    required String password,
  }) async {
    final normalized = HashUtils.normalizeUsername(username);

    // 1. Retrieve account by username
    final account = await _db.getAccountByUsername(normalized);
    if (account == null) {
      throw const AuthException(
        'Incorrect username or password',
        code: 'INVALID_CREDENTIALS',
      );
    }

    // 2. Verify candidate password against salted hash verifier
    final isValid = account.verifyPassword(password);
    if (!isValid) {
      throw const AuthException(
        'Incorrect username or password',
        code: 'INVALID_CREDENTIALS',
      );
    }

    // 3. Establish authenticated session
    _currentUser = account.toUser(isCurrentUser: true);
    _authStateController.add(_currentUser);

    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }
}
