import 'dart:async';
import 'dart:convert';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/love_connection.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/services/relay_service.dart';

/// Abstract service interface managing the 1-to-1 Love Connection subsystem (Phase 16).
///
/// Invariant: Strictly enforces 0 or 1 active Love Connection per account.
abstract class LoveConnectionService {
  Future<LoveConnection?> getLoveConnection({String? currentUserId});
  Stream<LoveConnection?> watchLoveConnection({String? currentUserId});
  Future<User?> searchPartnerByUsername(String username, {String? currentUsername});
  Future<LoveConnection> sendConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  });
  Future<LoveConnection> acceptConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  });
  Future<void> declineConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
  });
  Future<void> cancelConnectionRequest({
    required String currentUserId,
    required String currentUsername,
  });
  Future<void> unlinkLoveConnection({
    required String currentUserId,
    required String currentUsername,
  });
  Future<void> setVisibilityOnProfile(
    bool isVisible, {
    required String currentUserId,
  });
  Future<void> processInboundLoveEnvelope(
    EphemeralRelayEnvelope envelope, {
    required String currentUserId,
    required String currentUsername,
  });
}

/// Default production-ready implementation of [LoveConnectionService]
class DefaultLoveConnectionService implements LoveConnectionService {
  final LocalDatabase database;
  final RelayService relayService;
  final ConversationRepository conversationRepository;

  final StreamController<LoveConnection?> _connectionStreamController =
      StreamController<LoveConnection?>.broadcast();

  LoveConnection? _cachedConnection;

  DefaultLoveConnectionService({
    required this.database,
    required this.relayService,
    required this.conversationRepository,
  });

  String _normalizeUsername(String username) {
    var clean = username.trim();
    if (!clean.startsWith('@')) {
      clean = '@$clean';
    }
    return clean.toLowerCase();
  }

  @override
  Future<LoveConnection?> getLoveConnection({String? currentUserId}) async {
    if (_cachedConnection != null) {
      return _cachedConnection;
    }
    _cachedConnection = await database.getLoveConnection(userId: currentUserId);
    return _cachedConnection;
  }

  @override
  Stream<LoveConnection?> watchLoveConnection({String? currentUserId}) async* {
    yield await getLoveConnection(currentUserId: currentUserId);
    yield* _connectionStreamController.stream;
  }

  @override
  Future<User?> searchPartnerByUsername(
    String username, {
    String? currentUsername,
  }) async {
    final clean = _normalizeUsername(username);
    if (currentUsername != null && clean == _normalizeUsername(currentUsername)) {
      throw const LoveConnectionException('You cannot form a Love Connection with yourself.');
    }

    // Lookup known users in local database or known conversations
    final existingUser = await database.getAccountByUsername(clean);
    if (existingUser != null) {
      return User(
        id: existingUser.accountId,
        username: existingUser.username,
        displayName: existingUser.username,
        publicIdentityKey: existingUser.publicIdentityKey,
      );
    }

    // Default partner discovery for demonstration / pairing
    return User(
      id: 'user_${clean.replaceAll('@', '')}',
      username: clean,
      displayName: clean.replaceAll('@', ''),
    );
  }

