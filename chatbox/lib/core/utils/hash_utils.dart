import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic and formatting utilities for anonymous identity authentication
class HashUtils {
  static final Random _secureRandom = Random.secure();

  /// Generate a cryptographically secure random salt hex string
  static String generateSalt([int length = 16]) {
    final values = List<int>.generate(length, (i) => _secureRandom.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash a candidate password with a unique per-account salt using SHA-256
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Normalize a username into standard '@username' format (lowercase, trimmed)
  static String normalizeUsername(String input) {
    final clean = input.trim().replaceAll('@', '').toLowerCase();
    return '@$clean';
  }

  /// Extract raw handle without leading '@'
  static String rawUsername(String input) {
    return input.trim().replaceAll('@', '').toLowerCase();
  }

  /// Validate username against privacy and format constraints:
  /// - 3 to 20 alphanumeric characters or underscores
  /// - No whitespace or special symbols
  static String? validateUsername(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Username is required';
    }
    final raw = rawUsername(input);
    if (raw.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (raw.length > 20) {
      return 'Username cannot exceed 20 characters';
    }
    final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validCharacters.hasMatch(raw)) {
      return 'Only letters, numbers, and underscores are allowed';
    }
    return null;
  }

  /// Validate password constraints (minimum 6 characters)
  static String? validatePassword(String? input) {
    if (input == null || input.isEmpty) {
      return 'Password is required';
    }
    if (input.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
