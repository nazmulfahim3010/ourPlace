import 'package:flutter/material.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/repositories/conversation_repository.dart';
import 'package:chatbox/screens/inbox/inbox_screen.dart';
import 'package:chatbox/screens/profile/profile_screen.dart';

import 'package:chatbox/services/app_lock_service.dart';

/// Top-level Home Screen hosting the primary Inbox and profile navigation
class HomeScreen extends StatelessWidget {
  final User? currentUser;
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final ConversationRepository? conversationRepository;
  final AppLockService? appLockService;

  const HomeScreen({
    super.key,
    this.currentUser,
    this.authRepository,
    this.chatRepository,
    this.conversationRepository,
    this.appLockService,
  });

  @override
  Widget build(BuildContext context) {
    return InboxScreen(
      currentUser: currentUser,
      authRepository: authRepository,
      chatRepository: chatRepository,
      conversationRepository: conversationRepository,
      onOpenProfile: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              currentUser: currentUser,
              authRepository: authRepository,
              appLockService: appLockService,
              realtimeService: chatRepository?.realtimeService,
              notificationService: chatRepository?.notificationService,
              loveConnectionService: chatRepository?.loveConnectionService,
            ),
            settings: const RouteSettings(name: '/profile'),
          ),
        );
      },
    );
  }
}