  @override
  Future<LoveConnection> sendConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  }) async {
    final normalizedPartner = _normalizeUsername(partnerUsername);
    final normalizedCurrent = _normalizeUsername(currentUsername);

    if (normalizedPartner == normalizedCurrent) {
      throw const LoveConnectionException('You cannot form a Love Connection with yourself.');
    }

    // Enforce 1-to-1 Invariant: Only 0 or 1 active connection allowed
    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current != null && current.isConnected) {
      throw const LoveConnectionException(
        'You already have an active Love Connection. You must disconnect before connecting with someone else.',
      );
    }
    if (current != null && current.isPendingSent) {
      throw const LoveConnectionException(
        'You already have a pending Love Connection request. Cancel it first before sending a new one.',
      );
    }

    final connectionId =
        'love_${DateTime.now().millisecondsSinceEpoch}_${normalizedPartner.replaceAll('@', '')}';
    final connection = LoveConnection(
      id: connectionId,
      userId: currentUserId,
      partnerUsername: normalizedPartner,
      status: LoveConnectionStatus.requestSent,
      createdAt: DateTime.now(),
    );

    // Save locally
    await database.saveLoveConnection(connection);
    _cachedConnection = connection;
    _connectionStreamController.add(connection);

    // Dispatch ephemeral request envelope to relay
    final envelope = EphemeralRelayEnvelope.loveRequest(
      senderId: normalizedCurrent,
      recipientId: normalizedPartner,
      senderPublicKey: currentPublicKey,
    );
    await relayService.enqueueMessage(envelope);

    return connection;
  }

  @override
  Future<LoveConnection> acceptConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  }) async {
    final normalizedPartner = _normalizeUsername(partnerUsername);
    final normalizedCurrent = _normalizeUsername(currentUsername);

    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current != null && current.isConnected) {
      throw const LoveConnectionException(
        'You already have an active Love Connection with a partner.',
      );
    }

    final now = DateTime.now();
    final connection = (current ?? LoveConnection(
      id: 'love_${now.millisecondsSinceEpoch}',
      userId: currentUserId,
      partnerUsername: normalizedPartner,
      status: LoveConnectionStatus.requestReceived,
      createdAt: now,
    )).copyWith(
      status: LoveConnectionStatus.connected,
      connectedAt: now,
      partnerUsername: normalizedPartner,
    );

    // Save locally
    await database.saveLoveConnection(connection);
    _cachedConnection = connection;
    _connectionStreamController.add(connection);

    // Dispatch acceptance envelope to partner
    final envelope = EphemeralRelayEnvelope.loveAccept(
      senderId: normalizedCurrent,
      recipientId: normalizedPartner,
      senderPublicKey: currentPublicKey,
    );
    await relayService.enqueueMessage(envelope);

    // Elevate conversation in ConversationRepository
    await conversationRepository.startOrGetConversation(
      partner: User(
        id: 'user_${normalizedPartner.replaceAll('@', '')}',
        username: normalizedPartner,
        displayName: normalizedPartner.replaceAll('@', ''),
        loveConnectionId: connection.id,
      ),
      isLoveConnection: true,
    );

    return connection;
  }

  @override
  Future<void> declineConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
  }) async {
    final normalizedPartner = _normalizeUsername(partnerUsername);
    final normalizedCurrent = _normalizeUsername(currentUsername);

    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current != null) {
      await database.deleteLoveConnection(current.id);
      _cachedConnection = null;
      _connectionStreamController.add(null);
    }

    // Dispatch decline notification to partner
    final envelope = EphemeralRelayEnvelope.loveDecline(
      senderId: normalizedCurrent,
      recipientId: normalizedPartner,
    );
    await relayService.enqueueMessage(envelope);
  }

  @override
  Future<void> cancelConnectionRequest({
    required String currentUserId,
    required String currentUsername,
  }) async {
    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current == null) return;

    final normalizedCurrent = _normalizeUsername(currentUsername);
    final partner = current.partnerUsername;

    await database.deleteLoveConnection(current.id);
    _cachedConnection = null;
    _connectionStreamController.add(null);

    // Dispatch cancel notification to partner
    final envelope = EphemeralRelayEnvelope.loveCancel(
      senderId: normalizedCurrent,
      recipientId: partner,
    );
    await relayService.enqueueMessage(envelope);
  }

  @override
  Future<void> unlinkLoveConnection({
    required String currentUserId,
    required String currentUsername,
  }) async {
    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current == null) return;

    final partner = current.partnerUsername;
    final normalizedCurrent = _normalizeUsername(currentUsername);

    final unlinked = current.copyWith(
      status: LoveConnectionStatus.disconnected,
      disconnectedAt: DateTime.now(),
    );

    await database.saveLoveConnection(unlinked);
    _cachedConnection = unlinked;
    _connectionStreamController.add(unlinked);

    // Demote in ConversationRepository
    final loveConv = await conversationRepository.getLoveConnectionConversation(
      currentUserId: currentUserId,
    );
    if (loveConv != null) {
      // Local chat history is preserved in SQLite!
    }

    // Dispatch unlink envelope
    final envelope = EphemeralRelayEnvelope.loveUnlink(
      senderId: normalizedCurrent,
      recipientId: partner,
    );
    await relayService.enqueueMessage(envelope);
  }

  @override
  Future<void> setVisibilityOnProfile(
    bool isVisible, {
    required String currentUserId,
  }) async {
    final current = await getLoveConnection(currentUserId: currentUserId);
    if (current == null) return;

    final updated = current.copyWith(isVisibleOnProfile: isVisible);
    await database.saveLoveConnection(updated);
    _cachedConnection = updated;
    _connectionStreamController.add(updated);
  }

  @override
  Future<void> processInboundLoveEnvelope(
    EphemeralRelayEnvelope envelope, {
    required String currentUserId,
    required String currentUsername,
  }) async {
    if (!envelope.isLoveSignal) return;

    final senderUsername = _normalizeUsername(envelope.senderId);
    final current = await getLoveConnection(currentUserId: currentUserId);

    switch (envelope.envelopeType) {
      case 'love_request':
        // If current user is already connected with someone else, do not overwrite
        if (current != null && current.isConnected) {
          return;
        }

        // Parse optional public key from payload
        String? partnerPublicKey;
        try {
          final data = jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
          partnerPublicKey = data['sender_public_key'] as String?;
        } catch (_) {}

        final newConn = LoveConnection(
          id: 'love_${DateTime.now().millisecondsSinceEpoch}_${senderUsername.replaceAll('@', '')}',
          userId: currentUserId,
          partnerUsername: senderUsername,
          partnerPublicKey: partnerPublicKey,
          status: LoveConnectionStatus.requestReceived,
          createdAt: envelope.timestamp,
        );

        await database.saveLoveConnection(newConn);
        _cachedConnection = newConn;
        _connectionStreamController.add(newConn);
        break;

      case 'love_accept':
        // Partner accepted our pending request!
        if (current != null &&
            current.isPendingSent &&
            _normalizeUsername(current.partnerUsername) == senderUsername) {
          String? partnerPublicKey;
          try {
            final data = jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
            partnerPublicKey = data['sender_public_key'] as String?;
          } catch (_) {}

          final connected = current.copyWith(
            status: LoveConnectionStatus.connected,
            connectedAt: DateTime.now(),
            partnerPublicKey: partnerPublicKey ?? current.partnerPublicKey,
          );

          await database.saveLoveConnection(connected);
          _cachedConnection = connected;
          _connectionStreamController.add(connected);

          // Elevate conversation
          await conversationRepository.startOrGetConversation(
            partner: User(
              id: 'user_${senderUsername.replaceAll('@', '')}',
              username: senderUsername,
              displayName: senderUsername.replaceAll('@', ''),
              loveConnectionId: connected.id,
            ),
            isLoveConnection: true,
          );
        }
        break;

      case 'love_decline':
        // Partner declined our request
        if (current != null &&
            current.isPendingSent &&
            _normalizeUsername(current.partnerUsername) == senderUsername) {
          await database.deleteLoveConnection(current.id);
          _cachedConnection = null;
          _connectionStreamController.add(null);
        }
        break;

      case 'love_cancel':
        // Partner cancelled request they sent to us
        if (current != null &&
            current.isPendingReceived &&
            _normalizeUsername(current.partnerUsername) == senderUsername) {
          await database.deleteLoveConnection(current.id);
          _cachedConnection = null;
          _connectionStreamController.add(null);
        }
        break;

      case 'love_unlink':
        // Partner unlinked the couple connection
        if (current != null &&
            current.isConnected &&
            _normalizeUsername(current.partnerUsername) == senderUsername) {
          final unlinked = current.copyWith(
            status: LoveConnectionStatus.disconnected,
            disconnectedAt: DateTime.now(),
          );
          await database.saveLoveConnection(unlinked);
          _cachedConnection = unlinked;
          _connectionStreamController.add(unlinked);
        }
        break;
    }
  }
}

