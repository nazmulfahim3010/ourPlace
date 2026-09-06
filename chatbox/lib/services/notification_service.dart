/// Abstract contract for push notifications (Phase 12 - Push Notifications)
abstract class NotificationService {
  Future<void> initialize();
  Future<String?> getDeviceToken();
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  });
}

/// Initial stub implementation for NotificationService
class LocalNotificationService implements NotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getDeviceToken() async => 'mock_device_token';

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {}
}
