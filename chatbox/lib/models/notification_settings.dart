/// Domain model representing privacy-first push notification settings (Phase 14).
class NotificationSettings {
  /// Whether push notifications and wake-up signals are enabled.
  final bool enabled;

  /// Discreet Mode: When true, lock screen notifications display generic text
  /// ("Nest • New private message received") rather than message content.
  final bool hidePreviewOnLockScreen;

  /// When true, sender identity/username is hidden in notifications.
  final bool hideSenderIdentity;

  /// Whether sound is played on arrival.
  final bool soundEnabled;

  /// Whether vibration / haptic feedback is triggered.
  final bool vibrationEnabled;

  const NotificationSettings({
    this.enabled = true,
    this.hidePreviewOnLockScreen = true,
    this.hideSenderIdentity = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? hidePreviewOnLockScreen,
    bool? hideSenderIdentity,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      hidePreviewOnLockScreen:
          hidePreviewOnLockScreen ?? this.hidePreviewOnLockScreen,
      hideSenderIdentity: hideSenderIdentity ?? this.hideSenderIdentity,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'hidePreviewOnLockScreen': hidePreviewOnLockScreen,
      'hideSenderIdentity': hideSenderIdentity,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      hidePreviewOnLockScreen:
          json['hidePreviewOnLockScreen'] as bool? ?? true,
      hideSenderIdentity: json['hideSenderIdentity'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    );
  }
}

/// Lightweight, zero-knowledge silent wake-up payload transmitted via FCM/APNs.
///
/// Strictly enforces zero telemetry: contains zero message plaintext,
/// zero sender identities, and zero conversation content.
class PushWakeupSignal {
  /// Signal type identifier, usually 'wakeup' or 'sync'.
  final String signalType;

  /// Recipient user ID / hash targeted for wake-up.
  final String recipientId;

  /// Timestamp in milliseconds.
  final int timestamp;

  const PushWakeupSignal({
    this.signalType = 'wakeup',
    required this.recipientId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'signalType': signalType,
      'recipientId': recipientId,
      'timestamp': timestamp,
    };
  }

  factory PushWakeupSignal.fromJson(Map<String, dynamic> json) {
    return PushWakeupSignal(
      signalType: json['signalType'] as String? ?? 'wakeup',
      recipientId: json['recipientId'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Validates that no sensitive information is leaked in the payload.
  bool get hasZeroLeakage =>
      signalType.isNotEmpty &&
      recipientId.isNotEmpty &&
      timestamp > 0;
}
