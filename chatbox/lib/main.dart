import 'package:flutter/material.dart';
import 'package:chatbox/screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String partnerName;

  const MyApp({super.key, this.partnerName = 'Twilight'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ourPlace - Chat',
      theme: ThemeData.dark(useMaterial3: true),
      home: ChatScreen(partnerName: partnerName),
      debugShowCheckedModeBanner: false,
    );
  }
}
