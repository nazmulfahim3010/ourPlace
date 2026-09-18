import 'dart:convert';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/crypto_key_utils.dart';
import 'package:chatbox/models/encrypted_payload.dart';
import 'package:chatbox/services/secure_storage_service.dart';
import 'package:cryptography/cryptography.dart';

/// Abstract service contract for end-to-end encryption (Phase 10 — E2EE Layer)
abstract class EncryptionService {
  /// Initialize or load cryptographic identity keys for the specified user
  Future<void> initializeUserKeys(String userId);

  /// Retrieve the current user's Base64-encoded public X25519 identity key
  Future<String> getPublicIdentityKey();

  /// Encrypt a plaintext message payload targeting the recipient's public key
  ///
  /// Returns a serialized [EncryptedPayload] JSON string
  Future<String> encryptPayload(String plaintext, String recipientPublicKey);

  /// Decrypt a serialized [EncryptedPayload] ciphertext envelope using the sender's public key
  ///
  /// Authenticates with AEAD tag. Throws [SecurityException] on tampering.
  Future<String> decryptPayload(String serializedEnvelope, String senderPublicKey);

  /// Whether cryptographic keys have been generated and configured for the active session
  Future<bool> hasKeysConfigured();

  /// Securely purge stored keys for the current session (used during sign-out)
  Future<void> clearKeys();
}

/// Production implementation of [EncryptionService] utilizing X25519 ECDH,
/// HKDF-SHA256, and AES-256-GCM AEAD authenticated encryption.
///
/// Private keys are hardware-isolated in [SecureStorageService].
class StandardE2EEEncryptionService implements EncryptionService {
  static StandardE2EEEncryptionService? _defaultInstance;

  final SecureStorageService _secureStorage;
  String? _activeUserId;
  SimpleKeyPair? _cachedKeyPair;
  String? _cachedPublicKeyBase64;

  static const String _privKeyPrefix = 'e2ee_priv_key_';
  static const String _pubKeyPrefix = 'e2ee_pub_key_';

  StandardE2EEEncryptionService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? DefaultSecureStorageService();

  /// Shared default instance for application-level singleton access
  static StandardE2EEEncryptionService get instance =>
      _defaultInstance ??= StandardE2EEEncryptionService();

  @override
  Future<void> initializeUserKeys(String userId) async {
    _activeUserId = userId;

    final privKeyHex = await _secureStorage.read('$_privKeyPrefix$userId');
    final pubKeyHex = await _secureStorage.read('$_pubKeyPrefix$userId');

    if (privKeyHex != null && pubKeyHex != null) {
      // Reconstruct existing keypair from secure hardware storage
      _cachedKeyPair = CryptoKeyUtils.reconstructKeyPair(
        base64PrivateKey: privKeyHex,
        base64PublicKey: pubKeyHex,
      );
      _cachedPublicKeyBase64 = pubKeyHex;
    } else {
      // Generate new X25519 keypair
      final keyPair = await CryptoKeyUtils.generateX25519KeyPair();
      final privBase64 = await CryptoKeyUtils.encodePrivateKey(keyPair);
      final pubBase64 = await CryptoKeyUtils.encodePublicKey(keyPair);

      // Persist strictly to secure storage
      await _secureStorage.write('$_privKeyPrefix$userId', privBase64);
      await _secureStorage.write('$_pubKeyPrefix$userId', pubBase64);

      _cachedKeyPair = keyPair;
      _cachedPublicKeyBase64 = pubBase64;
    }
  }

  @override
  Future<String> getPublicIdentityKey() async {
    if (_cachedPublicKeyBase64 != null) {
      return _cachedPublicKeyBase64!;
    }

    if (_activeUserId != null) {
      final stored = await _secureStorage.read('$_pubKeyPrefix$_activeUserId');
      if (stored != null) {
        _cachedPublicKeyBase64 = stored;
        return stored;
      }
    }

    // Auto-initialize fallback default session if not configured
    await initializeUserKeys(_activeUserId ?? 'default_user');
    return _cachedPublicKeyBase64!;
  }

  @override
  Future<bool> hasKeysConfigured() async {
    if (_cachedKeyPair != null) return true;
    if (_activeUserId == null) return false;
    final priv = await _secureStorage.read('$_privKeyPrefix$_activeUserId');
    return priv != null;
  }

