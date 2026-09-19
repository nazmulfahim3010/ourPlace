import 'package:flutter/material.dart';
import 'package:chatbox/models/media_attachment.dart';

/// Bottom message input bar supporting text, media attachments, and voice notes (Phase 15 — Media Messaging)
class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSendPressed;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onVoiceRecordPressed;
  final bool isRecording;
  final int recordingDurationSeconds;
  final VoidCallback? onCancelRecording;
  final VoidCallback? onSendRecording;
  final MediaAttachment? pendingAttachment;
  final VoidCallback? onRemovePendingAttachment;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSendPressed,
    this.onChanged,
    this.onAttachmentPressed,
    this.onVoiceRecordPressed,
    this.isRecording = false,
    this.recordingDurationSeconds = 0,
    this.onCancelRecording,
    this.onSendRecording,
    this.pendingAttachment,
    this.onRemovePendingAttachment,
  });

  String _formatRecordingTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Staged pending attachment preview banner
            if (pendingAttachment != null && !isRecording) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF383838)),
                ),
                child: Row(
                  children: [
                    Icon(
                      pendingAttachment!.isImage
                          ? Icons.image_rounded
                          : pendingAttachment!.isAudio
                              ? Icons.mic_rounded
                              : Icons.movie_rounded,
                      color: Colors.pinkAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pendingAttachment!.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            pendingAttachment!.formattedFileSize,
                            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      onPressed: onRemovePendingAttachment,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
            ],

            /// Input bar: Voice recording mode OR standard message typing mode
            if (isRecording)
              _buildRecordingBar()
            else
              _buildStandardInputRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2428),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Cancel recording trash button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 22),
            onPressed: onCancelRecording,
            tooltip: 'Cancel recording',
          ),
          const SizedBox(width: 8),

          // Pulsing red dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Recording elapsed timer
          Text(
            _formatRecordingTime(recordingDurationSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          const Text(
            'Recording voice...',
            style: TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const Spacer(),

          // Send recorded audio button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSendRecording,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInputRow(BuildContext context) {
    return Row(
      children: [
        /// Attachment button (📎)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAttachmentPressed,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF383838),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(Icons.attach_file_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        /// Text input field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(28),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSendPressed(),
              decoration: InputDecoration(
                hintText: pendingAttachment != null ? 'Add a caption...' : 'Type a message...',
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        /// Send OR Mic button (dynamically reactive to text changes)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            final showSendButton = hasText || pendingAttachment != null || onVoiceRecordPressed == null;

            if (showSendButton) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSendPressed,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383838),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              );
            } else {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onVoiceRecordPressed,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383838),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
