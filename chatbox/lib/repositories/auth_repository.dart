import 'package:chatbox/models/user.dart';
import 'package:chatbox/services/auth_service.dart';

/// Abstract contract for authentication operations (Phase 6 - Firebase Auth)
abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<User> signIn(String email, String password);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
}

/// Initial implementation backed by AuthService
class DefaultAuthRepository implements AuthRepository {
  final AuthService _authService;

  DefaultAuthRepository({AuthService? authService})
      : _authService = authService ?? LocalAuthService();

  @override
  Future<User?> getCurrentUser() => _authService.getCurrentUser();

  @override
  Future<User> signIn(String email, String password) =>
      _authService.signInWithCredentials(email, password);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;
}
