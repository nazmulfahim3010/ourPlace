import 'dart:async';
import 'package:chatbox/core/config/app_environment.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/services/firebase_rest_client.dart';
import 'package:firebase_core/firebase_core.dart';
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

/// Production implementation backed by Firebase Realtime Database with REST fallback
class FirebaseUserDirectoryService implements UserDirectoryService {
  final FirebaseDatabase _database;
  final FirebaseRestDatabaseClient _restClient;

  FirebaseUserDirectoryService({
    FirebaseDatabase? database,
    FirebaseRestDatabaseClient? restClient,
  })  : _database = database ?? _defaultDatabase(),
        _restClient = restClient ?? FirebaseRestDatabaseClient();

  static FirebaseDatabase _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: AppConstants.firebaseDatabaseUrl,
      );
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

  String _sanitizeKey(String username) {
    return HashUtils.normalizeUsername(username).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  DatabaseReference _dirRef(String username) {
    final key = _sanitizeKey(username);
    return _database.ref('directory').child(key);
  }

  @override
  Future<void> publishProfile(DirectoryProfile profile) async {
    final key = _sanitizeKey(profile.username);
    final json = profile.toJson();

    // 1. Write via REST
    await _restClient.put('directory/$key', json);

    // 2. Write via native SDK if available
    try {
      await _dirRef(profile.username).set(json);
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService (native set notice): $e');
    }
  }

  @override
  Future<DirectoryProfile?> lookupProfile(String username) async {
    final key = _sanitizeKey(username);

    // 1. Try native Firebase SDK
    try {
      final snapshot = await _dirRef(username).get();
      if (snapshot.exists && snapshot.value != null && snapshot.value is Map) {
        return DirectoryProfile.fromJson(Map<String, dynamic>.from(snapshot.value as Map));
      }
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService (native get notice): $e');
    }

    // 2. Fallback to direct REST HTTP
    try {
      final data = await _restClient.get('directory/$key');
      if (data is Map) {
        return DirectoryProfile.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('FirebaseUserDirectoryService REST lookup error: $e');
    }

    return null;
  }

  @override
  Future<void> updateFcmToken({
    required String username,
    required String fcmToken,
  }) async {
    final key = _sanitizeKey(username);
    final payload = {
      'fcmToken': fcmToken,
      'lastSeen': DateTime.now().toUtc().toIso8601String(),
    };
    await _restClient.patch('directory/$key', payload);
    try {
      await _dirRef(username).update(payload);
    } catch (_) {}
  }

  @override
  Future<void> updateLastSeen(String username) async {
    final key = _sanitizeKey(username);
    final payload = {
      'lastSeen': DateTime.now().toUtc().toIso8601String(),
    };
    await _restClient.patch('directory/$key', payload);
    try {
      await _dirRef(username).update(payload);
    } catch (_) {}
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
