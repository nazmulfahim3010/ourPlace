import 'dart:async';
import 'dart:math';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/core/utils/recovery_key_utils.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/models/user_account.dart';
import 'package:chatbox/services/access_throttling_service.dart';
import 'package:chatbox/services/encryption_service.dart';

/// Abstract service contract for anonymous identity authentication (Phase 6 & 9)
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> register({
    required String username,
    required String password,
    String? recoveryKey,
  });
  Future<User> login({required String username, required String password});
  Future<void> signOut();
  Future<bool> isUsernameAvailable(String username);
  Future<bool> resetPasswordWithRecoveryKey({
    required String username,
    required String recoveryPhrase,
    required String newPassword,
  });
  Future<bool> setRecoveryKey({
    required String username,
    required String recoveryPhrase,
  });
  Duration getRemainingLoginCooldown(String username);
  String? get lastRegisteredRecoveryKey;
  Stream<User?> get authStateChanges;
}

/// Local-first anonymous authentication service backed by Drift / SQLite
class LocalAuthService implements AuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();

  factory LocalAuthService({
    LocalDatabase? database,
    AccessThrottlingService? throttlingService,
    EncryptionService? encryptionService,
    bool resetSession = false,
  }) {
    if (database != null) {
      _instance._database = database;
    }
    if (throttlingService != null) {
      _instance._throttlingService = throttlingService;
    }
    if (encryptionService != null) {
      _instance._encryptionService = encryptionService;
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

  AccessThrottlingService _throttlingService = AccessThrottlingService();
  EncryptionService _encryptionService = StandardE2EEEncryptionService();

  String? _lastRegisteredRecoveryKey;

  @override
  String? get lastRegisteredRecoveryKey => _lastRegisteredRecoveryKey;

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
  Duration getRemainingLoginCooldown(String username) {
    return _throttlingService.getRemainingCooldown(username);
  }

  @override
  Future<User> register({
    required String username,
    required String password,
    String? recoveryKey,
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

    // 5. Generate and hash 12-word recovery key
    final phrase = recoveryKey ?? RecoveryKeyUtils.generateMnemonic();
    _lastRegisteredRecoveryKey = phrase;
    final recoverySalt = HashUtils.generateSalt();
    final recoveryHash = RecoveryKeyUtils.hashRecoveryKey(phrase, recoverySalt);

    // 5b. Generate and store E2EE X25519 identity keypair in hardware secure storage
    await _encryptionService.initializeUserKeys(accountId);
    final publicIdentityKey = await _encryptionService.getPublicIdentityKey();

    // 6. Create secure UserAccount (salted hash verifiers, never plaintext)
    final account = UserAccount.create(
      accountId: accountId,
      username: normalized,
      plaintextPassword: password,
      publicIdentityKey: publicIdentityKey,
      recoveryKeyHash: recoveryHash,
      recoveryKeySalt: recoverySalt,
    );

    // 7. Persist locally
    await _db.saveAccount(account);
    await _db.logSecurityEvent(
      'account_created',
      'New anonymous account registered: $normalized with E2EE identity key',
      severity: 'info',
    );

    // 8. Establish authenticated session
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

    // 1. Check rate limiting & exponential backoff
    if (!_throttlingService.canAttemptLogin(normalized)) {
      final cooldown = _throttlingService.getRemainingCooldown(normalized);
      await _db.logSecurityEvent(
        'login_throttled',
        'Login blocked due to rate limit for $normalized (${cooldown.inSeconds}s left)',
        severity: 'warning',
      );
      throw AuthException(
        'Too many failed attempts. Please wait ${cooldown.inSeconds} seconds.',
        code: 'RATE_LIMITED',
      );
    }

    // 2. Retrieve account by username
    final account = await _db.getAccountByUsername(normalized);
    if (account == null) {
      _throttlingService.recordFailedLogin(normalized);
      await _db.logSecurityEvent(
        'login_failed',
        'Failed login attempt for unknown username: $normalized',
        severity: 'warning',
      );
      throw const AuthException(
        'Incorrect username or password',
        code: 'INVALID_CREDENTIALS',
      );
    }

    // 3. Verify candidate password against salted hash verifier
    final isValid = account.verifyPassword(password);
    if (!isValid) {
      _throttlingService.recordFailedLogin(normalized);
      await _db.logSecurityEvent(
        'login_failed',
        'Incorrect password entered for: $normalized',
        severity: 'warning',
      );
      throw const AuthException(
        'Incorrect username or password',
        code: 'INVALID_CREDENTIALS',
      );
    }

    // 4. Clear throttling on successful login
    _throttlingService.recordSuccessfulLogin(normalized);

    // 4b. Load E2EE keys for authenticated session
    await _encryptionService.initializeUserKeys(account.accountId);

    await _db.logSecurityEvent(
      'login_success',
      'Successful authentication for: $normalized',
      severity: 'info',
    );

    // 5. Establish authenticated session
    _currentUser = account.toUser(isCurrentUser: true);
    _authStateController.add(_currentUser);

    return _currentUser!;
  }

  @override
  Future<bool> resetPasswordWithRecoveryKey({
    required String username,
    required String recoveryPhrase,
    required String newPassword,
  }) async {
    final passwordError = HashUtils.validatePassword(newPassword);
    if (passwordError != null) {
      throw AuthException(passwordError, code: 'INVALID_PASSWORD');
    }

    final phraseError = RecoveryKeyUtils.validateMnemonic(recoveryPhrase);
    if (phraseError != null) {
      throw AuthException(phraseError, code: 'INVALID_RECOVERY_KEY');
    }

    final normalized = HashUtils.normalizeUsername(username);
    final success = await _db.resetPasswordWithRecoveryKey(
      username: normalized,
      recoveryPhrase: recoveryPhrase,
      newPlaintextPassword: newPassword,
    );

    if (!success) {
      throw const AuthException(
        'Invalid recovery phrase for this account',
        code: 'INVALID_RECOVERY_KEY',
      );
    }

    _throttlingService.reset(normalized);
    return true;
  }

  @override
  Future<bool> setRecoveryKey({
    required String username,
    required String recoveryPhrase,
  }) async {
    final phraseError = RecoveryKeyUtils.validateMnemonic(recoveryPhrase);
    if (phraseError != null) {
      throw AuthException(phraseError, code: 'INVALID_RECOVERY_KEY');
    }

    final normalized = HashUtils.normalizeUsername(username);
    final salt = HashUtils.generateSalt();
    final hash = RecoveryKeyUtils.hashRecoveryKey(recoveryPhrase, salt);

    return await _db.setAccountRecoveryKey(
      normalized,
      recoveryKeyHash: hash,
      recoveryKeySalt: salt,
    );
  }

  @override
  Future<void> signOut() async {
    if (_currentUser != null) {
      await _db.logSecurityEvent(
        'sign_out',
        'User signed out: ${_currentUser?.username}',
        severity: 'info',
      );
    }
    await _encryptionService.clearKeys();
    _currentUser = null;
    _authStateController.add(null);
  }
}

