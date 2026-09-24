import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/models/conversation.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/screens/chat_screen.dart';
import 'package:chatbox/widgets/conversation_tile.dart';

/// Primary Inbox Screen displaying Love Connection and multi-user conversations
class InboxScreen extends StatefulWidget {
  final User? currentUser;
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final ConversationRepository? conversationRepository;
  final VoidCallback? onOpenProfile;

  const InboxScreen({
    super.key,
    this.currentUser,
    this.authRepository,
    this.chatRepository,
    this.conversationRepository,
    this.onOpenProfile,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final ConversationRepository _conversationRepo;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<Conversation>>? _conversationsSub;
  StreamSubscription<dynamic>? _notificationSub;

  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _conversationRepo =
        widget.conversationRepository ?? LocalConversationRepository();
    _searchController.addListener(_onSearchChanged);
    _loadConversations();
    _conversationsSub = _conversationRepo
        .watchConversations(currentUserId: widget.currentUser?.id)
        .listen((conversations) {
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _applySearchFilter();
          _isLoading = false;
        });
      }
    });
    _notificationSub = widget.chatRepository?.notificationService.onNotificationDisplayed
        .listen((_) => _loadConversations());
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    _notificationSub?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearchFilter() {
    final query = _searchQuery;
    if (query.isEmpty) {
      _filteredConversations = _allConversations;
    } else {
      _filteredConversations = _allConversations.where((c) {
        final nameMatch = c.partner.displayName.toLowerCase().contains(query);
        final usernameMatch = c.partner.username.toLowerCase().contains(query);
        final messageMatch = c.lastMessage?.text.toLowerCase().contains(query) ?? false;
        return nameMatch || usernameMatch || messageMatch;
      }).toList();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      _applySearchFilter();
    });
  }

  Future<void> _loadConversations() async {
    final conversations = await _conversationRepo.getConversations(
      currentUserId: widget.currentUser?.id,
    );
    if (mounted) {
      setState(() {
        _allConversations = conversations;
        _applySearchFilter();
        _isLoading = false;
      });
    }
  }

  void _openConversation(Conversation conversation) {
    _conversationRepo.markAsRead(conversation.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          partnerName: conversation.partner.displayName,
          partnerId: conversation.partner.id,
          currentUser: widget.currentUser,
          repository: widget.chatRepository,
          authRepository: widget.authRepository,
          isLoveConnection: conversation.isLoveConnection,
        ),
        settings: const RouteSettings(name: '/chat'),
      ),
    ).then((_) => _loadConversations());
  }

  void _showNewConversationDialog() {
    final usernameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242424),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Start a Conversation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter username to start a private one-on-one chat:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF383838),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixText: '@',
                    prefixStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'username',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                final raw = usernameController.text.trim();
                if (raw.isEmpty) return;
                final clean = raw.replaceAll('@', '').trim();
                if (clean.isEmpty) return;
                final displayName = clean.length > 1
                    ? clean[0].toUpperCase() + clean.substring(1)
                    : clean.toUpperCase();
                final partnerUser = User(
                  id: 'user_$clean',
                  username: '@$clean',
                  displayName: displayName,
                  isCurrentUser: false,
                );

                Navigator.of(ctx).pop();
                final newConv = await _conversationRepo.startOrGetConversation(
                  partner: partnerUser,
                );
                _openConversation(newConv);
              },
              child: const Text('Start Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loveConversations =
        _filteredConversations.where((c) => c.isLoveConnection).toList();
    final otherConversations =
        _filteredConversations.where((c) => !c.isLoveConnection).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// Floating Pill App Header
            _buildInboxHeader(),

            /// Search Bar
            _buildSearchBar(),

            const SizedBox(height: 8),

            /// Conversation List Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white38),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: const Color(0xFF383838),
                      onRefresh: _loadConversations,
                      child: _searchQuery.isNotEmpty && _filteredConversations.isEmpty
                          ? _buildEmptyState()
                          : ListView(
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                if (_searchQuery.isNotEmpty) ...[
                                  /// Filtered Search Results (includes all matching conversations)
                                  _buildSectionHeader(
                                    'SEARCH RESULTS (${_filteredConversations.length})',
                                  ),
                                  ..._filteredConversations.map(
                                    (conv) => ConversationTile(
                                      conversation: conv,
                                      currentUserId: widget.currentUser?.id ?? 'current_user',
                                      onTap: () => _openConversation(conv),
                                    ),
                                  ),
                                ] else ...[
                                  /// Love Connection Section (Always pinned at top when not searching)
                                  _buildSectionHeader(
                                    loveConversations.isNotEmpty
                                        ? '❤️ LOVE CONNECTION'
                                        : '❤️ LOVE CONNECTION (0/1)',
                                    hasAccent: true,
                                  ),
                                  if (loveConversations.isNotEmpty)
                                    ...loveConversations.map(
                                      (conv) => ConversationTile(
                                        conversation: conv,
                                        currentUserId: widget.currentUser?.id ?? 'current_user',
                                        onTap: () => _openConversation(conv),
                                      ),
                                    )
                                  else
                                    _buildEmptyLoveCard(),
                                  const SizedBox(height: 14),

                                  /// Regular Conversations Section
                                  if (otherConversations.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      'CONVERSATIONS (${otherConversations.length})',
                                    ),
                                    ...otherConversations.map(
                                      (conv) => ConversationTile(
                                        conversation: conv,
                                        currentUserId: widget.currentUser?.id ?? 'current_user',
                                        onTap: () => _openConversation(conv),
                                      ),
                                    ),
                                  ] else if (loveConversations.isEmpty) ...[
                                    const SizedBox(height: 32),
                                    _buildNoConversationsPlaceholder(),
                                  ],
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: 'New conversation',
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildInboxHeader() {
    final currentUsername = widget.currentUser?.username ?? '@alex';
    final cleanUsername = currentUsername.replaceFirst(RegExp(r'^@+'), '').trim();
    final avatarChar = cleanUsername.isNotEmpty
        ? cleanUsername[0].toUpperCase()
        : (currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : '?');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF383838),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            /// App Logo / Name
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3.5),
                  child: Image.asset(
                    'assets/images/logo_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Nest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const Spacer(),

            /// Current User Pill with Avatar & Tap for Profile
            GestureDetector(
              onTap: widget.onOpenProfile,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white,
                      child: Text(
                        avatarChar,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentUsername,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search conversations or @username...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool hasAccent = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 22.0, right: 22.0, top: 12.0, bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          color: hasAccent ? const Color(0xFFFF6B81) : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.chat_bubble_outline,
              color: Colors.white30,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No conversations matching "$_searchQuery"'
                  : 'Your inbox is clear',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different username or keyword.'
                  : 'Tap the + button below to start a private conversation.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLoveCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF4D6D).withValues(alpha: 0.15),
            const Color(0xFF383838),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B81).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D6D).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              color: Color(0xFFFF6B81),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect your Love Partner (0/1)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Establish a private couple connection for your shared world.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onOpenProfile,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D6D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Connect',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConversationsPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          children: const [
            Icon(Icons.chat_bubble_outline, color: Colors.white30, size: 40),
            SizedBox(height: 12),
            Text(
              'No individual chats yet',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Tap the + button below to start a private conversation.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
