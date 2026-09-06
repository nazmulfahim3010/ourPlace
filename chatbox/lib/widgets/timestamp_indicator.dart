import 'package:flutter/material.dart';

/// Timestamp indicator widget
class TimestampIndicator extends StatelessWidget {
  final DateTime timestamp;
  final bool isSent;

  const TimestampIndicator({
    Key? key,
    required this.timestamp,
    required this.isSent,
  }) : super(key: key);

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          _formatTime(timestamp),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}
