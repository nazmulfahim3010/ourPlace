import 'dart:convert';
import 'package:chatbox/models/message.dart';

/// Domain model representing an encrypted/decrypted media attachment (Phase 15 — Media Messaging)
class MediaAttachment {
  /// Unique identifier for this media attachment
  final String id;

  /// Media attachment type (image, audio, video)
  final MessageType type;

  /// Human-readable file name
  final String fileName;

  /// MIME type string (e.g., 'image/jpeg', 'audio/m4a', 'video/mp4')
  final String mimeType;

  /// Payload size in bytes
  final int fileSizeBytes;

  /// Local path within application private sandbox (if downloaded/cached)
  final String? localPath;

  /// Ephemeral cloud storage URL or blob reference
  final String? remoteUrl;

  /// Base64 encoded wrapped 256-bit AES-GCM media key
  final String? encryptedMediaKey;

  /// Base64 encoded 12-byte initialization vector (nonce)
  final String? nonce;

  /// Base64 encoded 16-byte AEAD authentication tag (MAC)
  final String? mac;

  /// Duration in milliseconds for audio or video recordings
  final int? durationMs;

  /// Visual media pixel width
  final int? width;

  /// Visual media pixel height
  final int? height;

  /// Lightweight base64 encoded preview thumbnail
  final String? thumbnailBase64;

  const MediaAttachment({
    required this.id,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.localPath,
    this.remoteUrl,
    this.encryptedMediaKey,
    this.nonce,
    this.mac,
    this.durationMs,
    this.width,
    this.height,
    this.thumbnailBase64,
  });

  /// Convenience getters
  bool get isImage => type == MessageType.image;
  bool get isAudio => type == MessageType.audio;
  bool get isVideo => type == MessageType.video;

  /// Human-readable formatted file size
  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Formatted duration for audio/video (e.g. 0:05, 1:42)
  String get formattedDuration {
    if (durationMs == null || durationMs! <= 0) return '0:00';
    final totalSeconds = (durationMs! / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      if (localPath != null) 'localPath': localPath,
      if (remoteUrl != null) 'remoteUrl': remoteUrl,
      if (encryptedMediaKey != null) 'encryptedMediaKey': encryptedMediaKey,
      if (nonce != null) 'nonce': nonce,
      if (mac != null) 'mac': mac,
      if (durationMs != null) 'durationMs': durationMs,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (thumbnailBase64 != null) 'thumbnailBase64': thumbnailBase64,
    };
  }

  /// Serialize to JSON string for SQLite persistence
  String toJsonString() => jsonEncode(toJson());

  /// Construct from JSON map
  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'] || e.toString().split('.').last == json['type'],
        orElse: () => MessageType.image,
      ),
      fileName: json['fileName'] as String? ?? 'attachment',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      encryptedMediaKey: json['encryptedMediaKey'] as String?,
      nonce: json['nonce'] as String?,
      mac: json['mac'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      thumbnailBase64: json['thumbnailBase64'] as String?,
    );
  }

  /// Deserialize from JSON string
  factory MediaAttachment.fromJsonString(String jsonString) {
    return MediaAttachment.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Copy with modifications
  MediaAttachment copyWith({
    String? id,
    MessageType? type,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? localPath,
    String? remoteUrl,
    String? encryptedMediaKey,
    String? nonce,
    String? mac,
    int? durationMs,
    int? width,
    int? height,
    String? thumbnailBase64,
  }) {
    return MediaAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      encryptedMediaKey: encryptedMediaKey ?? this.encryptedMediaKey,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAttachment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          fileName == other.fileName &&
          mimeType == other.mimeType &&
          fileSizeBytes == other.fileSizeBytes &&
          localPath == other.localPath &&
          remoteUrl == other.remoteUrl &&
          encryptedMediaKey == other.encryptedMediaKey &&
          nonce == other.nonce &&
          mac == other.mac &&
          durationMs == other.durationMs &&
          width == other.width &&
          height == other.height &&
          thumbnailBase64 == other.thumbnailBase64;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      fileName.hashCode ^
      mimeType.hashCode ^
      fileSizeBytes.hashCode ^
      localPath.hashCode ^
      remoteUrl.hashCode ^
      encryptedMediaKey.hashCode ^
      nonce.hashCode ^
      mac.hashCode ^
      durationMs.hashCode ^
      width.hashCode ^
      height.hashCode ^
      thumbnailBase64.hashCode;

  @override
  String toString() {
    return 'MediaAttachment(id: $id, type: $type, fileName: $fileName, '
        'size: $formattedFileSize, localPath: $localPath, remoteUrl: $remoteUrl)';
  }
}
