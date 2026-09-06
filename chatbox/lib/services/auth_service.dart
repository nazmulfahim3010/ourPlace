import 'package:chatbox/models/user.dart';

/// Abstract service contract for authentication (Phase 6 - Firebase Auth)
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> signInWithCredentials(String email, String password);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
}

/// Initial local/mock implementation of AuthService
class LocalAuthService implements AuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  User? _currentUser = const User(
    id: 'current_user',
    displayName: 'You',
    isCurrentUser: true,
  );

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Future<User> signInWithCredentials(String email, String password) async {
    _currentUser = const User(
      id: 'current_user',
      displayName: 'You',
      isCurrentUser: true,
    );
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Stream<User?> get authStateChanges async* {
    yield _currentUser;
  }
}
