import 'dart:async';
import 'dart:convert';
import 'package:chatbox/models/ephemeral_relay_envelope.dart';
import 'package:chatbox/models/user_presence.dart';
import 'package:chatbox/services/chat_service.dart';
import 'package:chatbox/services/secure_storage_service.dart';

/// Abstract service contract for real-time typing indicators and presence (Phase 13).
///
/// In strict accordance with zero-knowledge, privacy-first, and battery-efficient architecture:
/// - Typing indicators and presence events are completely volatile (never written to permanent disk).
/// - Keystrokes are debounced to conserve battery and bandwidth.
/// - Users can enable stealth mode (presence/typing sharing toggles) to prevent any tracking.
/// - All heartbeats automatically pause when the app is backgrounded or locked.
abstract class RealtimeService {
  /// Reactive stream delivering typing events for a specific partner (true = typing, false = idle)
  Stream<bool> watchTyping({
    required String currentUserId,
    required String partnerId,
  });

  /// Emit typing state to partner with automatic debouncing and inactivity timeout
  Future<void> sendTyping({
    required String currentUserId,
    required String partnerId,
    required bool isTyping,
  });

  /// Reactive stream delivering presence updates for a specific partner
  Stream<UserPresence> watchPresence({
    required String currentUserId,
    required String partnerId,
  });

  /// Emit presence heartbeat or offline state to partner
  Future<void> updatePresence({
    required String currentUserId,
    required String partnerId,
    required bool isOnline,
  });

  /// Privacy preference: whether to share online presence and last seen
  Future<bool> isPresenceSharingEnabled();
  Future<void> setPresenceSharingEnabled(bool enabled);

  /// Privacy preference: whether to share typing indicator
  Future<bool> isTypingSharingEnabled();
  Future<void> setTypingSharingEnabled(bool enabled);

  /// Pause heartbeats and typing listeners (e.g. app backgrounded or locked)
  void pause();

  /// Resume heartbeats and active signaling (e.g. app foregrounded and unlocked)
  void resume();

  /// Dispose of all active controllers and timers
  void dispose();
}

/// Primary implementation of [RealtimeService] coordinating with [ChatService]
class DefaultRealtimeService implements RealtimeService {
  final ChatService _chatService;
  final SecureStorageService _storage;

  /// Inactivity timer that resets on keystrokes and auto-cancels typing after 3 seconds
  Timer? _inactivityTimer;

  /// Debounce timestamp to throttle typing packets (max 1 packet per 2 seconds)
  DateTime? _lastTypingSentAt;

  /// Heartbeat periodic timer
  Timer? _heartbeatTimer;

  /// Active partner context for heartbeats
  String? _activeCurrentUserId;
  String? _activePartnerId;

  /// Local broadcast controllers for reactive UI consumption
  final Map<String, StreamController<bool>> _typingControllers = {};
  final Map<String, StreamController<UserPresence>> _presenceControllers = {};

  /// Local caching of partner state
  final Map<String, bool> _cachedPartnerTyping = {};
  final Map<String, UserPresence> _cachedPartnerPresence = {};

  /// Storage keys
  static const String _presenceKey = 'privacy_presence_sharing_enabled';
  static const String _typingKey = 'privacy_typing_sharing_enabled';

  DefaultRealtimeService({
    ChatService? chatService,
    SecureStorageService? storage,
  })  : _chatService = chatService ?? ChatService(),
        _storage = storage ?? InMemorySecureStorageService();

  String _partnerKey(String currentUserId, String partnerId) =>
      '$currentUserId:$partnerId';

  StreamController<bool> _getTypingController(
      String currentUserId, String partnerId) {
    final key = _partnerKey(currentUserId, partnerId);
    return _typingControllers.putIfAbsent(
      key,
      () => StreamController<bool>.broadcast(),
    );
  }

  StreamController<UserPresence> _getPresenceController(
      String currentUserId, String partnerId) {
    final key = _partnerKey(currentUserId, partnerId);
    return _presenceControllers.putIfAbsent(
      key,
      () => StreamController<UserPresence>.broadcast(),
    );
  }

  @override
  Stream<bool> watchTyping({
    required String currentUserId,
    required String partnerId,
  }) {
    final controller = _getTypingController(currentUserId, partnerId);

    // Wire ephemeral relay listener
    _chatService.watchPendingRelayEnvelopes(currentUserId).listen((envelopes) {
      for (final env in envelopes) {
        if (env.isTypingSignal && env.senderId == partnerId) {
          final isTyping = env.isTypingActive;
          _cachedPartnerTyping[partnerId] = isTyping;
          if (!controller.isClosed) {
            controller.add(isTyping);
          }
          // Acknowledge and purge signaling envelope immediately
          _chatService.acknowledgeAndPurge(env.id, recipientId: currentUserId);
        }
      }
    });

    return controller.stream;
  }

