import 'dart:async';
import 'package:chatbox/core/config/app_environment.dart';
import 'package:chatbox/models/notification_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart' hide NotificationSettings;
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Silent data-only push wake-up signal: the background message triggers
  // local reconciliation when the user returns or via background sync.
}

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

  /// Stream of local alerts emitted when notifications are displayed.
  Stream<Map<String, dynamic>> get onNotificationDisplayed;

  /// Simulates or dispatches a notification tap event.
  void simulateNotificationTap(String conversationId);
}

/// Default implementation of [NotificationService] enforcing Discreet Mode and zero telemetry.
class DefaultNotificationService implements NotificationService {
  static final DefaultNotificationService _instance =
      DefaultNotificationService._internal();
  factory DefaultNotificationService() => _instance;
  DefaultNotificationService._internal();

  NotificationSettings _settings = const NotificationSettings();
  String? _deviceToken = 'mock_fcm_token_nest';
  String? _pendingRoute;
  final StreamController<String> _tappedController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _displayedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Log of displayed alerts (useful for automated testing and verification)
  final List<Map<String, dynamic>> displayedAlerts = [];

  @override
  Stream<Map<String, dynamic>> get onNotificationDisplayed =>
      _displayedController.stream;

  @override
  NotificationSettings get settings => _settings;

  @override
  Future<void> initialize() async {
    if (AppEnvironment.isProduction) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final token = await messaging.getToken();
        if (token != null) {
          _deviceToken = token;
        }
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.data['type'] == 'wakeup') {
            final sender = message.data['senderId'] as String? ?? 'Partner';
            showLocalAlert(
              title: 'New Message',
              body: 'Encrypted message from $sender',
              conversationId: sender,
            );
          }
        });
      } catch (e) {
        debugPrint('DefaultNotificationService: initialize error: $e');
      }
    }
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
    final displayTitle = discreet ? 'Nest' : title;
    final displayBody = discreet ? 'New private message received' : body;

    final alertData = {
      'title': displayTitle,
      'body': displayBody,
      'conversationId': conversationId,
      'isDiscreet': discreet,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    displayedAlerts.add(alertData);
    if (!_displayedController.isClosed) {
      _displayedController.add(alertData);
    }
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
  @override
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
    _displayedController.close();
  }
}

/// Backwards-compatible alias for existing service usage
class LocalNotificationService extends DefaultNotificationService {
  static final LocalNotificationService _subInstance =
      LocalNotificationService._();
  factory LocalNotificationService() => _subInstance;
  LocalNotificationService._() : super._internal();
}
