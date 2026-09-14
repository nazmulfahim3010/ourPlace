import 'package:flutter/material.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/auth/auth_gate.dart';

import 'package:chatbox/services/app_lock_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String partnerName;
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final AppLockService? appLockService;
  final Widget? home;

  const MyApp({
    super.key,
    this.partnerName = AppConstants.defaultPartnerName,
    this.authRepository,
    this.chatRepository,
    this.appLockService,
    this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} - Private Chat',
      theme: AppTheme.darkTheme,
      home: home ??
          AuthGate(
            authRepository: authRepository,
            chatRepository: chatRepository,
            appLockService: appLockService,
          ),
      debugShowCheckedModeBanner: false,
    );
  }
}