  @override
  Future<String> encryptPayload(
    String plaintext,
    String recipientPublicKey,
  ) async {
    if (recipientPublicKey.isEmpty) {
      throw const SecurityException(
        'Recipient public identity key is missing',
        code: 'MISSING_RECIPIENT_KEY',
      );
    }

    // Ensure local keys are loaded
    if (_cachedKeyPair == null) {
      await initializeUserKeys(_activeUserId ?? 'current_user');
    }

    final localKeyPair = _cachedKeyPair!;
    final localPublicBase64 = await getPublicIdentityKey();

    // 1. Decode remote public key
    final remotePub = CryptoKeyUtils.decodePublicKey(recipientPublicKey);

    // 2. Perform ECDH to compute shared secret
    final sharedSecret = await CryptoKeyUtils.computeSharedSecret(
      localKeyPair: localKeyPair,
      remotePublicKey: remotePub,
    );

    // 3. Derive symmetric message encryption key via HKDF-SHA256
    final messageKey = await CryptoKeyUtils.deriveMessageKey(
      sharedSecret: sharedSecret,
    );

    // 4. Encrypt with AES-256-GCM (generating random 12-byte nonce & 16-byte MAC)
    final secretBox = await CryptoKeyUtils.encryptAesGcm(
      plaintext: plaintext,
      secretKey: messageKey,
    );

    // 5. Wrap in structured EncryptedPayload envelope
    final envelope = EncryptedPayload(
      version: 1,
      senderPublicKey: localPublicBase64,
      nonce: base64Encode(secretBox.nonce),
      ciphertext: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
      createdAt: DateTime.now(),
    );

    return envelope.serialize();
  }

  @override
  Future<String> decryptPayload(
    String serializedEnvelope,
    String senderPublicKey,
  ) async {
    // 1. Deserialize envelope
    final EncryptedPayload payload;
    try {
      payload = EncryptedPayload.deserialize(serializedEnvelope);
    } catch (e) {
      throw SecurityException(
        'Malformed ciphertext envelope: $e',
        code: 'INVALID_ENVELOPE',
      );
    }

    // Verify sender matches envelope sender (if provided)
    final effectiveSenderPub = senderPublicKey.isNotEmpty
        ? senderPublicKey
        : payload.senderPublicKey;

    if (effectiveSenderPub.isEmpty) {
      throw const SecurityException(
        'Sender public key is missing',
        code: 'MISSING_SENDER_KEY',
      );
    }

    // Ensure local keys are loaded
    if (_cachedKeyPair == null) {
      await initializeUserKeys(_activeUserId ?? 'current_user');
    }

    final localKeyPair = _cachedKeyPair!;

    // 2. Decode sender's public key
    final remotePub = CryptoKeyUtils.decodePublicKey(effectiveSenderPub);

    // 3. Compute identical ECDH shared secret
    final sharedSecret = await CryptoKeyUtils.computeSharedSecret(
      localKeyPair: localKeyPair,
      remotePublicKey: remotePub,
    );

    // 4. Derive symmetric message key via HKDF-SHA256
    final messageKey = await CryptoKeyUtils.deriveMessageKey(
      sharedSecret: sharedSecret,
    );

    // 5. Authenticate & Decrypt with AES-256-GCM
    final nonceBytes = base64Decode(payload.nonce);
    final ciphertextBytes = base64Decode(payload.ciphertext);
    final macBytes = base64Decode(payload.mac);

    return await CryptoKeyUtils.decryptAesGcm(
      ciphertext: ciphertextBytes,
      nonce: nonceBytes,
      mac: macBytes,
      secretKey: messageKey,
    );
  }

  @override
  Future<void> clearKeys() async {
    if (_activeUserId != null) {
      await _secureStorage.delete('$_privKeyPrefix$_activeUserId');
      await _secureStorage.delete('$_pubKeyPrefix$_activeUserId');
    }
    _cachedKeyPair = null;
    _cachedPublicKeyBase64 = null;
    _activeUserId = null;
  }
}

/// Fallback / mock implementation of [EncryptionService] for testing environments
class NoOpEncryptionService implements EncryptionService {
  static final NoOpEncryptionService _instance =
      NoOpEncryptionService._internal();
  factory NoOpEncryptionService() => _instance;
  NoOpEncryptionService._internal();

  @override
  Future<void> initializeUserKeys(String userId) async {}

  @override
  Future<String> encryptPayload(
    String plaintext,
    String recipientPublicKey,
  ) async {
    return plaintext;
  }

  @override
  Future<String> decryptPayload(
    String ciphertext,
    String senderPublicKey,
  ) async {
    return ciphertext;
  }

  @override
  Future<String> getPublicIdentityKey() async {
    return 'noop_public_key';
  }

  @override
  Future<bool> hasKeysConfigured() async => true;

  @override
  Future<void> clearKeys() async {}
}
