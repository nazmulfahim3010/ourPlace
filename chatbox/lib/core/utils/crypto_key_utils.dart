import 'dart:convert';
import 'dart:math';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:cryptography/cryptography.dart';

/// Low-level cryptographic primitives supporting End-to-End Encryption (Phase 10)
///
/// Uses established, standard cryptographic algorithms:
/// - X25519 (Diffie-Hellman Key Exchange)
/// - HKDF-SHA256 (Key Derivation Function)
/// - AES-256-GCM (Authenticated Encryption with Associated Data - AEAD)
class CryptoKeyUtils {
  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Key derivation info tag for ourPlace messaging protocol
  static final List<int> _hkdfInfo = utf8.encode('ourPlace-e2ee-message-v1');

  /// Generate a new random X25519 KeyPair
  static Future<SimpleKeyPair> generateX25519KeyPair() async {
    return await _x25519.newKeyPair();
  }

  /// Encode public key to Base64
  static Future<String> encodePublicKey(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// Encode raw public key bytes to Base64
  static String encodePublicKeyBytes(List<int> bytes) {
    return base64Encode(bytes);
  }

  /// Decode Base64 string into a SimplePublicKey (X25519)
  static SimplePublicKey decodePublicKey(String base64Key) {
    final bytes = base64Decode(base64Key);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Encode private key bytes to Base64 for secure hardware keystore storage
  static Future<String> encodePrivateKey(SimpleKeyPair keyPair) async {
    final priv = await keyPair.extractPrivateKeyBytes();
    return base64Encode(priv);
  }

  /// Reconstruct SimpleKeyPair from stored private key bytes and public key bytes
  static SimpleKeyPair reconstructKeyPair({
    required String base64PrivateKey,
    required String base64PublicKey,
  }) {
    final privBytes = base64Decode(base64PrivateKey);
    final pubBytes = base64Decode(base64PublicKey);

    return SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  /// Compute ECDH shared secret using local private key and remote public key
  static Future<SecretKey> computeSharedSecret({
    required SimpleKeyPair localKeyPair,
    required SimplePublicKey remotePublicKey,
  }) async {
    try {
      return await _x25519.sharedSecretKey(
        keyPair: localKeyPair,
        remotePublicKey: remotePublicKey,
      );
    } catch (e) {
      throw SecurityException(
        'Failed to compute ECDH shared secret: $e',
        code: 'ECDH_FAILED',
      );
    }
  }

  /// Derive 256-bit symmetric message key via HKDF-SHA256 from shared secret
  static Future<SecretKey> deriveMessageKey({
    required SecretKey sharedSecret,
    List<int>? salt,
    List<int>? info,
  }) async {
    try {
      return await _hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: salt ?? const [],
        info: info ?? _hkdfInfo,
      );
    } catch (e) {
      throw SecurityException(
        'Failed to derive symmetric message key: $e',
        code: 'HKDF_FAILED',
      );
    }
  }

  /// Generate a cryptographically secure 12-byte initialization vector (nonce)
  static List<int> generateNonce([int length = 12]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Encrypt plaintext with AES-256-GCM
  ///
  /// Returns a [SecretBox] containing cipherText bytes, nonce bytes, and MAC tag.
  static Future<SecretBox> encryptAesGcm({
    required String plaintext,
    required SecretKey secretKey,
    List<int>? nonce,
  }) async {
    try {
      final plaintextBytes = utf8.encode(plaintext);
      final iv = nonce ?? generateNonce(12);

      final secretBox = await _aesGcm.encrypt(
        plaintextBytes,
        secretKey: secretKey,
        nonce: iv,
      );

      return secretBox;
    } catch (e) {
      throw SecurityException(
        'AES-256-GCM encryption failed: $e',
        code: 'ENCRYPTION_FAILED',
      );
    }
  }

  /// Decrypt ciphertext with AES-256-GCM and verify MAC authentication tag
  ///
  /// Throws [SecurityException] if the MAC tag doesn't match (tampering detected).
  static Future<String> decryptAesGcm({
    required List<int> ciphertext,
    required List<int> nonce,
    required List<int> mac,
    required SecretKey secretKey,
  }) async {
    try {
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );

      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decryptedBytes);
    } on SecretBoxAuthenticationError catch (_) {
      throw const SecurityException(
        'Tamper detected: Message authentication tag (MAC) verification failed',
        code: 'INTEGRITY_COMPROMISED',
      );
    } catch (e) {
      throw SecurityException(
        'AES-256-GCM decryption failed: $e',
        code: 'DECRYPTION_FAILED',
      );
    }
  }
}
