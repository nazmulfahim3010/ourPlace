import 'package:flutter/material.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/auth/auth_screen.dart';
import 'package:chatbox/screens/home_screen.dart';

/// Entryway gate that dynamically displays the AuthScreen or the HomeScreen (Inbox) based on session state
class AuthGate extends StatefulWidget {
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;

  const AuthGate({
    super.key,
    this.authRepository,
    this.chatRepository,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? DefaultAuthRepository();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white38,
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(
            currentUser: user,
            authRepository: _authRepository,
            chatRepository: widget.chatRepository,
          );
        }

        return AuthScreen(
          authRepository: _authRepository,
        );
      },
    );
  }
}
