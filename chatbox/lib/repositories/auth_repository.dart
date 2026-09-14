import 'package:chatbox/models/user.dart';
import 'package:chatbox/services/auth_service.dart';

/// Abstract contract for authentication operations (Phase 6 - Anonymous Identity System)
abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User> register({required String username, required String password});
  Future<User> login({required String username, required String password});
  Future<void> signOut();
  Future<bool> isUsernameAvailable(String username);
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
  }) =>
      _authService.register(username: username, password: password);

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
  Stream<User?> get authStateChanges => _authService.authStateChanges;
}
