import 'dart:async';
import 'package:chatbox/core/config/app_environment.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// User identity metadata published to the public lookup directory
class DirectoryProfile {
  final String accountId;
  final String username;
  final String publicIdentityKey;
  final String? fcmToken;
  final DateTime lastSeen;

  const DirectoryProfile({
    required this.accountId,
    required this.username,
    required this.publicIdentityKey,
    this.fcmToken,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'username': username,
        'publicIdentityKey': publicIdentityKey,
        if (fcmToken != null) 'fcmToken': fcmToken,
        'lastSeen': lastSeen.toUtc().toIso8601String(),
      };

  factory DirectoryProfile.fromJson(Map<String, dynamic> json) => DirectoryProfile(
        accountId: json['accountId'] as String? ?? '',
        username: json['username'] as String? ?? '',
        publicIdentityKey: json['publicIdentityKey'] as String? ?? '',
        fcmToken: json['fcmToken'] as String?,
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
      );

  DirectoryProfile copyWith({
    String? accountId,
    String? username,
    String? publicIdentityKey,
    String? fcmToken,
    DateTime? lastSeen,
  }) {
    return DirectoryProfile(
      accountId: accountId ?? this.accountId,
      username: username ?? this.username,
      publicIdentityKey: publicIdentityKey ?? this.publicIdentityKey,
      fcmToken: fcmToken ?? this.fcmToken,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Abstract contract for central user identity & public key registry
abstract class UserDirectoryService {
  /// Publish or update user's public identity metadata
  Future<void> publishProfile(DirectoryProfile profile);

  /// Look up user's public identity and public key by normalized username
  Future<DirectoryProfile?> lookupProfile(String username);

  /// Update FCM registration token for background push delivery
  Future<void> updateFcmToken({
    required String username,
    required String fcmToken,
  });

  /// Update last seen heartbeat timestamp
  Future<void> updateLastSeen(String username);
}

/// In-memory mock implementation for testing and isolated offline execution
class InMemoryUserDirectoryService implements UserDirectoryService {
  final Map<String, DirectoryProfile> _directory = {};

  InMemoryUserDirectoryService([Map<String, DirectoryProfile>? initial]) {
    if (initial != null) {
      _directory.addAll(initial);
    }
  }

  @override
  Future<void> publishProfile(DirectoryProfile profile) async {
    final key = HashUtils.normalizeUsername(profile.username);
    _directory[key] = profile;
  }

  @override
  Future<DirectoryProfile?> lookupProfile(String username) async {
    final key = HashUtils.normalizeUsername(username);
    return _directory[key];
  }

  @override
  Future<void> updateFcmToken({
    required String username,
    required String fcmToken,
  }) async {
    final key = HashUtils.normalizeUsername(username);
    final existing = _directory[key];
    if (existing != null) {
      _directory[key] = existing.copyWith(fcmToken: fcmToken);
    }
  }

  @override
  Future<void> updateLastSeen(String username) async {
    final key = HashUtils.normalizeUsername(username);
    final existing = _directory[key];
    if (existing != null) {
      _directory[key] = existing.copyWith(lastSeen: DateTime.now());
    }
  }
}

/// Production implementation backed by Firebase Realtime Database
class FirebaseUserDirectoryService implements UserDirectoryService {
  final FirebaseDatabase _database;

  FirebaseUserDirectoryService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  String _sanitizeKey(String username) {
    return HashUtils.normalizeUsername(username).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  DatabaseReference _dirRef(String username) {
    final key = _sanitizeKey(username);
    return _database.ref('directory').child(key);
  }

  @override
  Future<void> publishProfile(DirectoryProfile profile) async {
    try {
      await _dirRef(profile.username).set(profile.toJson());
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService: publishProfile error: $e');
    }
  }

  @override
  Future<DirectoryProfile?> lookupProfile(String username) async {
    try {
      final snapshot = await _dirRef(username).get();
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }
      final raw = snapshot.value;
      if (raw is Map) {
        return DirectoryProfile.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService: lookupProfile error: $e');
      return null;
    }
  }

  @override
  Future<void> updateFcmToken({
    required String username,
    required String fcmToken,
  }) async {
    try {
      await _dirRef(username).update({
        'fcmToken': fcmToken,
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService: updateFcmToken error: $e');
    }
  }

  @override
  Future<void> updateLastSeen(String username) async {
    try {
      await _dirRef(username).update({
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService: updateLastSeen error: $e');
    }
  }
}

/// Factory that chooses between [FirebaseUserDirectoryService] in production
/// and [InMemoryUserDirectoryService] in test mode.
class DefaultUserDirectoryService implements UserDirectoryService {
  static final DefaultUserDirectoryService _instance = DefaultUserDirectoryService._internal();
  factory DefaultUserDirectoryService() => _instance;
  DefaultUserDirectoryService._internal();

  UserDirectoryService? _delegate;

  UserDirectoryService get delegate {
    if (_delegate != null) return _delegate!;
    if (AppEnvironment.isProduction) {
      _delegate = FirebaseUserDirectoryService();
    } else {
      _delegate = InMemoryUserDirectoryService();
    }
    return _delegate!;
  }

  @visibleForTesting
  void setDelegate(UserDirectoryService service) {
    _delegate = service;
  }

  @override
  Future<void> publishProfile(DirectoryProfile profile) => delegate.publishProfile(profile);

  @override
  Future<DirectoryProfile?> lookupProfile(String username) => delegate.lookupProfile(username);

  @override
  Future<void> updateFcmToken({required String username, required String fcmToken}) =>
      delegate.updateFcmToken(username: username, fcmToken: fcmToken);

  @override
  Future<void> updateLastSeen(String username) => delegate.updateLastSeen(username);
}
