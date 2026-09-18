import 'dart:async';
import 'package:chatbox/models/notification_settings.dart';

/// Abstract contract for privacy-first push notifications and wake-up signals (Phase 14)
abstract class NotificationService {
  Future<void> initialize();
  Future<String?> getDeviceToken();
  
  NotificationSettings get settings;
  Future<void> updateSettings(NotificationSettings newSettings);

  /// Backwards-compatible raw notification display
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  });

  /// Displays a privacy-preserving local notification banner after local decryption.
  /// When Discreet Mode is active, content and sender are replaced with generic text.
  Future<void> showLocalAlert({
    required String title,
    required String body,
    String? conversationId,
    bool? isDiscreet,
  });

  /// Processes a silent wake-up signal from FCM/APNs and triggers message synchronization.
  Future<void> handleSilentWakeup(
    PushWakeupSignal signal, {
    required Future<void> Function() onSync,
  });

  /// Buffers a conversation ID when the user taps a notification while the app is locked.
  void bufferPendingRoute(String conversationId);

  /// Consumes and clears any buffered pending conversation route after authentication.
  String? consumePendingRoute();

  /// Stream of conversation IDs emitted when notifications are tapped.
  Stream<String> get onNotificationTapped;
}

/// Default implementation of [NotificationService] enforcing Discreet Mode and zero telemetry.
class DefaultNotificationService implements NotificationService {
  static final DefaultNotificationService _instance =
      DefaultNotificationService._internal();
  factory DefaultNotificationService() => _instance;
  DefaultNotificationService._internal();

  NotificationSettings _settings = const NotificationSettings();
  String? _deviceToken = 'mock_fcm_token_ourplace';
  String? _pendingRoute;
  final StreamController<String> _tappedController =
      StreamController<String>.broadcast();

  /// Log of displayed alerts (useful for automated testing and verification)
  final List<Map<String, dynamic>> displayedAlerts = [];

  @override
  NotificationSettings get settings => _settings;

  @override
  Future<void> initialize() async {
    // Ready for FCM / local notifications integration
  }

  @override
  Future<String?> getDeviceToken() async => _deviceToken;

  /// Sets a custom mock token (useful for multi-device simulation and testing)
  void setMockDeviceToken(String? token) {
    _deviceToken = token;
  }

  @override
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showLocalAlert(
      title: title,
      body: body,
      conversationId: payload,
    );
  }

  @override
  Future<void> showLocalAlert({
    required String title,
    required String body,
    String? conversationId,
    bool? isDiscreet,
  }) async {
    if (!_settings.enabled) return;

    final discreet = isDiscreet ?? _settings.hidePreviewOnLockScreen;
    final displayTitle = discreet ? 'ourPlace' : title;
    final displayBody = discreet ? 'New private message received' : body;

    displayedAlerts.add({
      'title': displayTitle,
      'body': displayBody,
      'conversationId': conversationId,
      'isDiscreet': discreet,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> handleSilentWakeup(
    PushWakeupSignal signal, {
    required Future<void> Function() onSync,
  }) async {
    if (!_settings.enabled) return;
    await onSync();
  }

  @override
  void bufferPendingRoute(String conversationId) {
    _pendingRoute = conversationId;
  }

  @override
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  @override
  Stream<String> get onNotificationTapped => _tappedController.stream;

  /// Simulates a user tapping a notification banner
  void simulateNotificationTap(String conversationId) {
    bufferPendingRoute(conversationId);
    _tappedController.add(conversationId);
  }

  /// Clears in-memory test logs and resets default settings
  void clearLogs() {
    displayedAlerts.clear();
    _pendingRoute = null;
    _settings = const NotificationSettings();
  }

  void dispose() {
    _tappedController.close();
  }
}

/// Backwards-compatible alias for existing service usage
class LocalNotificationService extends DefaultNotificationService {
  static final LocalNotificationService _subInstance =
      LocalNotificationService._();
  factory LocalNotificationService() => _subInstance;
  LocalNotificationService._() : super._internal();
}
