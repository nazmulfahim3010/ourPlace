import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/services/user_directory_service.dart';

/// Resolves a user's public X25519 identity key for encryption and sender
/// verification.
///
/// Sources, in order of trust:
/// 1. An account stored on this device
/// 2. The key pinned on the active Love Connection
/// 3. The remote user directory
///
/// A key embedded in an incoming ciphertext envelope is chosen by whoever
/// wrote the envelope, so it is deliberately never used as a source here.
class PublicKeyResolver {
  final LocalDatabase _database;
  final UserDirectoryService _directory;

  PublicKeyResolver({
    LocalDatabase? database,
    UserDirectoryService? directory,
  })  : _database = database ?? LocalDatabase(),
        _directory = directory ?? DefaultUserDirectoryService();

  Future<String?> resolve(String username) async {
    final normalized = HashUtils.normalizeUsername(username);

    try {
      final account = await _database.getAccountByUsername(normalized);
      final key = account?.publicIdentityKey;
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    try {
      final conn = await _database.getLoveConnection();
      final key = conn?.partnerPublicKey;
      if (conn != null &&
          key != null &&
          key.isNotEmpty &&
          HashUtils.normalizeUsername(conn.partnerUsername) == normalized) {
        return key;
      }
    } catch (_) {}

    try {
      final profile = await _directory.lookupProfile(normalized);
      final key = profile?.publicIdentityKey;
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    return null;
  }
}
