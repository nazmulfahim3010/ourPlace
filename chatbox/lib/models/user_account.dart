import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/models/user.dart';

/// Internal account entity encapsulating credentials and salted password verification
class UserAccount {
  final String accountId;
  final String username;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final String? publicIdentityKey;

  UserAccount({
    required this.accountId,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.publicIdentityKey,
  });

  /// Factory to create a new UserAccount securely by salting and hashing the plaintext password
  factory UserAccount.create({
    required String accountId,
    required String username,
    required String plaintextPassword,
    String? publicIdentityKey,
  }) {
    final salt = HashUtils.generateSalt();
    final passwordHash = HashUtils.hashPassword(plaintextPassword, salt);
    final normalized = HashUtils.normalizeUsername(username);

    return UserAccount(
      accountId: accountId,
      username: normalized,
      passwordHash: passwordHash,
      salt: salt,
      createdAt: DateTime.now(),
      publicIdentityKey: publicIdentityKey,
    );
  }

  /// Verify candidate password against the salted password hash
  bool verifyPassword(String candidatePassword) {
    final candidateHash = HashUtils.hashPassword(candidatePassword, salt);
    return candidateHash == passwordHash;
  }

  /// Convert to public User domain model (omitting credentials)
  User toUser({bool isCurrentUser = false}) {
    return User(
      id: accountId,
      username: username,
      displayName: username,
      createdAt: createdAt,
      publicIdentityKey: publicIdentityKey,
      isCurrentUser: isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'username': username,
      'passwordHash': passwordHash,
      'salt': salt,
      'createdAt': createdAt.toIso8601String(),
      'publicIdentityKey': publicIdentityKey,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      accountId: json['accountId'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      publicIdentityKey: json['publicIdentityKey'] as String?,
    );
  }
}
