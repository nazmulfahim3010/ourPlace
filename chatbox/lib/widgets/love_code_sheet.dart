import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbox/models/love_code_session.dart';
import 'package:chatbox/services/conversation_sharing_service.dart';

/// Modal bottom sheet for generating and presenting a 60-second One-Time Love Code (Phase 17).
class LoveCodeSheet extends StatefulWidget {
  final String conversationPartner;
  final String currentUserId;
  final String currentUsername;
  final String lovePartnerUsername;
  final ConversationSharingService sharingService;

  const LoveCodeSheet({
    super.key,
    required this.conversationPartner,
    required this.currentUserId,
    required this.currentUsername,
    required this.lovePartnerUsername,
    required this.sharingService,
  });

  /// Static helper to display the sheet easily
  static Future<void> show(
    BuildContext context, {
    required String conversationPartner,
    required String currentUserId,
    required String currentUsername,
    required String lovePartnerUsername,
    required ConversationSharingService sharingService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LoveCodeSheet(
        conversationPartner: conversationPartner,
        currentUserId: currentUserId,
        currentUsername: currentUsername,
        lovePartnerUsername: lovePartnerUsername,
        sharingService: sharingService,
      ),
    );
  }

  @override
  State<LoveCodeSheet> createState() => _LoveCodeSheetState();
}

class _LoveCodeSheetState extends State<LoveCodeSheet> {
  LoveCodeSession? _session;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<LoveCodeSession?>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _initOrGenerateCode();
  }

  Future<void> _initOrGenerateCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final existing = widget.sharingService.getActiveLoveCode(
        currentUserId: widget.currentUserId,
      );

      final session = existing ??
          await widget.sharingService.generateLoveCode(
            conversationPartner: widget.conversationPartner,
            currentUserId: widget.currentUserId,
            currentUsername: widget.currentUsername,
            lovePartnerUsername: widget.lovePartnerUsername,
          );

      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });

        _sessionSubscription?.cancel();
        _sessionSubscription = widget.sharingService
            .watchActiveLoveCode(currentUserId: widget.currentUserId)
            .listen((updated) {
          if (mounted) {
            setState(() {
              _session = updated;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('AppException: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final remaining = session?.remainingSeconds ?? 0;
    final progress = (remaining / 60.0).clamp(0.0, 1.0);
    final isUsed = session?.isUsed ?? false;
    final isExpired = session?.isExpired ?? false;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Romantic Title & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'One-Time Love Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share ${widget.conversationPartner} with ${widget.lovePartnerUsername}',
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (_isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            ),
          ] else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (isUsed) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Conversation Shared!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.lovePartnerUsername} has successfully redeemed the code and received the messages.',
                    style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else if (isExpired) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF444444)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.timer_off_outlined, color: Colors.amberAccent, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Code Expired (60s Reached)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'For security, Love Codes expire after 60 seconds.',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _initOrGenerateCode,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                    label: const Text(
                      'Generate New Code',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (session != null) ...[
            // 6-digit Code Display Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: session.code.split('').map((digit) {
                return Container(
                  width: 44,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Text(
                    digit,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Copy Action
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: session.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Love Code copied to clipboard'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF2E2E2E),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Copy Code',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 60-Second Countdown Progress Bar
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF333333),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remaining < 15 ? Colors.redAccent : Colors.pinkAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.pinkAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Waiting for ${widget.lovePartnerUsername}...',
                          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${remaining}s',
                      style: TextStyle(
                        color: remaining < 15 ? Colors.redAccent : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Dismiss Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF444444)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
