import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/core/utils/recovery_key_utils.dart';
import 'package:chatbox/models/user.dart';

/// Internal account entity encapsulating credentials, recovery keys, and salted password verification
class UserAccount {
  final String accountId;
  final String username;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final String? publicIdentityKey;
  final String? recoveryKeyHash;
  final String? recoveryKeySalt;

  UserAccount({
    required this.accountId,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.publicIdentityKey,
    this.recoveryKeyHash,
    this.recoveryKeySalt,
  });

  /// Factory to create a new UserAccount securely by salting and hashing the plaintext password
  factory UserAccount.create({
    required String accountId,
    required String username,
    required String plaintextPassword,
    String? publicIdentityKey,
    String? recoveryKeyHash,
    String? recoveryKeySalt,
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
      recoveryKeyHash: recoveryKeyHash,
      recoveryKeySalt: recoveryKeySalt,
    );
  }

  /// Verify candidate password against the salted password hash
  bool verifyPassword(String candidatePassword) {
    final candidateHash = HashUtils.hashPassword(candidatePassword, salt);
    return candidateHash == passwordHash;
  }

  /// Verify candidate recovery phrase against stored recovery key hash
  bool verifyRecoveryKey(String candidatePhrase) {
    if (recoveryKeyHash == null || recoveryKeySalt == null) return false;
    return RecoveryKeyUtils.verifyRecoveryKey(
      candidatePhrase: candidatePhrase,
      storedHash: recoveryKeyHash!,
      salt: recoveryKeySalt!,
    );
  }

  /// Return copy with updated fields
  UserAccount copyWith({
    String? passwordHash,
    String? salt,
    String? publicIdentityKey,
    String? recoveryKeyHash,
    String? recoveryKeySalt,
  }) {
    return UserAccount(
      accountId: accountId,
      username: username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt,
      publicIdentityKey: publicIdentityKey ?? this.publicIdentityKey,
      recoveryKeyHash: recoveryKeyHash ?? this.recoveryKeyHash,
      recoveryKeySalt: recoveryKeySalt ?? this.recoveryKeySalt,
    );
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
      'recoveryKeyHash': recoveryKeyHash,
      'recoveryKeySalt': recoveryKeySalt,
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
      recoveryKeyHash: json['recoveryKeyHash'] as String?,
      recoveryKeySalt: json['recoveryKeySalt'] as String?,
    );
  }
}

