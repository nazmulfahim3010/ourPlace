import 'package:flutter/material.dart';
import 'package:chatbox/models/love_connection.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/couple/love_notes_screen.dart';
import 'package:chatbox/screens/memories/shared_memories_screen.dart';
import 'package:chatbox/services/couple_features_service.dart';

/// Screen displaying relationship milestones, anniversary countdown, and couple dashboard (Phase 18)
class CoupleMilestonesScreen extends StatefulWidget {
  final LoveConnection loveConnection;
  final ChatRepository chatRepository;
  final String currentUsername;

  const CoupleMilestonesScreen({
    super.key,
    required this.loveConnection,
    required this.chatRepository,
    required this.currentUsername,
  });

  @override
  State<CoupleMilestonesScreen> createState() => _CoupleMilestonesScreenState();
}

class _CoupleMilestonesScreenState extends State<CoupleMilestonesScreen> {
  RelationshipMilestones? _milestones;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final messages = await widget.chatRepository
          .getMessages(widget.loveConnection.partnerUsername);
      final ms = widget.chatRepository.coupleFeaturesService.calculateMilestones(
        connectedAt: widget.loveConnection.connectedAt,
        messages: messages,
      );
      if (mounted) {
        setState(() {
          _milestones = ms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.loveConnection.partnerUsername;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Couple Space ❤️',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white38))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFF4081),
              backgroundColor: const Color(0xFF282828),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  /// Couple Header Hero
                  _buildCoupleHero(partner),
                  const SizedBox(height: 16),

                  /// "Together Since" Anniversary Card
                  if (_milestones != null) _buildTogetherCard(_milestones!),
                  const SizedBox(height: 16),

                  /// Quick Launch Grid (Memories & Love Letters)
                  _buildQuickLaunchSection(partner),
                  const SizedBox(height: 24),

                  /// Milestone Badges Section
                  if (_milestones != null) _buildBadgesSection(_milestones!),
                ],
              ),
            ),
    );
  }

  Widget _buildCoupleHero(String partner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF383838), width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatar(widget.currentUsername),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('❤️', style: TextStyle(fontSize: 28)),
              ),
              _buildAvatar(partner),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.currentUsername} & $partner',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2428),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF80AB), width: 0.8),
            ),
            child: const Text(
              '❤️ Love Connection Active',
              style: TextStyle(
                color: Color(0xFFFF80AB),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String username) {
    final clean = username.startsWith('@') ? username.substring(1) : username;
    final initial = clean.isNotEmpty ? clean[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF383838),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTogetherCard(RelationshipMilestones ms) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF333333), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOGETHER SINCE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ms.durationText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Messages', '${ms.totalMessages}', Icons.chat_bubble_outline),
              ),
              Expanded(
                child: _buildStatItem('Media Shared', '${ms.mediaCount}', Icons.photo_library_outlined),
              ),
              Expanded(
                child: _buildStatItem('Next Milestone', '${ms.daysUntilNextAnniversary}d', Icons.cake_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickLaunchSection(String partner) {
    return Row(
      children: [
        Expanded(
          child: _buildLaunchButton(
            title: 'Shared Memories',
            subtitle: 'Photos & Voice Notes',
            icon: Icons.photo_album_outlined,
            color: const Color(0xFF00E676),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SharedMemoriesScreen(
                    partnerUsername: partner,
                    chatRepository: widget.chatRepository,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLaunchButton(
            title: 'Love Letters',
            subtitle: 'Sealed Private Notes',
            icon: Icons.mail_outline_rounded,
            color: const Color(0xFFFF4081),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoveNotesScreen(
                    partnerUsername: partner,
                    currentUsername: widget.currentUsername,
                    chatRepository: widget.chatRepository,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLaunchButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF383838), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection(RelationshipMilestones ms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RELATIONSHIP MILESTONES',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...ms.badges.map((b) => _buildBadgeTile(b)),
      ],
    );
  }

  Widget _buildBadgeTile(MilestoneBadge badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: badge.isUnlocked ? const Color(0xFF282828) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.isUnlocked ? const Color(0xFF484848) : const Color(0xFF2C2C2C),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badge.isUnlocked ? const Color(0xFF383838) : const Color(0xFF242424),
              shape: BoxShape.circle,
            ),
            child: Text(badge.icon, style: TextStyle(fontSize: badge.isUnlocked ? 18 : 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                    color: badge.isUnlocked ? Colors.white : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  badge.description,
                  style: TextStyle(
                    color: badge.isUnlocked ? Colors.white54 : Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (badge.isUnlocked)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 18)
          else
            const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