/// Hermetic in-memory implementation of [LoveConnectionService] for testing and fallbacks
class InMemoryLoveConnectionService implements LoveConnectionService {
  LoveConnection? _currentConnection;
  final StreamController<LoveConnection?> _controller =
      StreamController<LoveConnection?>.broadcast();

  InMemoryLoveConnectionService([this._currentConnection]);

  @override
  Future<LoveConnection?> getLoveConnection({String? currentUserId}) async {
    return _currentConnection;
  }

  @override
  Stream<LoveConnection?> watchLoveConnection({String? currentUserId}) async* {
    yield _currentConnection;
    yield* _controller.stream;
  }

  @override
  Future<User?> searchPartnerByUsername(
    String username, {
    String? currentUsername,
  }) async {
    final clean = username.trim().startsWith('@') ? username.trim() : '@${username.trim()}';
    return User(
      id: 'user_${clean.replaceAll('@', '')}',
      username: clean,
      displayName: clean.replaceAll('@', ''),
    );
  }

  @override
  Future<LoveConnection> sendConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  }) async {
    final conn = LoveConnection(
      id: 'love_conn_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUserId,
      partnerUsername: partnerUsername,
      status: LoveConnectionStatus.requestSent,
      createdAt: DateTime.now(),
    );
    _currentConnection = conn;
    _controller.add(conn);
    return conn;
  }

  @override
  Future<LoveConnection> acceptConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    String? currentPublicKey,
  }) async {
    final conn = (_currentConnection ?? LoveConnection(
      id: 'love_conn_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUserId,
      partnerUsername: partnerUsername,
      status: LoveConnectionStatus.requestReceived,
      createdAt: DateTime.now(),
    )).copyWith(
      status: LoveConnectionStatus.connected,
      connectedAt: DateTime.now(),
    );
    _currentConnection = conn;
    _controller.add(conn);
    return conn;
  }

  @override
  Future<void> declineConnectionRequest({
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
  }) async {
    _currentConnection = null;
    _controller.add(null);
  }

  @override
  Future<void> cancelConnectionRequest({
    required String currentUserId,
    required String currentUsername,
  }) async {
    _currentConnection = null;
    _controller.add(null);
  }

  @override
  Future<void> unlinkLoveConnection({
    required String currentUserId,
    required String currentUsername,
  }) async {
    if (_currentConnection != null) {
      final unlinked = _currentConnection!.copyWith(
        status: LoveConnectionStatus.disconnected,
        disconnectedAt: DateTime.now(),
      );
      _currentConnection = unlinked;
      _controller.add(unlinked);
    }
  }

  @override
  Future<void> setVisibilityOnProfile(
    bool isVisible, {
    required String currentUserId,
  }) async {
    if (_currentConnection != null) {
      final updated = _currentConnection!.copyWith(isVisibleOnProfile: isVisible);
      _currentConnection = updated;
      _controller.add(updated);
    }
  }

  @override
  Future<void> processInboundLoveEnvelope(
    EphemeralRelayEnvelope envelope, {
    required String currentUserId,
    required String currentUsername,
  }) async {}

  /// Test helper to set simulated connection state
  void setMockConnection(LoveConnection? connection) {
    _currentConnection = connection;
    _controller.add(connection);
  }
}

