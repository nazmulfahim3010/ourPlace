import 'package:chatbox/models/user.dart';
import 'package:chatbox/services/auth_service.dart';

/// Abstract contract for authentication operations (Phase 6 & 9)
abstract class AuthRepository {
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

/// Primary implementation coordinating authentication via AuthService
class DefaultAuthRepository implements AuthRepository {
  final AuthService _authService;

  DefaultAuthRepository({AuthService? authService})
      : _authService = authService ?? LocalAuthService();

  @override
  Future<User?> getCurrentUser() => _authService.getCurrentUser();

  @override
  Future<User> register({
    required String username,
    required String password,
    String? recoveryKey,
  }) =>
      _authService.register(
        username: username,
        password: password,
        recoveryKey: recoveryKey,
      );

  @override
  Future<User> login({
    required String username,
    required String password,
  }) =>
      _authService.login(username: username, password: password);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _authService.isUsernameAvailable(username);

  @override
  Future<bool> resetPasswordWithRecoveryKey({
    required String username,
    required String recoveryPhrase,
    required String newPassword,
  }) =>
      _authService.resetPasswordWithRecoveryKey(
        username: username,
        recoveryPhrase: recoveryPhrase,
        newPassword: newPassword,
      );

  @override
  Future<bool> setRecoveryKey({
    required String username,
    required String recoveryPhrase,
  }) =>
      _authService.setRecoveryKey(
        username: username,
        recoveryPhrase: recoveryPhrase,
      );

  @override
  Duration getRemainingLoginCooldown(String username) =>
      _authService.getRemainingLoginCooldown(username);

  @override
  String? get lastRegisteredRecoveryKey => _authService.lastRegisteredRecoveryKey;

  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;
}

