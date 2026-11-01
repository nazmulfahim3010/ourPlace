import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbox/core/config/app_environment.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/repositories/auth_repository.dart';
import 'package:chatbox/repositories/chat_repository.dart';
import 'package:chatbox/screens/auth/auth_gate.dart';
import 'package:chatbox/services/app_lock_service.dart';
import 'package:chatbox/services/encryption_service.dart';
import 'package:chatbox/services/notification_service.dart';
import 'package:chatbox/widgets/top_notification_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.setEnvironment(EnvironmentType.production);
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCUW55pAkIE1KIN-55MECNOuvd5aRjZ2oA',
        appId: '1:345075037383:android:8dac2b3b5779c5dc9bbae2',
        messagingSenderId: '345075037383',
        projectId: 'ourplace-chat',
        databaseURL: AppConstants.firebaseDatabaseUrl,
      ),
    );
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (authError) {
      debugPrint('FirebaseAuth notice (anonymous sign-in optional): $authError');
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  final notificationService = DefaultNotificationService();
  await notificationService.initialize();
  final authRepository = DefaultAuthRepository();
  final chatRepository = LocalChatRepository(
    encryptionService: StandardE2EEEncryptionService.instance,
    notificationService: notificationService,
  );
  runApp(MyApp(
    authRepository: authRepository,
    chatRepository: chatRepository,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final String partnerName;
  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final AppLockService? appLockService;
  final NotificationService? notificationService;
  final Widget? home;

  const MyApp({
    super.key,
    this.partnerName = AppConstants.defaultPartnerName,
    this.authRepository,
    this.chatRepository,
    this.appLockService,
    this.notificationService,
    this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} - Private Chat',
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return InAppNotificationOverlay(
          notificationService: notificationService,
          child: child ?? const SizedBox.shrink(),
        );
      },
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
