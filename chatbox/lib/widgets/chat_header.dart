import 'package:flutter/material.dart';

/// Custom floating pill-shaped header widget
class ChatHeader extends StatelessWidget {
  final String partnerName;
  final VoidCallback onSendLuv;

  const ChatHeader({
    super.key,
    required this.partnerName,
    required this.onSendLuv,
  });

  @override
  Widget build(BuildContext context) {
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
              /// Leading Profile Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              /// Partner Name Title
              Expanded(
                child: Text(
                  partnerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

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
            ],
          ),
        ),
      ),
    );
  }
}
