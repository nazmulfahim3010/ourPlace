/// Base application exception
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Local database failures
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.details});
}

/// Messaging & Chat failures
class ChatException extends AppException {
  const ChatException(super.message, {super.code, super.details});
}

/// Authentication failures (Phase 6)
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.details});
}

/// Cryptographic failures (Phase 8)
class EncryptionException extends AppException {
  const EncryptionException(super.message, {super.code, super.details});
}

/// Security & Tamper detection failures (Phase 9 & 10)
class SecurityException extends AppException {
  const SecurityException(super.message, {super.code, super.details});
}

/// Love Connection failures (Phase 16)
class LoveConnectionException extends AppException {
  const LoveConnectionException(super.message, {super.code, super.details});
}

/// Conversation Sharing failures (Phase 17)
class ConversationSharingException extends AppException {
  const ConversationSharingException(super.message, {super.code, super.details});
}

