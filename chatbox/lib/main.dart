import 'package:flutter/material.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String partnerName;

  const MyApp({
    super.key,
    this.partnerName = AppConstants.defaultPartnerName,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} - Chat',
      theme: AppTheme.darkTheme,
      home: ChatScreen(partnerName: partnerName),
      debugShowCheckedModeBanner: false,
    );
  }
}
