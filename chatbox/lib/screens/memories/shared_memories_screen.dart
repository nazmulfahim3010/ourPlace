import 'package:flutter/material.dart';
import 'package:chatbox/models/message.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/media/private_media_viewer_screen.dart';

/// Screen displaying the shared media gallery between the couple (Phase 18)
class SharedMemoriesScreen extends StatefulWidget {
  final String partnerUsername;
  final ChatRepository chatRepository;

  const SharedMemoriesScreen({
    super.key,
    required this.partnerUsername,
    required this.chatRepository,
  });

  @override
  State<SharedMemoriesScreen> createState() => _SharedMemoriesScreenState();
}

class _SharedMemoriesScreenState extends State<SharedMemoriesScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Photos, 2: Audio, 3: Videos
  List<ChatMessage> _allMemories = [];
  bool _isLoading = true;

  static const List<String> _filters = ['All', 'Photos 📸', 'Audio 🎙️', 'Videos 🎥'];

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    try {
      final messages = await widget.chatRepository
          .getMessages(widget.partnerUsername);
      final media = messages.where((m) => m.mediaAttachment != null).toList();
      if (mounted) {
        setState(() {
          _allMemories = media;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ChatMessage> get _filteredMemories {
    switch (_selectedFilterIndex) {
      case 1:
        return _allMemories.where((m) => m.type == MessageType.image).toList();
      case 2:
        return _allMemories.where((m) => m.type == MessageType.audio).toList();
      case 3:
        return _allMemories.where((m) => m.type == MessageType.video).toList();
      default:
        return _allMemories;
    }
  }

  void _openMedia(ChatMessage message) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateMediaViewerScreen(
          message: message,
          storageService: widget.chatRepository.mediaStorageService,
        ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared Memories ❤️',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'with ${widget.partnerUsername}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          /// Filter row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF141414),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFilterIndex = index);
                        }
                      },
                      backgroundColor: const Color(0xFF282828),
                      selectedColor: const Color(0xFFFF4081),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFFF4081) : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          /// Memory count banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredMemories.length} ${_filteredMemories.length == 1 ? 'memory' : 'memories'} preserved',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          /// Grid or Empty State
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  )
                : _filteredMemories.isEmpty
                    ? _buildEmptyState()
                    : _buildGalleryGrid(),
          ),
        ],
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
              child: const Icon(Icons.favorite_outline, color: Color(0xFFFF80AB), size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Shared Memories Yet',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photos, voice notes, and videos shared between you and your Love Connection will automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final memories = _filteredMemories;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final item = memories[index];
        final att = item.mediaAttachment;

        return GestureDetector(
          onTap: () => _openMedia(item),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF383838), width: 0.8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Icon(
                    item.type == MessageType.image
                        ? Icons.image
                        : item.type == MessageType.audio
                            ? Icons.mic
                            : Icons.videocam,
                    color: item.type == MessageType.image
                        ? const Color(0xFF00E676)
                        : item.type == MessageType.audio
                            ? const Color(0xFF29B6F6)
                            : const Color(0xFFFF80AB),
                    size: 32,
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(
                    att?.fileName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
