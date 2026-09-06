import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';

/// Timestamp and status indicator widget
class TimestampIndicator extends StatelessWidget {
  final DateTime timestamp;
  final bool isSent;
  final MessageStatus? status;

  const TimestampIndicator({
    super.key,
    required this.timestamp,
    required this.isSent,
    this.status,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 11, color: Colors.white38);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: Colors.white54);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white54);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF64B5F6));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 13, color: Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(timestamp),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (isSent && status != null) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(status!),
            ],
          ],
        ),
      ),
    );
  }
}