  @override
  Future<void> sendTyping({
    required String currentUserId,
    required String partnerId,
    required bool isTyping,
  }) async {
    final enabled = await isTypingSharingEnabled();
    if (!enabled && isTyping) {
      // Stealth mode active: do not emit typing
      return;
    }

    _activeCurrentUserId = currentUserId;
    _activePartnerId = partnerId;

    if (isTyping) {
      final now = DateTime.now();
      // Debounce: throttle to 1 packet every 2000ms
      final lastSent = _lastTypingSentAt;
      final shouldSend =
          lastSent == null || now.difference(lastSent).inMilliseconds > 2000;

      if (shouldSend) {
        _lastTypingSentAt = now;
        final envelope = EphemeralRelayEnvelope.typing(
          senderId: currentUserId,
          recipientId: partnerId,
          isTyping: true,
        );
        await _chatService.sendEphemeralEnvelope(envelope);
      }

      // Reset 3-second auto-expiry timer
      _inactivityTimer?.cancel();
      _inactivityTimer = Timer(const Duration(seconds: 3), () async {
        await sendTyping(
          currentUserId: currentUserId,
          partnerId: partnerId,
          isTyping: false,
        );
      });
    } else {
      // Explicit idle / send tapped
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _lastTypingSentAt = null;

      final envelope = EphemeralRelayEnvelope.typing(
        senderId: currentUserId,
        recipientId: partnerId,
        isTyping: false,
      );
      await _chatService.sendEphemeralEnvelope(envelope);
    }
  }

  @override
  Stream<UserPresence> watchPresence({
    required String currentUserId,
    required String partnerId,
  }) {
    final controller = _getPresenceController(currentUserId, partnerId);

    // Wire ephemeral relay listener
    _chatService.watchPendingRelayEnvelopes(currentUserId).listen((envelopes) {
      for (final env in envelopes) {
        if (env.isPresenceSignal && env.senderId == partnerId) {
          try {
            final data = jsonDecode(env.ciphertextPayload) as Map<String, dynamic>;
            final isOnline = data['isOnline'] as bool? ?? false;
            final lastSeen = data['lastSeen'] != null
                ? DateTime.tryParse(data['lastSeen'] as String)
                : null;

            final presence = UserPresence(
              userId: partnerId,
              isOnline: isOnline,
              lastSeen: lastSeen,
            );

            _cachedPartnerPresence[partnerId] = presence;
            if (!controller.isClosed) {
              controller.add(presence);
            }
          } catch (_) {}

          // Acknowledge and purge presence envelope immediately
          _chatService.acknowledgeAndPurge(env.id, recipientId: currentUserId);
        }
      }
    });

    return controller.stream;
  }

  @override
  Future<void> updatePresence({
    required String currentUserId,
    required String partnerId,
    required bool isOnline,
  }) async {
    _activeCurrentUserId = currentUserId;
    _activePartnerId = partnerId;

    final enabled = await isPresenceSharingEnabled();
    final effectiveIsOnline = enabled ? isOnline : false;
    final now = DateTime.now().toUtc();

    final envelope = EphemeralRelayEnvelope.presence(
      senderId: currentUserId,
      recipientId: partnerId,
      isOnline: effectiveIsOnline,
      lastSeen: enabled ? now : null,
    );

    await _chatService.sendEphemeralEnvelope(envelope);

    if (effectiveIsOnline) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final cId = _activeCurrentUserId;
      final pId = _activePartnerId;
      if (cId != null && pId != null) {
        final enabled = await isPresenceSharingEnabled();
        if (enabled) {
          final env = EphemeralRelayEnvelope.presence(
            senderId: cId,
            recipientId: pId,
            isOnline: true,
            lastSeen: DateTime.now().toUtc(),
          );
          await _chatService.sendEphemeralEnvelope(env);
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  Future<bool> isPresenceSharingEnabled() async {
    final val = await _storage.read(_presenceKey);
    return val == null ? true : val == 'true';
  }

  @override
  Future<void> setPresenceSharingEnabled(bool enabled) async {
    await _storage.write(_presenceKey, enabled ? 'true' : 'false');
    final cId = _activeCurrentUserId;
    final pId = _activePartnerId;
    if (cId != null && pId != null) {
      await updatePresence(
        currentUserId: cId,
        partnerId: pId,
        isOnline: enabled,
      );
    }
  }

  @override
  Future<bool> isTypingSharingEnabled() async {
    final val = await _storage.read(_typingKey);
    return val == null ? true : val == 'true';
  }

  @override
  Future<void> setTypingSharingEnabled(bool enabled) async {
    await _storage.write(_typingKey, enabled ? 'true' : 'false');
    if (!enabled) {
      final cId = _activeCurrentUserId;
      final pId = _activePartnerId;
      if (cId != null && pId != null) {
        await sendTyping(
          currentUserId: cId,
          partnerId: pId,
          isTyping: false,
        );
      }
    }
  }

  @override
  void pause() {
    _stopHeartbeat();
    _inactivityTimer?.cancel();
    final cId = _activeCurrentUserId;
    final pId = _activePartnerId;
    if (cId != null && pId != null) {
      // Inform partner we transitioned to offline
      final envelope = EphemeralRelayEnvelope.presence(
        senderId: cId,
        recipientId: pId,
        isOnline: false,
        lastSeen: DateTime.now().toUtc(),
      );
      _chatService.sendEphemeralEnvelope(envelope);
    }
  }

  @override
  void resume() {
    final cId = _activeCurrentUserId;
    final pId = _activePartnerId;
    if (cId != null && pId != null) {
      updatePresence(
        currentUserId: cId,
        partnerId: pId,
        isOnline: true,
      );
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _stopHeartbeat();
    for (final c in _typingControllers.values) {
      c.close();
    }
    for (final c in _presenceControllers.values) {
      c.close();
    }
    _typingControllers.clear();
    _presenceControllers.clear();
  }
}
