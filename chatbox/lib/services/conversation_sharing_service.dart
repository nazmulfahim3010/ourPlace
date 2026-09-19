import 'dart:async';
import 'dart:convert';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/utils/crypto_key_utils.dart';
import 'package:chatbox/database/local_database.dart';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/love_code_session.dart';
import 'package:chatbox/models/shared_conversation_bundle.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/love_connection_service.dart';
import 'package:chatbox/services/relay_service.dart';

/// Abstract service contract for Phase 17 — One-Time Love Code & Conversation Sharing.
abstract class ConversationSharingService {
  /// Generate a 60-second single-use Love Code authorizing sharing of [conversationPartner]'s messages
  Future<LoveCodeSession> generateLoveCode({
    required String conversationPartner,
    required String currentUserId,
    required String currentUsername,
    required String lovePartnerUsername,
    Duration ttl = const Duration(seconds: 60),
  });

  /// Cancel any active Love Code session for [currentUserId]
  Future<void> cancelActiveLoveCode({required String currentUserId});

  /// Watch active Love Code session updates (real-time countdown and status)
  Stream<LoveCodeSession?> watchActiveLoveCode({required String currentUserId});

  /// Get currently active Love Code session (if any and not expired)
  LoveCodeSession? getActiveLoveCode({required String currentUserId});

  /// Claim a Love Code from [partnerUsername], awaiting and decrypting the shared conversation bundle
  Future<SharedConversationBundle> claimAndReceiveSharedConversation({
    required String code,
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    Duration timeout = const Duration(seconds: 20),
  });

  /// Intercept and process incoming ephemeral wire envelopes (claims, bundles, rejects, acks)
  Future<bool> handleInboundEnvelope(EphemeralRelayEnvelope envelope);

  /// Import received conversation bundle into local SQLite database with deduplication
  Future<int> importSharedConversation({
    required SharedConversationBundle bundle,
    required String currentUserId,
  });

  /// Clean up timers and resources
  void dispose();
}

/// Production implementation of [ConversationSharingService]
class DefaultConversationSharingService implements ConversationSharingService {
  final RelayService _relayService;
  final EncryptionService? _encryptionService;
  final LocalDatabase _localDatabase;
  final LoveConnectionService _loveConnectionService;

  final Map<String, LoveCodeSession> _activeSessions = {};
  final Map<String, StreamController<LoveCodeSession?>> _sessionControllers = {};
  final Map<String, Timer> _countdownTimers = {};
  final Map<String, Completer<SharedConversationBundle>> _pendingClaims = {};

  DefaultConversationSharingService({
    RelayService? relayService,
    EncryptionService? encryptionService,
    LocalDatabase? localDatabase,
    LoveConnectionService? loveConnectionService,
  })  : _relayService = relayService ?? InMemoryFirebaseRelayService.instance,
        _encryptionService = encryptionService,
        _localDatabase = localDatabase ?? LocalDatabase(),
        _loveConnectionService =
            loveConnectionService ?? InMemoryLoveConnectionService();

  StreamController<LoveCodeSession?> _getController(String userId) {
    return _sessionControllers.putIfAbsent(
      userId,
      () => StreamController<LoveCodeSession?>.broadcast(),
    );
  }

