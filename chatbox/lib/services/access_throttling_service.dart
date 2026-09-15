import 'package:chatbox/core/utils/hash_utils.dart';


/// Throttling state for a single identity (username or device lock)
class ThrottleEntry {
  int failedAttempts;
  DateTime? lockoutUntil;
  DateTime lastAttemptTime;

  ThrottleEntry({
    this.failedAttempts = 0,
    this.lockoutUntil,
    DateTime? lastAttemptTime,
  }) : lastAttemptTime = lastAttemptTime ?? DateTime.now();

  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  Duration get remainingCooldown {
    if (lockoutUntil == null) return Duration.zero;
    final remaining = lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Service managing rate limiting and exponential backoff for account logins and access security
class AccessThrottlingService {
  static final AccessThrottlingService _instance = AccessThrottlingService._internal();
  factory AccessThrottlingService() => _instance;
  AccessThrottlingService._internal();

  final Map<String, ThrottleEntry> _loginEntries = {};

  /// Determine lockout duration based on consecutive failed attempts
  Duration calculateCooldown(int failedAttempts) {
    if (failedAttempts < 3) return Duration.zero;
    if (failedAttempts < 5) return const Duration(seconds: 10);
    if (failedAttempts < 8) return const Duration(seconds: 30);
    if (failedAttempts < 10) return const Duration(minutes: 2);
    return const Duration(minutes: 5);
  }

  /// Check if login attempt is allowed for given username
  bool canAttemptLogin(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    final entry = _loginEntries[normalized];
    if (entry == null) return true;
    return !entry.isLockedOut;
  }

  /// Get remaining cooldown duration for username
  Duration getRemainingCooldown(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    final entry = _loginEntries[normalized];
    if (entry == null) return Duration.zero;
    return entry.remainingCooldown;
  }

  /// Get count of failed attempts for username
  int getFailedAttempts(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    return _loginEntries[normalized]?.failedAttempts ?? 0;
  }

  /// Record a failed login attempt and apply backoff cooldown if threshold reached
  ThrottleEntry recordFailedLogin(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    final entry = _loginEntries.putIfAbsent(normalized, () => ThrottleEntry());
    entry.failedAttempts += 1;
    entry.lastAttemptTime = DateTime.now();

    final cooldown = calculateCooldown(entry.failedAttempts);
    if (cooldown > Duration.zero) {
      entry.lockoutUntil = DateTime.now().add(cooldown);
    }

    return entry;
  }

  /// Record a successful login and clear failed attempts
  void recordSuccessfulLogin(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    _loginEntries.remove(normalized);
  }

  /// Explicitly reset throttling (e.g., during tests or after recovery)
  void reset(String username) {
    final normalized = HashUtils.normalizeUsername(username);
    _loginEntries.remove(normalized);
  }

  /// Clear all entries
  void clearAll() {
    _loginEntries.clear();
  }
}
