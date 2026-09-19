import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbox/services/conversation_sharing_service.dart';

/// Dialog for claiming and importing a shared conversation using a 6-digit Love Code (Phase 17).
class ClaimLoveCodeDialog extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;
  final String lovePartnerUsername;
  final ConversationSharingService sharingService;
  final VoidCallback? onImportSuccess;

  const ClaimLoveCodeDialog({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    required this.lovePartnerUsername,
    required this.sharingService,
    this.onImportSuccess,
  });

  /// Static helper to display the dialog easily
  static Future<void> show(
    BuildContext context, {
    required String currentUserId,
    required String currentUsername,
    required String lovePartnerUsername,
    required ConversationSharingService sharingService,
    VoidCallback? onImportSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ClaimLoveCodeDialog(
        currentUserId: currentUserId,
        currentUsername: currentUsername,
        lovePartnerUsername: lovePartnerUsername,
        sharingService: sharingService,
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<ClaimLoveCodeDialog> createState() => _ClaimLoveCodeDialogState();
}

class _ClaimLoveCodeDialogState extends State<ClaimLoveCodeDialog> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  String? _errorMessage;
  int? _importedCount;
  String? _importedPartner;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit Love Code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Claim bundle from partner device
      final bundle = await widget.sharingService.claimAndReceiveSharedConversation(
        code: code,
        partnerUsername: widget.lovePartnerUsername,
        currentUserId: widget.currentUserId,
        currentUsername: widget.currentUsername,
      );

      // 2. Import into local SQLite
      final count = await widget.sharingService.importSharedConversation(
        bundle: bundle,
        currentUserId: widget.currentUserId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _importedCount = count;
          _importedPartner = bundle.conversationPartner;
        });

        widget.onImportSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('AppException: ', '').replaceAll('ConversationSharingException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      title: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Redeem Love Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_importedCount != null) ...[
              // Success view
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Conversation Imported!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Successfully imported $_importedCount messages with $_importedPartner from ${widget.lovePartnerUsername}.',
                      style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Enter the 6-digit One-Time Love Code shown on ${widget.lovePartnerUsername}\'s screen:',
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
              ),
              const SizedBox(height: 16),

              // 6-digit input
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF444444)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _handleClaim(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_importedCount != null) ...[
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFAAAAAA))),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    'Claim & Import',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ],
    );
  }
}
