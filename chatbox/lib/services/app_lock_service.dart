import 'dart:async';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/services/secure_storage_service.dart';

/// Service contract managing local device passcode and biometric authentication
abstract class AppLockService {
  Future<bool> isPasscodeConfigured();
  Future<bool> isBiometricsEnabled();
  Future<bool> isBiometricsAvailable();
  Future<void> setPasscode(String passcode);
  Future<bool> verifyPasscode(String candidate);
  Future<bool> authenticateWithBiometrics({
    String reason = 'Unlock ourPlace to access your private conversations',
  });
  Future<void> setBiometricsEnabled(bool enabled);
  Future<void> clearPasscode();

  bool get isAppUnlocked;
  void lockApp();
  void unlockApp();
  Stream<bool> get lockStateChanges;

  bool isLockedOut();
  int remainingLockoutSeconds();
  int get failedAttempts;
  void resetFailedAttempts();
}


/// Production implementation backed by hardware secure storage and platform biometrics
class DefaultAppLockService implements AppLockService {
  static final DefaultAppLockService _instance = DefaultAppLockService._internal();

  factory DefaultAppLockService({
    SecureStorageService? storage,
    LocalAuthentication? localAuth,
  }) {
    if (storage != null) {
      _instance._storage = storage;
    }
    if (localAuth != null) {
      _instance._localAuth = localAuth;
    }
    return _instance;
  }

  DefaultAppLockService._internal();

  SecureStorageService _storage = DefaultSecureStorageService();
  LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyPasscodeVerifier = 'app_lock_passcode_verifier';
  static const String _keyPasscodeSalt = 'app_lock_passcode_salt';
  static const String _keyBiometricsEnabled = 'app_lock_biometrics_enabled';

  bool _isAppUnlocked = false;
  int _failedPasscodeAttempts = 0;
  DateTime? _lockoutUntil;
  final StreamController<bool> _lockStateController =
      StreamController<bool>.broadcast();

  @override
  bool get isAppUnlocked => _isAppUnlocked;

  @override
  Stream<bool> get lockStateChanges => _lockStateController.stream;

  @override
  int get failedAttempts => _failedPasscodeAttempts;

  @override
  bool isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isBefore(_lockoutUntil!)) {
      return true;
    }
    _lockoutUntil = null;
    return false;
  }

  @override
  int remainingLockoutSeconds() {
    if (_lockoutUntil == null) return 0;
    final diff = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  @override
  void resetFailedAttempts() {
    _failedPasscodeAttempts = 0;
    _lockoutUntil = null;
  }

  @override
  void lockApp() {
    _isAppUnlocked = false;
    _lockStateController.add(false);
  }

  @override
  void unlockApp() {
    _isAppUnlocked = true;
    resetFailedAttempts();
    _lockStateController.add(true);
  }

  @override
  Future<bool> isPasscodeConfigured() async {
    final verifier = await _storage.read(_keyPasscodeVerifier);
    return verifier != null && verifier.isNotEmpty;
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    final enabled = await _storage.read(_keyBiometricsEnabled);
    return enabled == 'true';
  }

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setPasscode(String passcode) async {
    final salt = HashUtils.generateSalt();
    final verifier = HashUtils.hashPassword(passcode, salt);

    await _storage.write(_keyPasscodeSalt, salt);
    await _storage.write(_keyPasscodeVerifier, verifier);
    resetFailedAttempts();
  }

  @override
  Future<bool> verifyPasscode(String candidate) async {
    if (isLockedOut()) {
      return false;
    }

    final salt = await _storage.read(_keyPasscodeSalt);
    final storedVerifier = await _storage.read(_keyPasscodeVerifier);

    if (salt == null || storedVerifier == null) {
      return false;
    }

    final candidateVerifier = HashUtils.hashPassword(candidate, salt);
    final isValid = candidateVerifier == storedVerifier;

    if (isValid) {
      unlockApp();
    } else {
      _failedPasscodeAttempts += 1;
      if (_failedPasscodeAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
      }
    }
    return isValid;
  }


  @override
  Future<bool> authenticateWithBiometrics({
    String reason = 'Unlock ourPlace to access your private conversations',
  }) async {
    final isConfigured = await isPasscodeConfigured();
    if (!isConfigured) return false;

    final isEnabled = await isBiometricsEnabled();
    if (!isEnabled) return false;

    final isAvailable = await isBiometricsAvailable();
    if (!isAvailable) return false;

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        unlockApp();
      }
      return didAuthenticate;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(_keyBiometricsEnabled, enabled ? 'true' : 'false');
  }

  @override
  Future<void> clearPasscode() async {
    await _storage.delete(_keyPasscodeVerifier);
    await _storage.delete(_keyPasscodeSalt);
    await _storage.delete(_keyBiometricsEnabled);
    resetFailedAttempts();
    lockApp();
  }

}
