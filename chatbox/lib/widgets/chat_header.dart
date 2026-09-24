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
  final VoidCallback? onOpenCoupleSpace;
  final VoidCallback? onOpenMemories;

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
    this.onOpenCoupleSpace,
    this.onOpenMemories,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = partnerName.trim();
    final cleanPartnerName = trimmedName.replaceFirst(RegExp(r'^@+'), '').trim();
    final initial = cleanPartnerName.isNotEmpty
        ? cleanPartnerName[0].toUpperCase()
        : '?';

    final canPop = Navigator.of(context).canPop();
    final hasMoreOptions = onShareConversation != null ||
        onOpenMemories != null ||
        onOpenCoupleSpace != null ||
        onSignOut != null;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF383838),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              /// Leading Back Button if pushed on stack
              if (onBackPressed != null || canPop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  tooltip: 'Back to Inbox',
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 8),
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
              const SizedBox(width: 10),

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isTyping)
                      const Text(
                        'typing...',
                        style: TextStyle(
                          color: Color(0xFFFF80AB),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (presenceText != null && presenceText!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                          Flexible(
                            child: Text(
                              presenceText!,
                              style: TextStyle(
                                color: presenceText == 'online'
                                    ? const Color(0xFF00E676)
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              /// Send Luv Button
              TextButton(
                onPressed: onSendLuv,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '💕 Send luv',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              /// Consolidated More Options Menu
              if (hasMoreOptions) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                  tooltip: 'More options',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF282828),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF444444), width: 0.8),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'couple':
                        onOpenCoupleSpace?.call();
                        break;
                      case 'memories':
                        onOpenMemories?.call();
                        break;
                      case 'share':
                        onShareConversation?.call();
                        break;
                      case 'signout':
                        onSignOut?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (onOpenCoupleSpace != null)
                      const PopupMenuItem(
                        value: 'couple',
                        child: Row(
                          children: [
                            Icon(Icons.favorite_rounded, color: Color(0xFFFF4081), size: 18),
                            SizedBox(width: 10),
                            Text('Couple Space ❤️', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onOpenMemories != null)
                      const PopupMenuItem(
                        value: 'memories',
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_outlined, color: Color(0xFF00E676), size: 18),
                            SizedBox(width: 10),
                            Text('Shared Memories', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onShareConversation != null)
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, color: Colors.pinkAccent, size: 18),
                            SizedBox(width: 10),
                            Text('Share Conversation', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onSignOut != null)
                      const PopupMenuItem(
                        value: 'signout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.white70, size: 18),
                            SizedBox(width: 10),
                            Text('Sign out', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