  @override
  Future<LoveCodeSession> generateLoveCode({
    required String conversationPartner,
    required String currentUserId,
    required String currentUsername,
    required String lovePartnerUsername,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    // 1. Verify that the user has an active Love Connection with lovePartnerUsername
    final conn = await _loveConnectionService.getLoveConnection(
      currentUserId: currentUserId,
    );
    if (conn == null ||
        !conn.isConnected ||
        conn.partnerUsername != lovePartnerUsername) {
      throw ConversationSharingException(
        'You can only share conversations with your verified Love Partner ($lovePartnerUsername).',
        code: 'LOVE_CONNECTION_REQUIRED',
      );
    }

    // 2. Cancel existing active session/timer if any
    _countdownTimers[currentUserId]?.cancel();

    // 3. Generate cryptographically secure 6-digit code
    final code = CryptoKeyUtils.generateLoveCode();
    final session = LoveCodeSession.create(
      code: code,
      conversationPartner: conversationPartner,
      ownerUsername: currentUsername,
      targetLovePartner: lovePartnerUsername,
      ttl: ttl,
    );

    _activeSessions[currentUserId] = session;
    _getController(currentUserId).add(session);

    // 4. Start periodic 1-second countdown timer
    _countdownTimers[currentUserId] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        final current = _activeSessions[currentUserId];
        if (current == null) {
          timer.cancel();
          return;
        }

        if (current.isExpired || current.isUsed) {
          timer.cancel();
          _getController(currentUserId).add(current);
        } else {
          _getController(currentUserId).add(current);
        }
      },
    );

