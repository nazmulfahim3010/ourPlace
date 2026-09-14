import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/screens/auth/app_lock_screen.dart';
import 'package:chatbox/screens/auth/auth_screen.dart';
import 'package:chatbox/screens/auth/passcode_setup_screen.dart';
import 'package:chatbox/screens/home_screen.dart';

/// Entryway gate that coordinates account session and local device lock state
class AuthGate extends StatefulWidget {
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final AppLockService? appLockService;

  const AuthGate({
    super.key,
    this.authRepository,
    this.chatRepository,
    this.appLockService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  late final AppLockService _appLockService;
  StreamSubscription<bool>? _lockStateSub;
  bool? _isPasscodeConfigured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authRepository = widget.authRepository ?? DefaultAuthRepository();
    _appLockService = widget.appLockService ?? DefaultAppLockService();

    _refreshPasscodeStatus();

    _lockStateSub = _appLockService.lockStateChanges.listen((_) {
      if (mounted) setState(() {});
      _refreshPasscodeStatus();
    });
  }

  Future<void> _refreshPasscodeStatus() async {
    final configured = await _appLockService.isPasscodeConfigured();
    if (mounted) {
      setState(() {
        _isPasscodeConfigured = configured;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _appLockService.lockApp();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white38,
              ),
            ),
          );
        }

        final user = authSnapshot.data;

        /// 1. Unauthenticated -> Show login / account creation screen
        if (user == null) {
          return AuthScreen(
            authRepository: _authRepository,
          );
        }

        /// 2. Authenticated user -> Check device lock state
        if (_isPasscodeConfigured == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white38,
              ),
            ),
          );
        }

        /// 2A. No local passcode configured -> Force first-time passcode setup
        if (!_isPasscodeConfigured!) {
          return PasscodeSetupScreen(
            appLockService: _appLockService,
            onSetupComplete: _refreshPasscodeStatus,
          );
        }

        /// 2B. Passcode configured but app is locked -> Show dedicated AppLockScreen
        if (!_appLockService.isAppUnlocked) {
          return AppLockScreen(
            appLockService: _appLockService,
            onUnlocked: () => setState(() {}),
            onSignOutRequested: () async {
              _appLockService.lockApp();
              await _authRepository.signOut();
            },
          );
        }

        /// 2C. Unlocked and authenticated -> Show primary HomeScreen (Inbox)
        return HomeScreen(
          currentUser: user,
          authRepository: _authRepository,
          chatRepository: widget.chatRepository,
          appLockService: _appLockService,
        );
      },
    );
  }
}
