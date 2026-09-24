import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/services/notification_service.dart';

/// Interactive, high-contrast notification popup that drops down from the upper side of the screen
class TopNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? conversationId;
  final bool isDiscreet;
  final bool isLoveSignal;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration displayDuration;

  const TopNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.conversationId,
    this.isDiscreet = false,
    this.isLoveSignal = false,
    this.onTap,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
  });

  @override
  State<TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<TopNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    _dismissTimer = Timer(widget.displayDuration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  Color get _accentColor {
    if (widget.isDiscreet) return AppTheme.notificationDiscreetGold;
    if (widget.isLoveSignal ||
        widget.body.contains('❤️') ||
        widget.body.toLowerCase().contains('luv')) {
      return AppTheme.notificationLovePink;
    }
    if (widget.body.contains('📷') ||
        widget.body.contains('🎙️') ||
        widget.body.contains('🎥')) {
      return AppTheme.notificationSuccessGreen;
    }
    return AppTheme.notificationChatBlue;
  }

  IconData get _notificationIcon {
    if (widget.isDiscreet) return Icons.shield_outlined;
    if (widget.isLoveSignal ||
        widget.body.contains('❤️') ||
        widget.body.toLowerCase().contains('luv')) {
      return Icons.favorite_rounded;
    }
    if (widget.body.contains('📷')) return Icons.camera_alt_rounded;
    if (widget.body.contains('🎙️')) return Icons.mic_rounded;
    if (widget.body.contains('🎥')) return Icons.videocam_rounded;
    return Icons.chat_bubble_rounded;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final accent = _accentColor;

    return Positioned(
      top: topPadding + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: const Key('top_notification_dismissible'),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _dismissTimer?.cancel();
              widget.onDismiss?.call();
            },
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _dismissTimer?.cancel();
                  _dismiss();
                  widget.onTap?.call();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.notificationSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.isDiscreet
                          ? AppTheme.notificationDiscreetGold.withValues(alpha: 0.7)
                          : widget.isLoveSignal
                              ? AppTheme.notificationLovePink.withValues(alpha: 0.7)
                              : AppTheme.notificationBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 14,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      /// High-contrast icon pill
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _notificationIcon,
                            color: accent,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      /// Notification Content (Title & Body)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: AppTheme.notificationTextPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isDiscreet) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.notificationDiscreetGold
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.notificationDiscreetGold
                                            .withValues(alpha: 0.6),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: const Text(
                                      'DISCREET',
                                      style: TextStyle(
                                        color: AppTheme.notificationDiscreetGold,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.body,
                              style: const TextStyle(
                                color: AppTheme.notificationTextSecondary,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      /// Close / Dismiss Icon
                      GestureDetector(
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.65),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Global overlay widget providing top notification popups above any child screen
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  final NotificationService? notificationService;

  const InAppNotificationOverlay({
    super.key,
    required this.child,
    this.notificationService,
  });

  /// Programmatically triggers an in-app top notification popup from anywhere in the tree
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String? conversationId,
    bool isDiscreet = false,
    bool isLoveSignal = false,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final state = context.findAncestorStateOfType<_InAppNotificationOverlayState>();
    state?.showNotification(
      title: title,
      body: body,
      conversationId: conversationId,
      isDiscreet: isDiscreet,
      isLoveSignal: isLoveSignal,
      onTap: onTap,
      duration: duration,
    );
  }

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  _NotificationPayload? _activeNotification;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  @override
  void didUpdateWidget(InAppNotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notificationService != oldWidget.notificationService) {
      _notificationSub?.cancel();
      _subscribeToNotifications();
    }
  }

  void _subscribeToNotifications() {
    final service = widget.notificationService ?? DefaultNotificationService();
    _notificationSub = service.onNotificationDisplayed.listen((payload) {
      if (!mounted) return;
      showNotification(
        title: payload['title'] as String? ?? 'Nest',
        body: payload['body'] as String? ?? '',
        conversationId: payload['conversationId'] as String?,
        isDiscreet: payload['isDiscreet'] as bool? ?? false,
        isLoveSignal: payload['isLoveSignal'] as bool? ?? false,
      );
    });
  }

  void showNotification({
    required String title,
    required String body,
    String? conversationId,
    bool isDiscreet = false,
    bool isLoveSignal = false,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    setState(() {
      _activeNotification = _NotificationPayload(
        id: UniqueKey(),
        title: title,
        body: body,
        conversationId: conversationId,
        isDiscreet: isDiscreet,
        isLoveSignal: isLoveSignal,
        onTap: onTap,
        duration: duration,
      );
    });
  }

  void _clearActiveNotification(Key id) {
    if (mounted && _activeNotification?.id == id) {
      setState(() {
        _activeNotification = null;
      });
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _activeNotification;

    return Stack(
      children: [
        widget.child,
        if (current != null)
          TopNotificationBanner(
            key: current.id,
            title: current.title,
            body: current.body,
            conversationId: current.conversationId,
            isDiscreet: current.isDiscreet,
            isLoveSignal: current.isLoveSignal,
            displayDuration: current.duration,
            onTap: () {
              final convId = current.conversationId;
              if (current.onTap != null) {
                current.onTap!();
              } else if (convId != null) {
                final service =
                    widget.notificationService ?? DefaultNotificationService();
                service.simulateNotificationTap(convId);
              }
              _clearActiveNotification(current.id);
            },
            onDismiss: () => _clearActiveNotification(current.id),
          ),
      ],
    );
  }
}

class _NotificationPayload {
  final Key id;
  final String title;
  final String body;
  final String? conversationId;
  final bool isDiscreet;
  final bool isLoveSignal;
  final VoidCallback? onTap;
  final Duration duration;

  _NotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    this.conversationId,
    this.isDiscreet = false,
    this.isLoveSignal = false,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });
}
