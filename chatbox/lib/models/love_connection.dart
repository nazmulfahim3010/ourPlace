import 'dart:convert';

/// Status of the 1-to-1 Love Connection between two users (Phase 16)
enum LoveConnectionStatus {
  none,
  requestSent,
  requestReceived,
  connected,
  disconnected,
}

extension LoveConnectionStatusExtension on LoveConnectionStatus {
  String toDbString() {
    switch (this) {
      case LoveConnectionStatus.none:
        return 'none';
      case LoveConnectionStatus.requestSent:
        return 'request_sent';
      case LoveConnectionStatus.requestReceived:
        return 'request_received';
      case LoveConnectionStatus.connected:
        return 'connected';
      case LoveConnectionStatus.disconnected:
        return 'disconnected';
    }
  }

  static LoveConnectionStatus fromDbString(String value) {
    switch (value) {
      case 'request_sent':
        return LoveConnectionStatus.requestSent;
      case 'request_received':
        return LoveConnectionStatus.requestReceived;
      case 'connected':
        return LoveConnectionStatus.connected;
      case 'disconnected':
        return LoveConnectionStatus.disconnected;
      case 'none':
      default:
        return LoveConnectionStatus.none;
    }
  }
}

/// Domain model representing the mutually accepted 1-to-1 couple connection (Phase 16).
///
/// Invariant: A user may have at most ONE active Love Connection at any time.
class LoveConnection {
  final String id;
  final String userId;
  final String partnerUsername;
  final String? partnerUserId;
  final String? partnerPublicKey;
  final LoveConnectionStatus status;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? disconnectedAt;
  final bool isVisibleOnProfile;

  const LoveConnection({
    required this.id,
    required this.userId,
    required this.partnerUsername,
    this.partnerUserId,
    this.partnerPublicKey,
    required this.status,
    required this.createdAt,
    this.connectedAt,
    this.disconnectedAt,
    this.isVisibleOnProfile = true,
  });

  bool get isConnected => status == LoveConnectionStatus.connected;
  bool get isPendingSent => status == LoveConnectionStatus.requestSent;
  bool get isPendingReceived => status == LoveConnectionStatus.requestReceived;
  bool get isPending => isPendingSent || isPendingReceived;
  bool get canSendRequest =>
      status == LoveConnectionStatus.none ||
      status == LoveConnectionStatus.disconnected;
  bool get canAccept => status == LoveConnectionStatus.requestReceived;

  LoveConnection copyWith({
    String? id,
    String? userId,
    String? partnerUsername,
    String? partnerUserId,
    String? partnerPublicKey,
    LoveConnectionStatus? status,
    DateTime? createdAt,
    DateTime? connectedAt,
    DateTime? disconnectedAt,
    bool? isVisibleOnProfile,
  }) {
    return LoveConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      partnerUsername: partnerUsername ?? this.partnerUsername,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      partnerPublicKey: partnerPublicKey ?? this.partnerPublicKey,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      connectedAt: connectedAt ?? this.connectedAt,
      disconnectedAt: disconnectedAt ?? this.disconnectedAt,
      isVisibleOnProfile: isVisibleOnProfile ?? this.isVisibleOnProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'partnerUsername': partnerUsername,
      'partnerUserId': partnerUserId,
      'partnerPublicKey': partnerPublicKey,
      'status': status.toDbString(),
      'createdAt': createdAt.toIso8601String(),
      'connectedAt': connectedAt?.toIso8601String(),
      'disconnectedAt': disconnectedAt?.toIso8601String(),
      'isVisibleOnProfile': isVisibleOnProfile,
    };
  }

  factory LoveConnection.fromJson(Map<String, dynamic> json) {
    return LoveConnection(
      id: json['id'] as String,
      userId: json['userId'] as String,
      partnerUsername: json['partnerUsername'] as String,
      partnerUserId: json['partnerUserId'] as String?,
      partnerPublicKey: json['partnerPublicKey'] as String?,
      status: LoveConnectionStatusExtension.fromDbString(
        json['status'] as String? ?? 'none',
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'] as String)
          : null,
      disconnectedAt: json['disconnectedAt'] != null
          ? DateTime.parse(json['disconnectedAt'] as String)
          : null,
      isVisibleOnProfile: json['isVisibleOnProfile'] as bool? ?? true,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory LoveConnection.deserialize(String raw) =>
      LoveConnection.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  String toString() =>
      'LoveConnection(id: $id, partner: $partnerUsername, status: $status, connectedAt: $connectedAt)';
}