    return session;
  }

  @override
  Future<void> cancelActiveLoveCode({required String currentUserId}) async {
    _countdownTimers[currentUserId]?.cancel();
    _countdownTimers.remove(currentUserId);
    _activeSessions.remove(currentUserId);
    _getController(currentUserId).add(null);
  }

  @override
  Stream<LoveCodeSession?> watchActiveLoveCode({required String currentUserId}) {
    return _getController(currentUserId).stream;
  }

  @override
  LoveCodeSession? getActiveLoveCode({required String currentUserId}) {
    final session = _activeSessions[currentUserId];
    if (session == null || session.isExpired) {
      return null;
    }
    return session;
  }

  @override
  Future<SharedConversationBundle> claimAndReceiveSharedConversation({
    required String code,
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // 1. Verify active connection with partner
    final conn = await _loveConnectionService.getLoveConnection(
      currentUserId: currentUserId,
    );
    if (conn == null ||
        !conn.isConnected ||
        conn.partnerUsername != partnerUsername) {
      throw ConversationSharingException(
        'You can only claim Love Codes from your verified Love Partner ($partnerUsername).',
        code: 'LOVE_CONNECTION_REQUIRED',
      );
    }

    // 2. Setup response completer
    final completer = Completer<SharedConversationBundle>();
    _pendingClaims[partnerUsername] = completer;

    // 3. Dispatch ephemeral claim envelope to partner device
    final claimEnvelope = EphemeralRelayEnvelope.loveCodeClaim(
      senderId: currentUsername,
      recipientId: partnerUsername,
      code: code,
    );
    await _relayService.enqueueMessage(claimEnvelope);

    // 4. Wait for bundle or reject envelope with timeout
    try {
      final bundle = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingClaims.remove(partnerUsername);
          throw ConversationSharingException(
            'Partner device timed out or did not respond. Check the code and try again.',
            code: 'CLAIM_TIMEOUT',
          );
        },
      );

      // 5. Send delivery ACK back to partner to purge bundle from relay
      final ackEnvelope = EphemeralRelayEnvelope.loveShareAck(
        senderId: currentUsername,
        recipientId: partnerUsername,
        shareId: bundle.shareId,
      );
      await _relayService.enqueueMessage(ackEnvelope);

      return bundle;
    } finally {
      _pendingClaims.remove(partnerUsername);
    }
  }

  @override
  Future<bool> handleInboundEnvelope(EphemeralRelayEnvelope envelope) async {
    if (!envelope.isLoveShareSignal) return false;

    switch (envelope.envelopeType) {
      case 'love_share_claim':
        await _handleClaimRequest(envelope);
        return true;

      case 'love_share_bundle':
        await _handleIncomingBundle(envelope);
        return true;

      case 'love_share_reject':
        _handleIncomingReject(envelope);
        return true;

      case 'love_share_ack':
        // Partner acknowledged delivery; nothing further required
        return true;

      default:
        return false;
    }
  }

  Future<void> _handleClaimRequest(EphemeralRelayEnvelope envelope) async {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
    } catch (_) {}

    final submittedCode = data['code'] as String? ?? '';
    final requesterUsername = envelope.senderId;
    final currentUserId = envelope.recipientId;

    // Find active session for current user or matching target
    final session = _activeSessions[currentUserId];

    // Validation checks
    if (session == null) {
      await _sendReject(
        recipientId: requesterUsername,
        senderId: currentUserId,
        reason: 'No active Love Code found on partner device.',
      );
      return;
    }

    if (session.isExpired) {
      await _sendReject(
        recipientId: requesterUsername,
        senderId: currentUserId,
        reason: 'Love Code has expired. Please ask for a new code.',
      );
      return;
    }

    if (session.isUsed) {
      await _sendReject(
        recipientId: requesterUsername,
        senderId: currentUserId,
        reason: 'Love Code has already been used.',
      );
      return;
    }

    if (session.code != submittedCode) {
      await _sendReject(
        recipientId: requesterUsername,
        senderId: currentUserId,
        reason: 'Incorrect Love Code.',
      );
      return;
    }

    if (session.targetLovePartner != requesterUsername) {
      await _sendReject(
        recipientId: requesterUsername,
        senderId: currentUserId,
        reason: 'Unauthorized: This Love Code was not generated for your account.',
      );
      return;
    }

    // Code is valid! Mark as used immediately (single-use replay prevention)
    final usedSession = session.copyWith(isUsed: true);
    _activeSessions[currentUserId] = usedSession;
    _countdownTimers[currentUserId]?.cancel();
    _getController(currentUserId).add(usedSession);

    // Retrieve conversation messages
    final messages = await _localDatabase.getMessagesForPartner(
      session.conversationPartner,
      currentUserId: currentUserId,
    );

    // Package bundle
    final bundle = SharedConversationBundle.create(
      shareId: 'share_${DateTime.now().millisecondsSinceEpoch}',
      senderUsername: currentUserId,
      conversationPartner: session.conversationPartner,
      messages: messages,
    );

    // Encrypt bundle for recipient partner
    String payload = bundle.toJsonString();
    final enc = _encryptionService;
    if (enc != null) {
      final recipientAccount =
          await _localDatabase.getAccountByUsername(requesterUsername);
      final pubKey = recipientAccount?.publicIdentityKey;
      if (pubKey != null && pubKey.isNotEmpty) {
        payload = await enc.encryptPayload(payload, pubKey);
      }
    }

    // Dispatch bundle to partner over relay
    final bundleEnvelope = EphemeralRelayEnvelope.loveShareBundle(
      senderId: currentUserId,
      recipientId: requesterUsername,
      encryptedPayload: payload,
      shareId: bundle.shareId,
    );
    await _relayService.enqueueMessage(bundleEnvelope);
  }

  Future<void> _handleIncomingBundle(EphemeralRelayEnvelope envelope) async {
    final completer = _pendingClaims[envelope.senderId];
    if (completer == null || completer.isCompleted) return;

    try {
      String jsonStr = envelope.ciphertextPayload;
      final enc = _encryptionService;
      if (enc != null) {
        final senderAccount =
            await _localDatabase.getAccountByUsername(envelope.senderId);
        final pubKey = senderAccount?.publicIdentityKey;
        if (pubKey != null && pubKey.isNotEmpty) {
          try {
            jsonStr = await enc.decryptPayload(jsonStr, pubKey);
          } catch (_) {
            // If already plaintext JSON or fallback
          }
        }
      }

      final bundle = SharedConversationBundle.fromJsonString(jsonStr);
      completer.complete(bundle);
    } catch (e) {
      completer.completeError(
        ConversationSharingException(
          'Failed to decrypt or parse shared conversation bundle: $e',
          code: 'BUNDLE_PARSE_ERROR',
        ),
      );
    }
  }

  void _handleIncomingReject(EphemeralRelayEnvelope envelope) {
    final completer = _pendingClaims[envelope.senderId];
    if (completer == null || completer.isCompleted) return;

    String reason = 'Love Code authorization was rejected.';
    try {
      final data =
          jsonDecode(envelope.ciphertextPayload) as Map<String, dynamic>;
      if (data['reason'] != null) {
        reason = data['reason'] as String;
      }
    } catch (_) {}

    completer.completeError(
      ConversationSharingException(reason, code: 'CODE_REJECTED'),
    );
  }

  Future<void> _sendReject({
    required String recipientId,
    required String senderId,
    required String reason,
  }) async {
    final rejectEnvelope = EphemeralRelayEnvelope.loveCodeReject(
      senderId: senderId,
      recipientId: recipientId,
      reason: reason,
    );
    await _relayService.enqueueMessage(rejectEnvelope);
  }

  @override
  Future<int> importSharedConversation({
    required SharedConversationBundle bundle,
    required String currentUserId,
  }) async {
    return await _localDatabase.importSharedMessages(bundle.messages);
  }

  @override
  void dispose() {
    for (final timer in _countdownTimers.values) {
      timer.cancel();
    }
    _countdownTimers.clear();
    for (final controller in _sessionControllers.values) {
      controller.close();
    }
    _sessionControllers.clear();
  }
}

