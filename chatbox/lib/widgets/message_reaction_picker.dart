import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating dark pill emoji reaction picker for messages (Phase 18)
class MessageReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelectEmoji;
  final VoidCallback? onDismiss;

  static const List<String> defaultEmojis = ['❤️', '💕', '🔥', '🥰', '✨'];

  const MessageReactionPicker({
    super.key,
    required this.onSelectEmoji,
    this.onDismiss,
  });

  /// Static helper to display the picker at or near the given message
  static Future<String?> show(
    BuildContext context, {
    Offset? position,
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Reactions',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: (position?.dx ?? (MediaQuery.of(context).size.width / 2)) - 130,
              top: (position?.dy ?? 300) - 70,
              child: Material(
                color: Colors.transparent,
                child: MessageReactionPicker(
                  onSelectEmoji: (emoji) {
                    Navigator.of(context).pop(emoji);
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF424242), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: defaultEmojis.map((emoji) {
          return _EmojiButton(
            emoji: emoji,
            onPressed: () {
              HapticFeedback.lightImpact();
              onSelectEmoji(emoji);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onPressed;

  const _EmojiButton({required this.emoji, required this.onPressed});

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.35 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
