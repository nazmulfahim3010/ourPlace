import 'dart:convert';
import 'dart:typed_data';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/crypto_key_utils.dart';
import 'package:chatbox/models/media_attachment.dart';
import 'package:chatbox/models/message.dart';
import 'package:cryptography/cryptography.dart';

/// Encapsulates the encrypted binary blob alongside its descriptor metadata
class EncryptedMediaPackage {
  final Uint8List encryptedBytes;
  final MediaAttachment attachment;

  const EncryptedMediaPackage({
    required this.encryptedBytes,
    required this.attachment,
  });
}

/// Service contract for client-side media encryption and decryption (Phase 15 — Media Messaging)
abstract class MediaEncryptionService {
  /// Encrypt a raw media file using an ephemeral AES-256-GCM symmetric key,
  /// wrap the symmetric key with the recipient's public identity key, and produce
  /// an [EncryptedMediaPackage].
  Future<EncryptedMediaPackage> encryptMedia({
    required List<int> rawBytes,
    required String recipientPublicKey,
    required SimpleKeyPair localKeyPair,
    required String localPublicKeyBase64,
    required String fileName,
    required MessageType type,
    String? mimeType,
    int? durationMs,
    int? width,
    int? height,
    String? thumbnailBase64,
  });

  /// Decrypt an encrypted media ciphertext blob using the wrapped media key
  /// and the recipient's private identity key.
  Future<Uint8List> decryptMedia({
    required List<int> ciphertextBytes,
    required MediaAttachment attachment,
    required String senderPublicKey,
    required SimpleKeyPair localKeyPair,
  });
}

/// Production implementation of [MediaEncryptionService] using AES-256-GCM and X25519 ECDH
class StandardMediaEncryptionService implements MediaEncryptionService {
  static final List<int> _wrapInfo = utf8.encode('nest-media-key-wrap-v1');

  @override
  Future<EncryptedMediaPackage> encryptMedia({
    required List<int> rawBytes,
    required String recipientPublicKey,
    required SimpleKeyPair localKeyPair,
    required String localPublicKeyBase64,
    required String fileName,
    required MessageType type,
    String? mimeType,
    int? durationMs,
    int? width,
    int? height,
    String? thumbnailBase64,
  }) async {
    if (recipientPublicKey.isEmpty) {
      throw const SecurityException(
        'Recipient public identity key is missing for media encryption',
        code: 'MISSING_RECIPIENT_KEY',
      );
    }

    // 1. Generate ephemeral 256-bit AES-GCM symmetric media key
    final mediaKey = await CryptoKeyUtils.generateSymmetricKey();
    final rawMediaKeyBytes = await CryptoKeyUtils.extractSecretKeyBytes(mediaKey);

    // 2. Encrypt the raw binary file with AES-256-GCM
    final secretBox = await CryptoKeyUtils.encryptAesGcmBytes(
      bytes: rawBytes,
      secretKey: mediaKey,
    );

    // 3. Compute ECDH shared secret with recipient
    final remotePub = CryptoKeyUtils.decodePublicKey(recipientPublicKey);
    final sharedSecret = await CryptoKeyUtils.computeSharedSecret(
      localKeyPair: localKeyPair,
      remotePublicKey: remotePub,
    );

    // 4. Derive key wrapping key
    final wrapKey = await CryptoKeyUtils.deriveMessageKey(
      sharedSecret: sharedSecret,
      info: _wrapInfo,
    );

    // 5. Encrypt (wrap) the symmetric media key bytes
    final wrappedKeyBox = await CryptoKeyUtils.encryptAesGcmBytes(
      bytes: rawMediaKeyBytes,
      secretKey: wrapKey,
    );

    // Encode wrapped key as JSON containing its ciphertext, nonce, and MAC
    final wrappedKeyJson = jsonEncode({
      'ct': base64Encode(wrappedKeyBox.cipherText),
      'iv': base64Encode(wrappedKeyBox.nonce),
      'mac': base64Encode(wrappedKeyBox.mac.bytes),
    });

    final attachmentId = 'media_${DateTime.now().millisecondsSinceEpoch}';
    final attachment = MediaAttachment(
      id: attachmentId,
      type: type,
      fileName: fileName,
      mimeType: mimeType ?? _inferMimeType(fileName, type),
      fileSizeBytes: rawBytes.length,
      encryptedMediaKey: base64Encode(utf8.encode(wrappedKeyJson)),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
      durationMs: durationMs,
      width: width,
      height: height,
      thumbnailBase64: thumbnailBase64,
    );

    return EncryptedMediaPackage(
      encryptedBytes: Uint8List.fromList(secretBox.cipherText),
      attachment: attachment,
    );
  }

  @override
  Future<Uint8List> decryptMedia({
    required List<int> ciphertextBytes,
    required MediaAttachment attachment,
    required String senderPublicKey,
    required SimpleKeyPair localKeyPair,
  }) async {
    if (senderPublicKey.isEmpty) {
      throw const SecurityException(
        'Sender public identity key is missing for media decryption',
        code: 'MISSING_SENDER_KEY',
      );
    }
    if (attachment.encryptedMediaKey == null ||
        attachment.nonce == null ||
        attachment.mac == null) {
      throw const SecurityException(
        'Incomplete media encryption metadata',
        code: 'INVALID_MEDIA_METADATA',
      );
    }

    // 1. Compute ECDH shared secret with sender
    final remotePub = CryptoKeyUtils.decodePublicKey(senderPublicKey);
    final sharedSecret = await CryptoKeyUtils.computeSharedSecret(
      localKeyPair: localKeyPair,
      remotePublicKey: remotePub,
    );

    // 2. Derive key wrapping key
    final wrapKey = await CryptoKeyUtils.deriveMessageKey(
      sharedSecret: sharedSecret,
      info: _wrapInfo,
    );

    // 3. Unwrap symmetric media key
    final wrappedJsonStr = utf8.decode(base64Decode(attachment.encryptedMediaKey!));
    final wrappedMap = jsonDecode(wrappedJsonStr) as Map<String, dynamic>;
    final wrapCt = base64Decode(wrappedMap['ct'] as String);
    final wrapIv = base64Decode(wrappedMap['iv'] as String);
    final wrapMac = base64Decode(wrappedMap['mac'] as String);

    final unwrappedKeyBytes = await CryptoKeyUtils.decryptAesGcmBytes(
      ciphertext: wrapCt,
      nonce: wrapIv,
      mac: wrapMac,
      secretKey: wrapKey,
    );

    final mediaKey = CryptoKeyUtils.secretKeyFromBytes(unwrappedKeyBytes);

    // 4. Decrypt binary media bytes using unwrapped media key
    final mediaIv = base64Decode(attachment.nonce!);
    final mediaMac = base64Decode(attachment.mac!);

    final decryptedBytes = await CryptoKeyUtils.decryptAesGcmBytes(
      ciphertext: ciphertextBytes,
      nonce: mediaIv,
      mac: mediaMac,
      secretKey: mediaKey,
    );

    return Uint8List.fromList(decryptedBytes);
  }

  String _inferMimeType(String fileName, MessageType type) {
    switch (type) {
      case MessageType.image:
        if (fileName.toLowerCase().endsWith('.png')) return 'image/png';
        return 'image/jpeg';
      case MessageType.audio:
        return 'audio/m4a';
      case MessageType.video:
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
