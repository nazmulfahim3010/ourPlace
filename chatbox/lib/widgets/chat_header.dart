import 'package:flutter/material.dart';

/// Custom floating pill-shaped header widget
class ChatHeader extends StatelessWidget {
  final String partnerName;
  final VoidCallback onSendLuv;
  final VoidCallback? onSignOut;
  final VoidCallback? onBackPressed;
  final String? currentUsername;
  final bool isTyping;
  final String? presenceText;
  final VoidCallback? onShareConversation;

  const ChatHeader({
    super.key,
    required this.partnerName,
    required this.onSendLuv,
    this.onSignOut,
    this.onBackPressed,
    this.currentUsername,
    this.isTyping = false,
    this.presenceText,
    this.onShareConversation,
  });

  @override
  Widget build(BuildContext context) {
    final cleanPartnerName = partnerName.startsWith('@')
        ? partnerName.substring(1)
        : partnerName;
    final initial = cleanPartnerName.isNotEmpty
        ? cleanPartnerName[0].toUpperCase()
        : '?';

    final canPop = Navigator.of(context).canPop();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF383838),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              /// Leading Back Button if pushed on stack
              if (onBackPressed != null || canPop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  tooltip: 'Back to Inbox',
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 10),
                ),
              ],

              /// Leading Profile Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              /// Partner Name Title & optional presence/typing subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      partnerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isTyping)
                      const Row(
                        children: [
                          Text(
                            'typing...',
                            style: TextStyle(
                              color: Color(0xFFFF80AB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else if (presenceText != null && presenceText!.isNotEmpty)
                      Row(
                        children: [
                          if (presenceText == 'online') ...[
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Text(
                            presenceText!,
                            style: TextStyle(
                              color: presenceText == 'online'
                                  ? const Color(0xFF00E676)
                                  : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    else if (currentUsername != null)
                      Text(
                        'as $currentUsername',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              /// Optional Share Conversation Action (Phase 17)
              if (onShareConversation != null) ...[
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.pinkAccent, size: 18),
                  tooltip: 'Share with Partner ❤️',
                  onPressed: onShareConversation,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],

              /// Send Luv Button
              TextButton(
                onPressed: onSendLuv,
                child: const Text(
                  '💕 Send luv',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              /// Optional Sign Out Action
              if (onSignOut != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
