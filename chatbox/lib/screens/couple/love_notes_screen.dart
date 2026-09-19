import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbox/models/love_note.dart';
import 'package:chatbox/repositories/chat_repository.dart';

/// Screen for composing and reading private couple love letters and "Open When..." notes (Phase 18)
class LoveNotesScreen extends StatefulWidget {
  final String partnerUsername;
  final String currentUsername;
  final ChatRepository chatRepository;

  const LoveNotesScreen({
    super.key,
    required this.partnerUsername,
    required this.currentUsername,
    required this.chatRepository,
  });

  @override
  State<LoveNotesScreen> createState() => _LoveNotesScreenState();
}

class _LoveNotesScreenState extends State<LoveNotesScreen> {
  List<LoveNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await widget.chatRepository.coupleFeaturesService
          .getLoveNotes(widget.partnerUsername);
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openNote(LoveNote note) async {
    HapticFeedback.mediumImpact();
    if (!note.isOpened) {
      await widget.chatRepository.coupleFeaturesService
          .markLoveNoteOpened(note.id);
      _loadNotes();
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _LoveLetterDialog(note: note),
    );
  }

  void _composeNote() {
    showDialog(
      context: context,
      builder: (ctx) => _ComposeNoteDialog(
        onSend: (title, body, tag) async {
          await widget.chatRepository.coupleFeaturesService.sendLoveNote(
            partnerUsername: widget.partnerUsername,
            currentUsername: widget.currentUsername,
            title: title,
            body: body,
            tag: tag,
          );
          _loadNotes();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Love Letters 💌',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _composeNote,
        backgroundColor: const Color(0xFFFF4081),
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Write Letter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white38))
          : _notes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF383838), width: 1.5),
              ),
              child: const Icon(Icons.mail_outline_rounded, color: Color(0xFFFF80AB), size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Love Letters Yet',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Write sealed heartfelt notes or "Open When..." letters for your partner to cherish forever.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(LoveNote note) {
    final isMine = note.senderUsername == widget.currentUsername;
    final isSealed = note.isSealed;

    return GestureDetector(
      onTap: () => _openNote(note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSealed ? const Color(0xFFFF80AB).withValues(alpha: 0.5) : const Color(0xFF383838),
            width: isSealed ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSealed ? const Color(0xFF38202A) : const Color(0xFF333333),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                isSealed ? '💌' : '📖',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.tag != null && note.tag!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF383838),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        note.tag!,
                        style: const TextStyle(color: Color(0xFFFF80AB), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  Text(
                    note.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isMine ? 'Sent by you' : 'From ${note.senderUsername}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSealed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2428),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF80AB), width: 0.8),
                ),
                child: const Text(
                  'SEALED',
                  style: TextStyle(color: Color(0xFFFF80AB), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

class _LoveLetterDialog extends StatelessWidget {
  final LoveNote note;

  const _LoveLetterDialog({required this.note});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF202020),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💌', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'from ${note.senderUsername}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF383838), height: 1),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Text(
                  note.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: Color(0xFFFF4081))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeNoteDialog extends StatefulWidget {
  final Function(String title, String body, String? tag) onSend;

  const _ComposeNoteDialog({required this.onSend});

  @override
  State<_ComposeNoteDialog> createState() => _ComposeNoteDialogState();
}

class _ComposeNoteDialogState extends State<_ComposeNoteDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedTag = 'Open right now';

  static const List<String> _tags = [
    'Open right now',
    'Open when you miss me',
    'Open on our anniversary',
    'Open when you need a smile',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write Love Letter 💌',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Letter Title...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedTag,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _tags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTag = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Pour your heart out...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final title = _titleController.text.trim();
                      final body = _bodyController.text.trim();
                      if (title.isNotEmpty && body.isNotEmpty) {
                        widget.onSend(title, body, _selectedTag);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Seal & Send 💌', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
