import 'dart:typed_data';
import 'package:chatbox/core/config/app_environment.dart';
import 'package:chatbox/services/firebase_media_relay_service.dart';

/// Abstract service contract for temporary ephemeral cloud media relay (Phase 15 — Media Messaging)
abstract class MediaRelayService {
  /// Upload an encrypted media ciphertext blob to temporary cloud storage
  ///
  /// Returns the access URL or cloud blob identifier
  Future<String> uploadEncryptedBlob(
    String blobId,
    List<int> ciphertextBytes, {
    Duration ttl = const Duration(hours: 24),
  });

  /// Download an encrypted media ciphertext blob from temporary cloud storage
  Future<Uint8List> downloadEncryptedBlob(String blobIdOrUrl);

  /// Permanently delete an encrypted media blob from cloud storage (delivery ACK protocol)
  Future<bool> purgeEncryptedBlob(String blobIdOrUrl);

  /// Garbage-collect all blobs that have exceeded their TTL (24-hour rule)
  Future<int> purgeExpiredBlobs();

  /// Check whether an encrypted blob currently exists in the ephemeral relay
  Future<bool> hasBlob(String blobIdOrUrl);
}

class _RelayBlobEntry {
  final String id;
  final Uint8List data;
  final DateTime createdAt;
  final Duration ttl;

  _RelayBlobEntry({
    required this.id,
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));
}

/// Production-ready In-Memory / Test implementation of [MediaRelayService]
class InMemoryMediaRelayService implements MediaRelayService {
  final Map<String, _RelayBlobEntry> _blobs = {};

  @override
  Future<String> uploadEncryptedBlob(
    String blobId,
    List<int> ciphertextBytes, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final entry = _RelayBlobEntry(
      id: blobId,
      data: Uint8List.fromList(ciphertextBytes),
      createdAt: DateTime.now(),
      ttl: ttl,
    );
    _blobs[blobId] = entry;
    return 'relay://ephemeral-media/$blobId';
  }

  @override
  Future<Uint8List> downloadEncryptedBlob(String blobIdOrUrl) async {
    final cleanId = _normalizeBlobId(blobIdOrUrl);
    final entry = _blobs[cleanId];
    if (entry == null) {
      throw Exception('Encrypted media blob not found or already purged: $blobIdOrUrl');
    }
    if (entry.isExpired) {
      _blobs.remove(cleanId);
      throw Exception('Encrypted media blob has expired (TTL exceeded): $blobIdOrUrl');
    }
    return entry.data;
  }

  @override
  Future<bool> purgeEncryptedBlob(String blobIdOrUrl) async {
    final cleanId = _normalizeBlobId(blobIdOrUrl);
    return _blobs.remove(cleanId) != null;
  }

  @override
  Future<int> purgeExpiredBlobs() async {
    final expiredKeys = _blobs.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _blobs.remove(key);
    }
    return expiredKeys.length;
  }

  @override
  Future<bool> hasBlob(String blobIdOrUrl) async {
    final cleanId = _normalizeBlobId(blobIdOrUrl);
    final entry = _blobs[cleanId];
    if (entry == null) return false;
    if (entry.isExpired) {
      _blobs.remove(cleanId);
      return false;
    }
    return true;
  }

  String _normalizeBlobId(String blobIdOrUrl) {
    if (blobIdOrUrl.startsWith('relay://ephemeral-media/')) {
      return blobIdOrUrl.replaceFirst('relay://ephemeral-media/', '');
    }
    return blobIdOrUrl;
  }

  int get totalBlobCount => _blobs.length;
  void clear() => _blobs.clear();
}

/// Factory relay service that selects [FirebaseMediaRelayService] in production
/// and [InMemoryMediaRelayService] in test mode.
class DefaultMediaRelayService implements MediaRelayService {
  static final DefaultMediaRelayService _instance = DefaultMediaRelayService._internal();
  factory DefaultMediaRelayService() => _instance;
  DefaultMediaRelayService._internal();

  MediaRelayService? _delegate;

  MediaRelayService get delegate {
    if (_delegate != null) return _delegate!;
    if (AppEnvironment.isProduction) {
      _delegate = FirebaseMediaRelayService();
    } else {
      _delegate = InMemoryMediaRelayService();
    }
    return _delegate!;
  }

  @override
  Future<String> uploadEncryptedBlob(
    String blobId,
    List<int> ciphertextBytes, {
    Duration ttl = const Duration(hours: 24),
  }) =>
      delegate.uploadEncryptedBlob(blobId, ciphertextBytes, ttl: ttl);

  @override
  Future<Uint8List> downloadEncryptedBlob(String blobIdOrUrl) =>
      delegate.downloadEncryptedBlob(blobIdOrUrl);

  @override
  Future<bool> purgeEncryptedBlob(String blobIdOrUrl) =>
      delegate.purgeEncryptedBlob(blobIdOrUrl);

  @override
  Future<int> purgeExpiredBlobs() => delegate.purgeExpiredBlobs();

  @override
  Future<bool> hasBlob(String blobIdOrUrl) => delegate.hasBlob(blobIdOrUrl);
}

