/// Abstract service contract for end-to-end encryption (Phase 8 - E2EE)
abstract class EncryptionService {
  Future<String> encryptPayload(String plaintext, String recipientPublicKey);
  Future<String> decryptPayload(String ciphertext, String senderPublicKey);
  Future<String> getPublicIdentityKey();
}

/// Pass-through implementation prior to Phase 8 cryptographic key exchange
class NoOpEncryptionService implements EncryptionService {
  static final NoOpEncryptionService _instance =
      NoOpEncryptionService._internal();
  factory NoOpEncryptionService() => _instance;
  NoOpEncryptionService._internal();

  @override
  Future<String> encryptPayload(
    String plaintext,
    String recipientPublicKey,
  ) async {
    // Plaintext pass-through until Phase 8 cryptographic layer
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
}
