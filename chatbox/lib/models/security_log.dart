/// Domain model representing a device-local security audit event
class SecurityLog {
  final String id;
  final String eventType;
  final String details;
  final String severity; // 'info' | 'warning' | 'critical'
  final DateTime timestamp;

  const SecurityLog({
    required this.id,
    required this.eventType,
    required this.details,
    required this.severity,
    required this.timestamp,
  });

  /// Formatted relative or time string for UI display
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventType': eventType,
        'details': details,
        'severity': severity,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SecurityLog.fromJson(Map<String, dynamic> json) => SecurityLog(
        id: json['id'] as String,
        eventType: json['eventType'] as String,
        details: json['details'] as String,
        severity: json['severity'] as String? ?? 'info',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
