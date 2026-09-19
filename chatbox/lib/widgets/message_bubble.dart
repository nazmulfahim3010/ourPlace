import 'package:flutter/material.dart';
import 'package:chatbox/models/media_attachment.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/widgets/timestamp_indicator.dart';

/// Individual message bubble widget supporting Text, Image, Audio, and Video (Phase 15 — Media Messaging)
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final bool? isSent;
  final VoidCallback? onMediaTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.isSent,
    this.onMediaTap,
  });

  bool get _effectiveIsSent => isSent ?? message.isSent;
  MediaAttachment? get _attachment => message.mediaAttachment;

  @override
  Widget build(BuildContext context) {
    final sent = _effectiveIsSent;

    return Column(
      crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        /// Timestamp and delivery status indicator above message
        if (showTimestamp) ...[
          TimestampIndicator(
            timestamp: message.timestamp,
            isSent: sent,
            status: sent ? message.status : null,
          ),
          const SizedBox(height: 4),
        ],

        /// Message bubble container
        Align(
          alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildBubbleContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageBubble(context);
      case MessageType.audio:
        return _buildAudioBubble(context);
      case MessageType.video:
        return _buildVideoBubble(context);
      case MessageType.text:
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          child: Text(
            message.getContent(),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        );
    }
  }

  Widget _buildImageBubble(BuildContext context) {
    final att = _attachment;
    final hasCaption = message.text.isNotEmpty && message.text != att?.fileName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMediaTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: hasCaption ? Radius.zero : const Radius.circular(20),
            ),
            child: Container(
              height: 180,
              width: double.infinity,
              color: const Color(0xFF282828),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fallback dark romantic thumbnail container
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_outlined, color: Colors.white70, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          att?.fileName ?? 'Encrypted Photo',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (att != null)
                          Text(
                            att.formattedFileSize,
                            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Lock badge indicator in top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xAA000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Color(0xFF4CAF50), size: 10),
                          SizedBox(width: 3),
                          Text(
                            'E2EE',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioBubble(BuildContext context) {
    final att = _attachment;
    final durationStr = att?.formattedDuration ?? '0:30';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMediaTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF4A4A4A),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            // Simulated waveform bars
            Row(
              children: List.generate(16, (i) {
                final barHeights = [8, 14, 20, 12, 22, 16, 10, 24, 18, 12, 20, 14, 8, 16, 12, 6];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: barHeights[i % barHeights.length].toDouble(),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(width: 10),
            Text(
              durationStr,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBubble(BuildContext context) {
    final att = _attachment;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMediaTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          width: double.infinity,
          color: const Color(0xFF282828),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xAA000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 12,
                child: Text(
                  att?.fileName ?? 'Video attachment',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 12,
                child: Text(
                  att?.formattedDuration ?? '0:30',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
