import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure key-value storage contract for device-only secrets and lock state
abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Production implementation backed by FlutterSecureStorage (hardware-backed keystore/keychain)
///
/// Automatically uses in-memory sandbox during headless test execution to prevent
/// native platform channel blocking.
class DefaultSecureStorageService implements SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _inMemoryFallback = {};
  final bool _isTestMode;

  DefaultSecureStorageService({FlutterSecureStorage? storage, bool? isTestMode})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            ),
        _isTestMode = isTestMode ??
            (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  @override
  Future<String?> read(String key) async {
    if (_isTestMode) {
      return _inMemoryFallback[key];
    }
    try {
      final val = await _storage.read(key: key);
      return val ?? _inMemoryFallback[key];
    } catch (_) {
      return _inMemoryFallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _inMemoryFallback[key] = value;
    if (_isTestMode) return;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    _inMemoryFallback.remove(key);
    if (_isTestMode) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  @override
  Future<void> deleteAll() async {
    _inMemoryFallback.clear();
    if (_isTestMode) return;
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}

/// In-memory secure storage implementation for unit/widget testing and isolated execution
class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _data = {};

  InMemorySecureStorageService([Map<String, String>? initialData]) {
    if (initialData != null) {
      _data.addAll(initialData);
    }
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}