/// Hermetic in-memory implementation of [ConversationSharingService] for testing & UI preview
class InMemoryConversationSharingService implements ConversationSharingService {
  final Map<String, LoveCodeSession> _sessions = {};
  final Map<String, StreamController<LoveCodeSession?>> _controllers = {};
  SharedConversationBundle? simulatedBundle;

  StreamController<LoveCodeSession?> _getController(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<LoveCodeSession?>.broadcast(),
    );
  }

  @override
  Future<LoveCodeSession> generateLoveCode({
    required String conversationPartner,
    required String currentUserId,
    required String currentUsername,
    required String lovePartnerUsername,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    final code = CryptoKeyUtils.generateLoveCode();
    final session = LoveCodeSession.create(
      code: code,
      conversationPartner: conversationPartner,
      ownerUsername: currentUsername,
      targetLovePartner: lovePartnerUsername,
      ttl: ttl,
    );
    _sessions[currentUserId] = session;
    _getController(currentUserId).add(session);
    return session;
  }

  @override
  Future<void> cancelActiveLoveCode({required String currentUserId}) async {
    _sessions.remove(currentUserId);
    _getController(currentUserId).add(null);
  }

  @override
  Stream<LoveCodeSession?> watchActiveLoveCode({required String currentUserId}) {
    return _getController(currentUserId).stream;
  }

  @override
  LoveCodeSession? getActiveLoveCode({required String currentUserId}) {
    final s = _sessions[currentUserId];
    return (s != null && !s.isExpired) ? s : null;
  }

  @override
  Future<SharedConversationBundle> claimAndReceiveSharedConversation({
    required String code,
    required String partnerUsername,
    required String currentUserId,
    required String currentUsername,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (simulatedBundle != null) {
      return simulatedBundle!;
    }
    // Search in sessions
    final session = _sessions.values.firstWhere(
      (s) => s.code == code && s.targetLovePartner == currentUsername,
      orElse: () => throw const ConversationSharingException(
        'Invalid or expired Love Code.',
        code: 'INVALID_CODE',
      ),
    );

    if (session.isExpired) {
      throw const ConversationSharingException(
        'Love Code has expired.',
        code: 'CODE_EXPIRED',
      );
    }

    if (session.isUsed) {
      throw const ConversationSharingException(
        'Love Code has already been used.',
        code: 'CODE_USED',
      );
    }

    return SharedConversationBundle.create(
      shareId: 'test_share_${DateTime.now().millisecondsSinceEpoch}',
      senderUsername: partnerUsername,
      conversationPartner: session.conversationPartner,
      messages: [],
    );
  }

  @override
  Future<bool> handleInboundEnvelope(EphemeralRelayEnvelope envelope) async =>
      envelope.isLoveShareSignal;

  @override
  Future<int> importSharedConversation({
    required SharedConversationBundle bundle,
    required String currentUserId,
  }) async =>
      bundle.totalCount;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}
